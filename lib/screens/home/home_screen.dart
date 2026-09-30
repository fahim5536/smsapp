import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/attendance_model.dart';
import '../../models/class_routine_model.dart';
import '../../models/student_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/fee_provider.dart';
import '../../providers/routine_provider.dart';
import '../../providers/sms_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/teacher_provider.dart';
import '../attendance/attendance_screen.dart';
import '../fees/fee_list_screen.dart';
import '../routine/routine_screen.dart';
import '../students/add_edit_student_screen.dart';
import '../students/student_list_screen.dart';
import '../sms/sms_history_screen.dart';
import '../../reports/fee_report_screen.dart';

/// Full dashboard home: teacher identity, live stats, monthly collection,
/// today's classes & attendance, recent students, quick navigation.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _currency = '৳';

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'সুপ্রভাত';
    if (hour >= 12 && hour < 17) return 'শুভ অপরাহ্ণ';
    if (hour >= 17 && hour < 20) return 'শুভ সন্ধ্যা';
    return 'শুভ রাত্রি';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherAsync = ref.watch(teacherProfileProvider);
    final studentsAsync = ref.watch(studentsStreamProvider);
    final routinesAsync = ref.watch(routinesStreamProvider);
    final feesAsync = ref.watch(monthlyFeesProvider);
    final monthYear = ref.watch(selectedFeeMonthYearProvider);
    final attendanceAsync = ref.watch(attendanceMapProvider);
    final attendanceDate = ref.watch(selectedAttendanceDateProvider);
    final smsLogs = ref.watch(smsLogProvider).value ?? const [];

    final students = studentsAsync.value ?? const <StudentModel>[];
    final routines = routinesAsync.value ?? const <ClassRoutineModel>[];
    final attendanceMap = attendanceAsync.value ?? const <String, AttendanceModel>{};

    final teacherName = teacherAsync.value?['full_name']?.toString() ?? 'শিক্ষক মহাশয়';
    final teacherPhone = teacherAsync.value?['phone']?.toString() ?? '';

    // ── Today's figures ─────────────────────────────────────
    final now = DateTime.now();
    final todaysClasses = routines
        .where((r) => r.isActive && r.dayOfWeek == now.weekday)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    var presentCount = 0;
    var absentCount = 0;
    for (final s in students) {
      final status = attendanceMap[s.id]?.status;
      if (status == AttendanceStatus.present) presentCount++;
      if (status == AttendanceStatus.absent) absentCount++;
    }
    final unmarkedCount = students.length - (presentCount + absentCount);

    final smsToday = smsLogs.where((l) =>
        l.sentAt.year == now.year &&
        l.sentAt.month == now.month &&
        l.sentAt.day == now.day).length;

    // ── Monthly collection figures ──────────────────────────
    var totalBilled = 0.0;
    var totalCollected = 0.0;
    for (final f in feesAsync.value ?? const []) {
      totalBilled += f.amount;
      totalCollected += f.paidAmount;
    }
    final totalDue = (totalBilled - totalCollected).clamp(0.0, double.infinity);
    final collectionRate =
        totalBilled > 0 ? (totalCollected / totalBilled).clamp(0.0, 1.0) : 0.0;

    final recentStudents = [...students]
      ..sort((a, b) => b.admissionDate.compareTo(a.admissionDate));

    final isAttendanceToday = attendanceDate.year == now.year &&
        attendanceDate.month == now.month &&
        attendanceDate.day == now.day;
    final attendanceLabel = isAttendanceToday
        ? 'আজকের হাজিরা'
        : 'হাজিরা (${DateFormat('d MMM', 'bn').format(attendanceDate)})';

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: _buildAppBar(context, ref),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(teacherName, teacherPhone),
                const SizedBox(height: 14),

                // ── Top stats ───────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StatMiniCard(
                        label: 'মোট শিক্ষার্থী',
                        value: '${students.length}',
                        icon: Icons.people_alt_rounded,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatMiniCard(
                        label: 'আজকে ক্লাস',
                        value: '${todaysClasses.length} টি',
                        icon: Icons.calendar_month_rounded,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatMiniCard(
                        label: 'উপস্থিত (আজ)',
                        value: '$presentCount/${students.length}',
                        icon: Icons.fact_check_rounded,
                        color: AppTheme.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatMiniCard(
                        label: 'আজ SMS পাঠানো',
                        value: '$smsToday টি',
                        icon: Icons.sms_rounded,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Monthly collection card ─────────────────
                _buildCollectionCard(
                  context,
                  monthLabel: monthYear.displayBn,
                  totalBilled: totalBilled,
                  totalCollected: totalCollected,
                  totalDue: totalDue,
                  rate: collectionRate,
                ),
                const SizedBox(height: 12),

                // ── Today's attendance card ─────────────────
                _buildAttendanceCard(
                  context,
                  label: attendanceLabel,
                  total: students.length,
                  present: presentCount,
                  absent: absentCount,
                  unmarked: unmarkedCount,
                ),
                const SizedBox(height: 12),

                // ── Today's classes card ────────────────────
                _buildTodaysClassesCard(context, todaysClasses),
                const SizedBox(height: 12),

                // ── Recent students card ────────────────────
                _buildRecentStudentsCard(context, recentStudents.take(4).toList()),
                const SizedBox(height: 18),

                _buildSectionTitle('ম্যানেজমেন্ট ও সার্ভিস'),
                const SizedBox(height: 10),
                _buildNavigationGrid(context),
                const SizedBox(height: 14),
                _buildQuickAddButton(context),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: AppTheme.bgDark,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)],
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tuition Manager',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  'কোচিং ড্যাশবোর্ড',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.success.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Live',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'লগ আউট',
          icon: const Icon(Icons.logout_rounded, color: Colors.white70),
          onPressed: () => _confirmLogout(context, ref),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'লগ আউট করবেন?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'আপনি বর্তমান সেশন থেকে বের হয়ে যাবেন। আবার একই নম্বর দিয়ে লগইন করা যাবে।',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'বাতিল',
              style: GoogleFonts.outfit(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'লগ আউট',
              style: GoogleFonts.outfit(
                color: AppTheme.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Invalidate first: once signOut() fires, AuthGate swaps the screen and
      // this widget's ref is no longer usable.
      ref.invalidate(teacherProfileProvider);
      await SupabaseService.client.auth.signOut();
    }
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader(String teacherName, String teacherPhone) {
    final now = DateTime.now();
    final dateBn = DateFormat('EEEE, d MMMM yyyy', 'bn').format(now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4B44CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  teacherName.isNotEmpty ? teacherName[0] : '?',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_greeting,',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      teacherName,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 13, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                dateBn,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              if (teacherPhone.isNotEmpty) ...[
                const SizedBox(width: 12),
                const Icon(Icons.phone_rounded,
                    size: 13, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  teacherPhone,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Monthly collection card ──────────────────────────────────
  Widget _buildCollectionCard(
    BuildContext context, {
    required String monthLabel,
    required double totalBilled,
    required double totalCollected,
    required double totalDue,
    required double rate,
  }) {
    return _DashboardCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FeeListScreen()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CardIcon(icon: Icons.payments_rounded, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$monthLabel ফি আদায়',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'আদায়ের হার ${(rate * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white38),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: double.infinity,
              height: 8,
              child: LinearProgressIndicator(
                value: rate,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.success),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MoneyStat(
                  label: 'মোট ধার্য',
                  value: '$_currency${totalBilled.toStringAsFixed(0)}',
                  color: Colors.white70,
                ),
              ),
              Expanded(
                child: _MoneyStat(
                  label: 'আদায় হয়েছে',
                  value: '$_currency${totalCollected.toStringAsFixed(0)}',
                  color: AppTheme.success,
                ),
              ),
              Expanded(
                child: _MoneyStat(
                  label: 'বকেয়া',
                  value: '$_currency${totalDue.toStringAsFixed(0)}',
                  color: totalDue > 0 ? AppTheme.danger : Colors.white38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Today's attendance card ──────────────────────────────────
  Widget _buildAttendanceCard(
    BuildContext context, {
    required String label,
    required int total,
    required int present,
    required int absent,
    required int unmarked,
  }) {
    final marked = total > 0 ? (present + absent) / total : 0.0;

    return _DashboardCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AttendanceScreen()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CardIcon(icon: Icons.fact_check_rounded, color: AppTheme.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white38),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MoneyStat(
                  label: 'উপস্থিত',
                  value: '$present জন',
                  color: AppTheme.success,
                ),
              ),
              Expanded(
                child: _MoneyStat(
                  label: 'অনুপস্থিত',
                  value: '$absent জন',
                  color: AppTheme.danger,
                ),
              ),
              Expanded(
                child: _MoneyStat(
                  label: 'হাজিরা বাকি',
                  value: '$unmarked জন',
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: double.infinity,
                height: 6,
                child: LinearProgressIndicator(
                  value: marked,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Today's classes card ─────────────────────────────────────
  Widget _buildTodaysClassesCard(
    BuildContext context,
    List<ClassRoutineModel> classes,
  ) {
    return _DashboardCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RoutineScreen()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CardIcon(icon: Icons.schedule_rounded, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'আজকের ক্লাস (${classes.length}টি)',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white38),
            ],
          ),
          const SizedBox(height: 10),
          if (classes.isEmpty)
            Text(
              'আজ কোনো ক্লাস শিডিউল নেই',
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
            )
          else
            ...classes.take(3).map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          r.timeRange,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r.subject,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (r.topic != null && r.topic!.isNotEmpty)
                        Flexible(
                          child: Text(
                            r.topic!,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ── Recent students card ─────────────────────────────────────
  Widget _buildRecentStudentsCard(
    BuildContext context,
    List<StudentModel> students,
  ) {
    return _DashboardCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StudentListScreen()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CardIcon(icon: Icons.people_alt_rounded, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'সাম্প্রতিক শিক্ষার্থী',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white38),
            ],
          ),
          const SizedBox(height: 10),
          if (students.isEmpty)
            Text(
              'এখনো কোনো শিক্ষার্থী ভর্তি হয়নি',
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
            )
          else
            ...students.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.2),
                        child: Text(
                          s.initials,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.fullName,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        s.grade,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ── Section title ────────────────────────────────────────────
  Widget _buildSectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ── Navigation grid ──────────────────────────────────────────
  Widget _buildNavigationGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 520;
        final aspectRatio = isWide ? 3.0 : 2.5;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: aspectRatio,
          children: [
            _CompactNavTile(
              title: 'Student List',
              titleBn: 'শিক্ষার্থী তালিকা',
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF6C63FF),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentListScreen()),
              ),
            ),
            _CompactNavTile(
              title: 'Attendance',
              titleBn: 'হাজিরা খাতা (SMS)',
              icon: Icons.fact_check_rounded,
              color: const Color(0xFF2ECC71),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AttendanceScreen()),
              ),
            ),
            _CompactNavTile(
              title: 'Fee Due Manager',
              titleBn: 'ফি ও বকেয়া রিমাইন্ডার',
              icon: Icons.payments_rounded,
              color: const Color(0xFFFF9900),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeeListScreen()),
              ),
            ),
            _CompactNavTile(
              title: 'Class Routine',
              titleBn: 'ক্লাস শিডিউল ও টপিক',
              icon: Icons.calendar_month_rounded,
              color: const Color(0xFF00B4D8),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoutineScreen()),
              ),
            ),
            _CompactNavTile(
              title: 'SMS History',
              titleBn: 'SMS ইতিহাস ও বাল্ক SMS',
              icon: Icons.sms_outlined,
              color: const Color(0xFFE91E63),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SmsHistoryScreen()),
              ),
            ),
            _CompactNavTile(
              title: 'Fee Report',
              titleBn: 'ফি রিপোর্ট',
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF009688),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeeReportScreen()),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Quick add banner ─────────────────────────────────────────
  Widget _buildQuickAddButton(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddEditStudentScreen()),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppTheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'নতুন শিক্ষার্থী ভর্তি করুন',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'নাম, ক্লাস ও মাসিক বেতন দিয়ে যোগ করুন',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.add_circle_outline_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared dashboard widgets ───────────────────────────────────
class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CardIcon extends StatelessWidget {
  const _CardIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _MoneyStat extends StatelessWidget {
  const _MoneyStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }
}

// ── Compact Mini Stat Card ───────────────────────────────────
class _StatMiniCard extends StatelessWidget {
  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 3),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 9,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Compact Navigation Tile ──────────────────────────────────
class _CompactNavTile extends StatelessWidget {
  const _CompactNavTile({
    required this.title,
    required this.titleBn,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String titleBn;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      titleBn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
