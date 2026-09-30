import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/services/sms_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/attendance_model.dart';
import '../../models/student_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/student_provider.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String _filter = 'all'; // 'all', 'present', 'absent', 'unmarked'
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedAttendanceDateProvider);
    final studentsAsync = ref.watch(studentsStreamProvider);
    final attendanceAsync = ref.watch(attendanceMapProvider);
    final coachingName = ref.watch(coachingNameProvider);

    final isToday = _isSameDay(selectedDate, DateTime.now());
    final dateDisplay = DateFormat('EEE, d MMM yyyy').format(selectedDate);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Text(
          '📋 হাজিরা খাতা (Attendance)',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'কোচিংয়ের নাম ও SMS সেটিংস',
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () => _showCoachingNameDialog(context, coachingName),
          ),
        ],
      ),
      body: studentsAsync.when(
        data: (students) {
          if (students.isEmpty) {
            return _buildNoStudentsView(context);
          }

          return attendanceAsync.when(
            data: (attendanceMap) {
              return _buildAttendanceContent(
                context,
                students: students,
                attendanceMap: attendanceMap,
                selectedDate: selectedDate,
                dateDisplay: dateDisplay,
                isToday: isToday,
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
            'লোড করা যায়নি: $err',
            style: GoogleFonts.outfit(color: AppTheme.danger),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceContent(
    BuildContext context, {
    required List<StudentModel> students,
    required Map<String, AttendanceModel> attendanceMap,
    required DateTime selectedDate,
    required String dateDisplay,
    required bool isToday,
  }) {
    // Calculate stats
    int presentCount = 0;
    int absentCount = 0;
    for (final s in students) {
      final record = attendanceMap[s.id];
      if (record != null) {
        if (record.status == AttendanceStatus.present) presentCount++;
        if (record.status == AttendanceStatus.absent) absentCount++;
      }
    }
    final unmarkedCount = students.length - (presentCount + absentCount);

    // Apply search and status filter
    final filteredStudents = students.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.grade.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.parentPhone.contains(_searchQuery);

      if (!matchesSearch) return false;

      final record = attendanceMap[s.id];
      if (_filter == 'present') return record?.status == AttendanceStatus.present;
      if (_filter == 'absent') return record?.status == AttendanceStatus.absent;
      if (_filter == 'unmarked') return record == null;
      return true;
    }).toList();

    return Column(
      children: [
        // ── Date Selector Bar ──────────────────────────────
        _buildDateHeader(selectedDate, dateDisplay, isToday),

        // ── Summary Cards ──────────────────────────────────
        _buildStatsBar(
          total: students.length,
          present: presentCount,
          absent: absentCount,
          unmarked: unmarkedCount,
          onMarkAllPresent: () => _confirmMarkAllPresent(students),
        ),

        // ── Search & Filter Chips ──────────────────────────
        _buildFilterBar(),

        // ── Students List ──────────────────────────────────
        Expanded(
          child: filteredStudents.isEmpty
              ? Center(
                  child: Text(
                    'কোনো শিক্ষার্থী পাওয়া যায়নি',
                    style: GoogleFonts.outfit(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    final record = attendanceMap[student.id];
                    return _AttendanceStudentTile(
                      student: student,
                      record: record,
                      onMarkPresent: () => record?.status == AttendanceStatus.present
                          ? _unmarkAttendance(student)
                          : _markAttendance(
                              student,
                              AttendanceStatus.present,
                              sendSms: false,
                            ),
                      onMarkAbsent: () => record?.status == AttendanceStatus.absent
                          ? _unmarkAttendance(student)
                          : _markAttendance(
                              student,
                              AttendanceStatus.absent,
                              sendSms: true,
                            ),
                      onSendSms: () => _resendSms(student),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Date Header Widget ─────────────────────────────────────────
  Widget _buildDateHeader(
    DateTime selectedDate,
    String dateDisplay,
    bool isToday,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
            onPressed: () =>
                ref.read(selectedAttendanceDateProvider.notifier).previousDay(),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  builder: (context, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppTheme.primary,
                        surface: AppTheme.cardDark,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  ref
                      .read(selectedAttendanceDateProvider.notifier)
                      .setDate(picked);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      isToday ? 'আজ: $dateDisplay' : dateDisplay,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            onPressed: () =>
                ref.read(selectedAttendanceDateProvider.notifier).nextDay(),
          ),
          if (!isToday)
            TextButton(
              onPressed: () =>
                  ref.read(selectedAttendanceDateProvider.notifier).setToday(),
              child: Text(
                'আজ',
                style: GoogleFonts.outfit(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Stats Bar Widget ───────────────────────────────────────────
  Widget _buildStatsBar({
    required int total,
    required int present,
    required int absent,
    required int unmarked,
    required VoidCallback onMarkAllPresent,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('মোট', '$total', Colors.white70),
              _buildStatItem('উপস্থিত', '$present', AppTheme.success),
              _buildStatItem('অনুপস্থিত', '$absent', AppTheme.danger),
              _buildStatItem('বাকি', '$unmarked', Colors.white38),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.success,
                    side: const BorderSide(color: AppTheme.success),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: onMarkAllPresent,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: Text(
                    'সবাইকে উপস্থিত দেখান',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  // ── Filter Bar Widget ──────────────────────────────────────────
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          // Search input
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'নাম বা ফোন দিয়ে খুঁজুন...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.white38),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Colors.white38),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'সব'),
                const SizedBox(width: 8),
                _buildFilterChip('present', 'উপস্থিত'),
                const SizedBox(width: 8),
                _buildFilterChip('absent', 'অনুপস্থিত'),
                const SizedBox(width: 8),
                _buildFilterChip('unmarked', 'অনির্ধারিত'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
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

  // ── Actions ────────────────────────────────────────────────────
  Future<void> _markAttendance(
    StudentModel student,
    AttendanceStatus status, {
    required bool sendSms,
  }) async {
    final notifier = ref.read(attendanceMapProvider.notifier);
    final success = await notifier.markStudent(
      student: student,
      status: status,
      autoSendSms: sendSms,
    );

    if (mounted) {
      if (status == AttendanceStatus.absent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Text(
              '${student.fullName}-কে অনুপস্থিত চিহ্নিত করা হয়েছে। SMS খোলা হয়েছে।',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'পুনরায় SMS',
              textColor: Colors.white,
              onPressed: () => _resendSms(student),
            ),
          ),
        );
      } else if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1200),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Text(
              '✓ ${student.fullName} উপস্থিত',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Future<void> _unmarkAttendance(StudentModel student) async {
    final success = await ref
        .read(attendanceMapProvider.notifier)
        .unmarkStudent(student.id);

    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          content: Text(
            '${student.fullName}-এর হাজিরা মুছতে সমস্যা হয়েছে',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _resendSms(StudentModel student) async {
    final coaching = ref.read(coachingNameProvider);
    final message = SmsService.generateAbsentMessage(
      studentName: student.fullName,
      customCoachingName: coaching,
    );
    final launched = await SmsService.launchSms(
      phone: student.parentPhone,
      message: message,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text(
            'SMS অ্যাপ খোলা সম্ভব হয়নি (${student.parentPhone})',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _confirmMarkAllPresent(
    List<StudentModel> students,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'সবাইকে উপস্থিত চিহ্নিত করবেন?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'মোট ${students.length} জন শিক্ষার্থীকে এক ক্লিকে "উপস্থিত" চিহ্নিত করা হবে। পরে প্রয়োজন অনুযায়ী অনুপস্থিত চিহ্নিত করতে পারবেন।',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('বাতিল', style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              minimumSize: const Size(100, 40),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('হ্যাঁ, করুন',
                style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(attendanceMapProvider.notifier).markAllPresent(students);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Text(
              '✓ সকল শিক্ষার্থীকে উপস্থিত চিহ্নিত করা হয়েছে',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  void _showCoachingNameDialog(BuildContext context, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'কোচিংয়ের নাম (SMS ফুটার)',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'অভিভাবকের কাছে পাঠানো SMS-এর শেষে এই নাম থাকবে:',
              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'কোচিংয়ের নাম',
                prefixIcon: Icon(Icons.school),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('বাতিল', style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size(80, 40),
            ),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ref
                    .read(coachingNameProvider.notifier)
                    .updateName(ctrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: Text('সংরক্ষণ', style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoStudentsView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'কোনো শিক্ষার্থী যোগ করা হয়নি',
            style: GoogleFonts.outfit(fontSize: 18, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'প্রথমে শিক্ষার্থী তালিকায় গিয়ে শিক্ষার্থী যোগ করুন।',
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ── Attendance Student Tile ──────────────────────────────────────
class _AttendanceStudentTile extends StatelessWidget {
  const _AttendanceStudentTile({
    required this.student,
    required this.record,
    required this.onMarkPresent,
    required this.onMarkAbsent,
    required this.onSendSms,
  });

  final StudentModel student;
  final AttendanceModel? record;
  final VoidCallback onMarkPresent;
  final VoidCallback onMarkAbsent;
  final VoidCallback onSendSms;

  @override
  Widget build(BuildContext context) {
    final status = record?.status;
    final isPresent = status == AttendanceStatus.present;
    final isAbsent = status == AttendanceStatus.absent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPresent
              ? AppTheme.success.withValues(alpha: 0.35)
              : isAbsent
                  ? AppTheme.danger.withValues(alpha: 0.35)
                  : Colors.white10,
          width: isPresent || isAbsent ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: isPresent
                ? AppTheme.success.withValues(alpha: 0.2)
                : isAbsent
                    ? AppTheme.danger.withValues(alpha: 0.2)
                    : AppTheme.primary.withValues(alpha: 0.2),
            child: Text(
              student.initials,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                color: isPresent
                    ? AppTheme.success
                    : isAbsent
                        ? AppTheme.danger
                        : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Student Details
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
                const SizedBox(height: 2),
                Text(
                  '${student.grade} · ${student.subject}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 2),
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

          // Action Buttons: Present & Absent
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Present Button (P)
              _StatusActionButton(
                label: 'উপস্থিত',
                icon: Icons.check,
                isActive: isPresent,
                activeColor: AppTheme.success,
                onTap: onMarkPresent,
              ),
              const SizedBox(width: 8),

              // Absent Button (A)
              _StatusActionButton(
                label: 'অনুপস্থিত',
                icon: Icons.close,
                isActive: isAbsent,
                activeColor: AppTheme.danger,
                onTap: onMarkAbsent,
              ),

              // Resend SMS icon if absent
              if (isAbsent) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'অভিভাবককে SMS পাঠান',
                  icon: const Icon(
                    Icons.sms_rounded,
                    color: Colors.amberAccent,
                    size: 20,
                  ),
                  onPressed: onSendSms,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Status Action Button ─────────────────────────────────────────
class _StatusActionButton extends StatelessWidget {
  const _StatusActionButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? activeColor : Colors.white12,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? activeColor : Colors.white54,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeColor : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
