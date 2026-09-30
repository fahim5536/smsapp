import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/student_model.dart';
import '../../providers/student_provider.dart';
import 'add_edit_student_screen.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start from the current query (e.g. after returning to this screen).
    _searchCtrl.text = ref.read(studentSearchQueryProvider);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    ref.read(studentSearchQueryProvider.notifier).clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(filteredStudentsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: _buildAppBar(context),
      body: studentsAsync.when(
        data: (students) => students.isEmpty
            ? _EmptyState()
            : _StudentGrid(students: students),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (e, _) => _ErrorState(message: e.toString()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddStudent(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add_rounded),
        label: Text(
          'Add Student',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.bgDark,
      title: Text(
        '📚 My Students',
        style: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) =>
                ref.read(studentSearchQueryProvider.notifier).update(v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name, class or subject…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Colors.white38),
              suffixIcon: Consumer(
                builder: (_, ref, _) {
                  final q = ref.watch(studentSearchQueryProvider);
                  return q.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref
                                .read(studentSearchQueryProvider.notifier)
                                .clear();
                          },
                        )
                      : const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openAddStudent(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditStudentScreen()),
    );
  }
}

// ── Student Grid ───────────────────────────────────────────────
class _StudentGrid extends StatelessWidget {
  const _StudentGrid({required this.students});
  final List<StudentModel> students;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            '${students.length} student${students.length == 1 ? '' : 's'}',
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            itemCount: students.length,
            itemBuilder: (_, i) => _StudentCard(student: students[i]),
          ),
        ),
      ],
    );
  }
}

// ── Student Card ───────────────────────────────────────────────
class _StudentCard extends ConsumerWidget {
  const _StudentCard({required this.student});
  final StudentModel student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feeFormatted =
        NumberFormat.currency(symbol: '৳', decimalDigits: 0).format(student.monthlyFee);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditStudentScreen(student: student),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                _Avatar(initials: student.initials),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _InfoRow(
                        icon: Icons.school_rounded,
                        label: '${student.grade} · ${student.subject}',
                      ),
                      const SizedBox(height: 3),
                      _InfoRow(
                        icon: Icons.phone_rounded,
                        label: student.parentPhone,
                      ),
                      if (student.schedule != null &&
                          student.schedule!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _InfoRow(
                          icon: Icons.schedule_rounded,
                          label: student.schedule!,
                        ),
                      ],
                    ],
                  ),
                ),
                // Fee badge + actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        feeFormatted,
                        style: GoogleFonts.outfit(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DeleteButton(studentId: student.id, name: student.fullName),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Avatar ─────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});
  final String initials;

  static const _colors = [
    Color(0xFF6C63FF),
    Color(0xFFFF6584),
    Color(0xFF43B89C),
    Color(0xFFF7971E),
    Color(0xFF2193B0),
  ];

  Color get _color => _colors[initials.codeUnitAt(0) % _colors.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.outfit(
            color: _color,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

// ── InfoRow ────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.white38),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ── Delete Button ──────────────────────────────────────────────
class _DeleteButton extends ConsumerWidget {
  const _DeleteButton({required this.studentId, required this.name});
  final String studentId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _confirmDelete(context, ref),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppTheme.danger, size: 18),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Student',
          style: GoogleFonts.outfit(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to permanently delete "$name"?\n\nThis will also remove all their attendance and fee records.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.outfit(
                    color: AppTheme.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await ref
          .read(studentMutationProvider.notifier)
          .deleteStudent(studentId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? AppTheme.success : AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text(
              success ? '✓ Student deleted' : '✗ Failed to delete student',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
      }
    }
  }
}

// ── Empty State ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline_rounded,
                size: 56, color: AppTheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'No students yet',
            style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to add\nyour first student.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Error State ────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.danger),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
