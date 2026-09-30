import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/supabase_service.dart';
import '../../core/services/sms_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/student_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/sms_provider.dart';
import '../../providers/student_provider.dart';

/// Screen for both ADDING a new student and EDITING an existing one.
/// Pass [student] to pre-fill the form for editing; omit it for adding.
class AddEditStudentScreen extends ConsumerStatefulWidget {
  const AddEditStudentScreen({super.key, this.student});

  /// If non-null, the form opens in edit mode.
  final StudentModel? student;

  @override
  ConsumerState<AddEditStudentScreen> createState() =>
      _AddEditStudentScreenState();
}

class _AddEditStudentScreenState extends ConsumerState<AddEditStudentScreen> {
  // ── Form key & controllers ─────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _parentNameCtrl;
  late final TextEditingController _parentPhoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _gradeCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _scheduleCtrl;
  late final TextEditingController _notesCtrl;

  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameCtrl       = TextEditingController(text: s?.fullName);
    _phoneCtrl      = TextEditingController(text: s?.phone);
    _parentNameCtrl = TextEditingController(text: s?.parentName);
    _parentPhoneCtrl = TextEditingController(text: s?.parentPhone);
    _addressCtrl    = TextEditingController(text: s?.address);
    _gradeCtrl      = TextEditingController(text: s?.grade);
    _subjectCtrl    = TextEditingController(text: s?.subject);
    _feeCtrl        = TextEditingController(
        text: s != null ? s.monthlyFee.toStringAsFixed(0) : '');
    _scheduleCtrl   = TextEditingController(text: s?.schedule);
    _notesCtrl      = TextEditingController(text: s?.notes);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _parentNameCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _gradeCtrl.dispose();
    _subjectCtrl.dispose();
    _feeCtrl.dispose();
    _scheduleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Submit ─────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final student = StudentModel(
      id:            widget.student?.id ?? '',        // ignored on insert
      teacherId:     SupabaseService.currentUserId,
      fullName:      _nameCtrl.text.trim(),
      phone:         _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      parentName:    _parentNameCtrl.text.trim().isEmpty ? null : _parentNameCtrl.text.trim(),
      parentPhone:   _parentPhoneCtrl.text.trim(),
      address:       _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      grade:         _gradeCtrl.text.trim(),
      subject:       _subjectCtrl.text.trim(),
      monthlyFee:    double.tryParse(_feeCtrl.text.trim()) ?? 0,
      schedule:      _scheduleCtrl.text.trim().isEmpty ? null : _scheduleCtrl.text.trim(),
      admissionDate: widget.student?.admissionDate ?? now,
      isActive:      widget.student?.isActive ?? true,
      notes:         _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt:     widget.student?.createdAt ?? now,
      updatedAt:     now,
    );

    final notifier = ref.read(studentMutationProvider.notifier);
    final success = _isEdit
        ? await notifier.updateStudent(student)
        : await notifier.addStudent(student);

    if (!mounted) return;

    if (success) {
      if (!_isEdit) {
        await _askSendWelcomeSms(student);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            _isEdit ? '✓ Student updated!' : '✓ Student added successfully!',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
        ),
      );
      Navigator.pop(context);
    } else {
      final error = ref.read(studentMutationProvider).error?.toString() ?? 'Unknown error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            '✗ $error',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
        ),
      );
    }
  }

  // ── Welcome SMS after admission ────────────────────────────
  Future<void> _askSendWelcomeSms(StudentModel student) async {
    final send = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'স্বাগত বার্তা পাঠাবেন?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '${student.fullName}-এর অভিভাবকের নম্বরে (${student.parentPhone}) ভর্তির স্বাগত SMS পাঠানো হবে।',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'পরে',
              style: GoogleFonts.outfit(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'SMS পাঠান',
              style: GoogleFonts.outfit(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (send != true || !mounted) return;

    final coaching = ref.read(coachingNameProvider);
    final message = SmsService.renderTemplate(
      SmsService.getTemplate(SmsService.templateWelcome),
      variables: {
        'student_name': student.fullName,
        'grade': student.grade,
        'subject': student.subject,
        'schedule': student.schedule ?? '',
        'coaching_name': coaching,
      },
    );
    final sent = await SmsService.sendCustomSms(
      phone: student.parentPhone,
      message: message,
    );
    await ref.read(smsLogProvider.notifier).logSms(
          phone: student.parentPhone,
          studentName: student.fullName,
          message: message,
          type: SmsType.welcome,
          success: sent,
        );
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(studentMutationProvider) is AsyncLoading;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Student' : 'Add New Student'),
        backgroundColor: AppTheme.bgDark,
        leading: const BackButton(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              _buildHeroHeader(),
              const SizedBox(height: 24),

              // ── Personal Info ───────────────────────────
              _SectionLabel(label: 'Personal Information'),
              const SizedBox(height: 12),
              _AppField(
                controller: _nameCtrl,
                label: 'Full Name',
                icon: Icons.person_rounded,
                validator: _requiredValidator('Name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              _AppField(
                controller: _phoneCtrl,
                label: "Student's Phone (optional)",
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 24),

              // ── Guardian Info ───────────────────────────
              _SectionLabel(label: 'Guardian Information'),
              const SizedBox(height: 12),
              _AppField(
                controller: _parentNameCtrl,
                label: 'Guardian Name (optional)',
                icon: Icons.supervisor_account_rounded,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              _AppField(
                controller: _parentPhoneCtrl,
                label: 'Guardian Phone Number *',
                icon: Icons.phone_in_talk_rounded,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _requiredValidator('Guardian phone'),
              ),
              const SizedBox(height: 12),
              _AppField(
                controller: _addressCtrl,
                label: 'Address (optional)',
                icon: Icons.location_on_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // ── Academic Info ───────────────────────────
              _SectionLabel(label: 'Academic Details'),
              const SizedBox(height: 12),
              _AppField(
                controller: _gradeCtrl,
                label: 'Class / Grade *',
                icon: Icons.class_rounded,
                hint: 'e.g. Class 9, HSC 1st Year',
                validator: _requiredValidator('Class'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              _AppField(
                controller: _subjectCtrl,
                label: 'Subject(s) *',
                icon: Icons.menu_book_rounded,
                hint: 'e.g. Physics, Math',
                validator: _requiredValidator('Subject'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),

              // ── Fee & Schedule ──────────────────────────
              _SectionLabel(label: 'Fee & Schedule'),
              const SizedBox(height: 12),
              _AppField(
                controller: _feeCtrl,
                label: 'Monthly Fee (৳) *',
                icon: Icons.payments_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Fee is required';
                  if (double.tryParse(v.trim()) == null) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _AppField(
                controller: _scheduleCtrl,
                label: 'Schedule / Routine (optional)',
                icon: Icons.schedule_rounded,
                hint: 'e.g. Sat, Mon, Wed — 5:00 PM',
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),

              // ── Notes ───────────────────────────────────
              _SectionLabel(label: 'Additional Notes'),
              const SizedBox(height: 12),
              _AppField(
                controller: _notesCtrl,
                label: 'Notes (optional)',
                icon: Icons.notes_rounded,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 32),

              // ── Submit button ───────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      )
                    : ElevatedButton.icon(
                        key: const ValueKey('submit'),
                        onPressed: _submit,
                        icon: Icon(
                          _isEdit ? Icons.save_rounded : Icons.person_add_rounded,
                        ),
                        label: Text(_isEdit ? 'Save Changes' : 'Add Student'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.25),
            AppTheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _isEdit ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
              color: AppTheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Edit Student Profile' : 'New Student Enrollment',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEdit
                      ? 'Update the details below and save.'
                      : 'Fill in the details to enroll a new student.',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? Function(String?) _requiredValidator(String field) =>
      (v) => (v == null || v.trim().isEmpty) ? '$field is required' : null;
}

// ── Reusable Section Label ─────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Reusable Text Field ────────────────────────────────────────
class _AppField extends StatelessWidget {
  const _AppField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }
}
