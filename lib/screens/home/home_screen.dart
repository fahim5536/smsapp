import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/fee_provider.dart';
import '../../providers/routine_provider.dart';
import '../../providers/student_provider.dart';
import '../attendance/attendance_screen.dart';
import '../fees/fee_list_screen.dart';
import '../routine/routine_screen.dart';
import '../students/add_edit_student_screen.dart';
import '../students/student_list_screen.dart';

/// Clean, compact and responsive Dashboard HomeScreen
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsStreamProvider);
    final routinesAsync = ref.watch(routinesStreamProvider);
    final feesAsync = ref.watch(monthlyFeesProvider);

    final totalStudents = studentsAsync.value?.length ?? 0;
    final totalRoutines = routinesAsync.value?.length ?? 0;

    int dueStudentsCount = 0;
    if (feesAsync.hasValue) {
      dueStudentsCount = feesAsync.value!.where((f) => !f.isFullyPaid).length;
    }

    final todayFormatted =
        DateFormat('EEE, d MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: _buildCustomAppBar(context),
      body: Center(
        // Centers and constrains layout so it never blows up on widescreen/desktop
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Compact Welcome Banner ───────────────────
                _buildCompactWelcome(todayFormatted),
                const SizedBox(height: 14),

                // ── Compact Stats Row ────────────────────────
                _buildCompactStatsRow(
                  totalStudents: totalStudents,
                  dueStudents: dueStudentsCount,
                  totalRoutines: totalRoutines,
                ),
                const SizedBox(height: 16),

                // ── Section Title ────────────────────────────
                Row(
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
                      'ম্যানেজমেন্ট ও সার্ভিস (Quick Navigation)',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Sleek Compact Navigation Tiles ───────────
                _buildNavigationList(context),
                const SizedBox(height: 14),

                // ── Compact Quick Action ─────────────────────
                _buildQuickAddButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Custom Compact AppBar ──────────────────────────────────
  PreferredSizeWidget _buildCustomAppBar(BuildContext context) {
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
          Column(
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
                'কোচিং ও ব্যাচ ড্যাশবোর্ড',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
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
      ],
    );
  }

  // ── Compact Welcome Banner ─────────────────────────────────
  Widget _buildCompactWelcome(String today) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.wb_sunny_outlined,
              color: Colors.amberAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'স্বাগতম, শিক্ষক মহাশয়! 👋',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  today,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_done_rounded,
                  size: 13,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 4),
                Text(
                  'Connected',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Compact Stats Row ──────────────────────────────────────
  Widget _buildCompactStatsRow({
    required int totalStudents,
    required int dueStudents,
    required int totalRoutines,
  }) {
    return Row(
      children: [
        Expanded(
          child: _StatMiniCard(
            label: 'মোট শিক্ষার্থী',
            value: '$totalStudents',
            icon: Icons.people_alt_rounded,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatMiniCard(
            label: 'বকেয়া বেতন',
            value: '$dueStudents জন',
            icon: Icons.pending_actions_rounded,
            color: AppTheme.danger,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatMiniCard(
            label: 'মোট শিডিউল',
            value: '$totalRoutines টি',
            icon: Icons.schedule_rounded,
            color: AppTheme.accent,
          ),
        ),
      ],
    );
  }

  // ── Sleek Compact Navigation Grid (Responsive 2-column or list)
  Widget _buildNavigationList(BuildContext context) {
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
            // 1. Student List
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

            // 2. Attendance Tracker
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

            // 3. Fee Due Manager
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

            // 4. Routine / Schedule
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
          ],
        );
      },
    );
  }

  // ── Compact Quick Add Student Banner ───────────────────────
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 10,
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
