import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/services/sms_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/fee_record_model.dart';
import '../../models/student_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/fee_provider.dart';
import '../../providers/sms_provider.dart';
import '../../providers/student_provider.dart';

class FeeListScreen extends ConsumerStatefulWidget {
  const FeeListScreen({super.key});

  @override
  ConsumerState<FeeListScreen> createState() => _FeeListScreenState();
}

class _FeeListScreenState extends ConsumerState<FeeListScreen> {
  String _filter = 'due'; // 'all', 'due', 'paid'
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monthYear = ref.watch(selectedFeeMonthYearProvider);
    final feesAsync = ref.watch(monthlyFeesProvider);
    final studentsAsync = ref.watch(studentsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Text(
          '💳 বেতন ও বকেয়া (Fees)',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: studentsAsync.when(
        data: (students) {
          final studentMap = {for (var s in students) s.id: s};

          return feesAsync.when(
            data: (feeRecords) {
              return _buildContent(
                context,
                monthYear: monthYear,
                feeRecords: feeRecords,
                studentMap: studentMap,
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
            error: (err, _) => Center(
              child: Text(
                'ত্রুটি: $err',
                style: GoogleFonts.outfit(color: AppTheme.danger),
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (err, _) => Center(
          child: Text(
            'শিক্ষার্থী তথ্য লোড করা যায়নি: $err',
            style: GoogleFonts.outfit(color: AppTheme.danger),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required MonthYearState monthYear,
    required List<FeeRecordModel> feeRecords,
    required Map<String, StudentModel> studentMap,
  }) {
    // Calculate aggregate statistics
    double totalBilled = 0;
    double totalCollected = 0;
    int dueCount = 0;
    int paidCount = 0;

    for (final f in feeRecords) {
      totalBilled += f.amount;
      totalCollected += f.paidAmount;
      if (f.isFullyPaid) {
        paidCount++;
      } else {
        dueCount++;
      }
    }
    final totalDue = (totalBilled - totalCollected).clamp(0.0, double.infinity).toDouble();

    // Filter fees
    final filteredFees = feeRecords.where((f) {
      final student = studentMap[f.studentId];
      if (student == null) return false;

      final matchesSearch = _searchQuery.isEmpty ||
          student.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          student.grade.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          student.parentPhone.contains(_searchQuery);

      if (!matchesSearch) return false;

      if (_filter == 'due') return !f.isFullyPaid;
      if (_filter == 'paid') return f.isFullyPaid;
      return true;
    }).toList();

    return Column(
      children: [
        // ── Month Navigator ────────────────────────────────────
        _buildMonthNavigator(monthYear),

        // ── Stats Summary Bar ──────────────────────────────────
        _buildStatsBar(
          totalBilled: totalBilled,
          totalCollected: totalCollected,
          totalDue: totalDue,
          dueCount: dueCount,
          paidCount: paidCount,
        ),

        // ── Search & Filter ────────────────────────────────────
        _buildSearchAndFilters(),

        // ── List of Fees ───────────────────────────────────────
        Expanded(
          child: filteredFees.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 48, color: AppTheme.success),
                      const SizedBox(height: 12),
                      Text(
                        _filter == 'due'
                            ? 'এই মাসে কোনো বকেয়া নেই! 🎉'
                            : 'কোনো রেকর্ড পাওয়া যায়নি',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filteredFees.length,
                  itemBuilder: (context, index) {
                    final fee = filteredFees[index];
                    final student = studentMap[fee.studentId];
                    if (student == null) return const SizedBox.shrink();

                    return _FeeCard(
                      fee: fee,
                      student: student,
                      onSendReminderSms: () => _sendReminderSms(student, fee),
                      onRecordPayment: () => _showPaymentDialog(student, fee),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMonthNavigator(MonthYearState monthYear) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
            onPressed: () =>
                ref.read(selectedFeeMonthYearProvider.notifier).previousMonth(),
          ),
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                monthYear.displayBn,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          IconButton(
            icon:
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            onPressed: () =>
                ref.read(selectedFeeMonthYearProvider.notifier).nextMonth(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar({
    required double totalBilled,
    required double totalCollected,
    required double totalDue,
    required int dueCount,
    required int paidCount,
  }) {
    final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'মোট বকেয়া',
                  currency.format(totalDue),
                  AppTheme.danger,
                  '$dueCount জন শিক্ষার্থীর',
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(
                child: _buildStatItem(
                  'সংগৃহীত ফি',
                  currency.format(totalCollected),
                  AppTheme.success,
                  '$paidCount জন পরিশোধ করেছে',
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(
                child: _buildStatItem(
                  'মোট ধার্য',
                  currency.format(totalBilled),
                  Colors.white70,
                  'চলতি মাস',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, Color color, String subtitle) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70),
        ),
        Text(
          subtitle,
          style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'শিক্ষার্থী বা অভিভাবকের ফোন খুঁজুন...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: Colors.white38),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          size: 18, color: Colors.white38),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildChoiceChip('due', 'বকেয়া রয়েছে'),
              const SizedBox(width: 8),
              _buildChoiceChip('all', 'সকল শিক্ষার্থী'),
              const SizedBox(width: 8),
              _buildChoiceChip('paid', 'পরিশোধিত'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String value, String label) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.cardDark,
      labelStyle: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected ? Colors.white : Colors.white60,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Future<void> _sendReminderSms(StudentModel student, FeeRecordModel fee) async {
    final launched = await ref
        .read(monthlyFeesProvider.notifier)
        .sendDueReminderSms(student: student, dueAmount: fee.dueAmount);

    if (mounted) {
      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text(
              '${student.fullName}-এর বকেয়া রিমাইন্ডার SMS খোলা হয়েছে',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text(
              'SMS পাঠানো সম্ভব হয়নি (${student.parentPhone})',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  void _showPaymentDialog(StudentModel student, FeeRecordModel fee) {
    final paidCtrl = TextEditingController(
      text: fee.paidAmount > 0
          ? fee.paidAmount.toStringAsFixed(0)
          : fee.amount.toStringAsFixed(0),
    );
    final noteCtrl = TextEditingController(text: fee.note);
    var sendConfirmationSms = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'বেতন আদায় রেকর্ড করুন',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'শিক্ষার্থী: ${student.fullName} (${student.grade})',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
            ),
            Text(
              'ধার্যকৃত মাসিক ফি: ৳${fee.amount.toStringAsFixed(0)}',
              style: GoogleFonts.outfit(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paidCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                labelText: 'প্রাপ্ত টাকা (৳)',
                prefixIcon: Icon(Icons.payments_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.success,
                    side: const BorderSide(color: AppTheme.success),
                  ),
                  onPressed: () {
                    paidCtrl.text = fee.amount.toStringAsFixed(0);
                  },
                  child: const Text('সম্পূর্ণ পরিশোধ (Full Pay)'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'নোট (বিকাশ / নগদ / ক্যাশ)',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: sendConfirmationSms,
              activeThumbColor: AppTheme.success,
              title: Text(
                'পরিশোধের SMS পাঠান',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.white),
              ),
              subtitle: Text(
                student.parentPhone,
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38),
              ),
              onChanged: (v) => setSheetState(() => sendConfirmationSms = v),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final paidAmount = double.tryParse(paidCtrl.text.trim()) ?? 0;
                Navigator.pop(ctx);

                final success = await ref.read(monthlyFeesProvider.notifier).recordPayment(
                      studentId: student.id,
                      totalAmount: fee.amount,
                      paidAmount: paidAmount,
                      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    );

                if (!mounted) return;

                if (success && sendConfirmationSms && paidAmount > 0) {
                  final my = ref.read(selectedFeeMonthYearProvider);
                  final coaching = ref.read(coachingNameProvider);
                  final message = SmsService.generateFeePaidMessage(
                    studentName: student.fullName,
                    paidAmount: paidAmount,
                    monthYear: my.displayBn,
                    customCoachingName: coaching,
                  );
                  final sent = await SmsService.sendCustomSms(
                    phone: student.parentPhone,
                    message: message,
                  );
                  await ref.read(smsLogProvider.notifier).logSms(
                        phone: student.parentPhone,
                        studentName: student.fullName,
                        message: message,
                        type: SmsType.feePaid,
                        success: sent,
                      );
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.success,
                      content: Text(
                        '✓ ${student.fullName}-এর পেমেন্ট সফলভাবে সংরক্ষিত হয়েছে',
                        style: GoogleFonts.outfit(color: Colors.white),
                      ),
                    ),
                  );
                }
              },
              child: const Text('সংরক্ষণ করুন'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ── Fee Card Widget ─────────────────────────────────────────────
class _FeeCard extends StatelessWidget {
  const _FeeCard({
    required this.fee,
    required this.student,
    required this.onSendReminderSms,
    required this.onRecordPayment,
  });

  final FeeRecordModel fee;
  final StudentModel student;
  final VoidCallback onSendReminderSms;
  final VoidCallback onRecordPayment;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final isDue = !fee.isFullyPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDue
              ? AppTheme.danger.withValues(alpha: 0.3)
              : AppTheme.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: isDue
                    ? AppTheme.danger.withValues(alpha: 0.2)
                    : AppTheme.success.withValues(alpha: 0.2),
                child: Text(
                  student.initials,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    color: isDue ? AppTheme.danger : AppTheme.success,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Student Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${student.grade} · ${student.subject}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 11, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text(
                          student.parentPhone,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(fee.status.colorValue).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Color(fee.status.colorValue).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  fee.status.labelBn,
                  style: GoogleFonts.outfit(
                    color: Color(fee.status.colorValue),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),
          // Amount Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ধার্য: ${currency.format(fee.amount)} | আদায়: ${currency.format(fee.paidAmount)}',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: Colors.white60),
                  ),
                  if (isDue)
                    Text(
                      'বকেয়া: ${currency.format(fee.dueAmount)}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.danger,
                      ),
                    )
                  else
                    Text(
                      'সম্পূর্ণ পরিশোধিত ✓',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.success,
                      ),
                    ),
                ],
              ),
              // Buttons
              Row(
                children: [
                  if (isDue) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.danger.withValues(alpha: 0.2),
                        foregroundColor: AppTheme.danger,
                        side: const BorderSide(color: AppTheme.danger),
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      onPressed: onSendReminderSms,
                      icon: const Icon(Icons.sms_outlined, size: 16),
                      label: Text(
                        'SMS দিন',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    onPressed: onRecordPayment,
                    child: Text(
                      'আদায়',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
