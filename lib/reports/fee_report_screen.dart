import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/fee_provider.dart';
import '../../providers/student_provider.dart';
import '../../reports/fee_report_service.dart';

class FeeReportScreen extends ConsumerWidget {
  const FeeReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthYear = ref.watch(selectedFeeMonthYearProvider);
    final feesAsync = ref.watch(monthlyFeesProvider);
    final studentsAsync = ref.watch(studentsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Text(
          '📊 ফি রিপোর্ট (Fee Report)',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(monthlyFeesProvider);
          ref.invalidate(studentsStreamProvider);
        },
        child: feesAsync.when(
          data: (feeRecords) {
            final students = studentsAsync.value ?? [];
            final report = FeeReportService.generateMonthlyReport(
              feeRecords: feeRecords,
              students: students,
              month: monthYear.month,
              year: monthYear.year,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Report header
                  _buildReportHeader(report),
                  const SizedBox(height: 24),

                  // Summary cards
                  _buildSummaryCards(report),
                  const SizedBox(height: 24),

                  // Collection rate
                  _buildCollectionRate(report),
                  const SizedBox(height: 24),

                  // Due students list
                  _buildDueStudentsSection(report),
                  const SizedBox(height: 24),

                  // Grade-wise breakdown
                  _buildGradeWiseSection(report),
                  const SizedBox(height: 24),

                  // Export button
                  _buildExportButton(context, report),
                ],
              ),
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
        ),
      ),
    );
  }

  Widget _buildReportHeader(Map<String, dynamic> report) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: AppTheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ' ${report['displayBn']}',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      ' ${report['month']}/${report['year']}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Monthly Fee Collection Report',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Colors.white54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> report) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: 'মোট ধার্য',
            value: FeeReportService.formatCurrency(report['totalBilled']),
            icon: Icons.receipt_long_rounded,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            title: 'সংগৃহিত',
            value: FeeReportService.formatCurrency(report['totalCollected']),
            icon: Icons.payments_rounded,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            title: 'বকেয়া',
            value: FeeReportService.formatCurrency(report['totalDue']),
            icon: Icons.pending_actions_rounded,
            color: AppTheme.danger,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionRate(Map<String, dynamic> report) {
    final rate = report['collectionRate'] as double;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.percent_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'আদায়ের হার (Collection Rate)',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              Text(
                '/ 100%',
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: double.infinity,
              height: 8,
              child: LinearProgressIndicator(
                value: rate / 100,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.success),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            FeeReportService.getCollectionRateText(rate),
            style: GoogleFonts.outfit(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildDueStudentsSection(Map<String, dynamic> report) {
    final dueStudents = report['dueStudents'] as List<dynamic>;
    final dueCount = report['dueCount'] as int;

    if (dueStudents.isEmpty) {
      return _buildEmptyState('এই মাসে কোনো বকেয়া নেই!');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 20),
            const SizedBox(width: 8),
            Text(
              '$dueCount জন বকেয়া শিক্ষার্থী',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...dueStudents
            .map(
              (student) => _dueStudentTile(
                name: student['studentName'] as String,
                grade: student['grade'] as String?,
                dueAmount: student['dueAmount'] as double?,
                totalAmount: student['totalAmount'] as double?,
              ),
            )

      ],
    );
  }

  Widget _buildGradeWiseSection(Map<String, dynamic> report) {
    final gradeWise = report['gradeWise'] as Map<String, dynamic>?;

    if (gradeWise == null || gradeWise.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.insert_chart_rounded, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              'Grade-wise Breakdown',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...gradeWise.entries
            .map(
              (entry) => _gradeWiseTile(
                grade: entry.key,
                totalBilled:
                    (entry.value['totalBilled'] as num?)?.toDouble() ?? 0,
                totalCollected:
                    (entry.value['totalCollected'] as num?)?.toDouble() ?? 0,
                dueCount: entry.value['dueCount'] as int?,
                paidCount: entry.value['paidCount'] as int?,
                studentCount: entry.value['studentCount'] as int?,
              ),
            )

      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 16, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _dueStudentTile({
    required String name,
    required String? grade,
    required double? dueAmount,
    required double? totalAmount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (grade != null && grade.isNotEmpty)
                    Text(
                      'ক্লাস: $grade',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '৳${dueAmount?.toStringAsFixed(0) ?? '0'} / ৳${totalAmount?.toStringAsFixed(0) ?? '0'}',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.danger,
              ),
            ),
            Icon(Icons.close_rounded, color: AppTheme.danger, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _gradeWiseTile({
    required String grade,
    required double totalBilled,
    required double totalCollected,
    required int? dueCount,
    required int? paidCount,
    required int? studentCount,
  }) {
    final due = dueCount ?? 0;
    final paid = paidCount ?? 0;
    final total = studentCount ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Avatar with grade color
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
              child: Text(
                grade.isNotEmpty ? grade[0] : '?',
                style: GoogleFonts.outfit(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ক্লাস: $grade',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '($total students)',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: Colors.white54,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '৳${totalBilled.toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '৳${totalCollected.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
                Text(
                  '$paid paid',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                ),
                Text(
                  '$due due',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: AppTheme.danger,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildCsv(Map<String, dynamic> report) {
    final buf = StringBuffer();
    buf.writeln('Fee Report,${report['displayBn']}');
    buf.writeln('Generated,${DateTime.now().toLocal()}');
    buf.writeln('');
    buf.writeln('Total Billed,${report['totalBilled']}');
    buf.writeln('Total Collected,${report['totalCollected']}');
    buf.writeln('Total Due,${report['totalDue']}');
    buf.writeln('Paid Students,${report['paidCount']}');
    buf.writeln('Due Students,${report['dueCount']}');
    buf.writeln('Collection Rate,${(report['collectionRate'] as double).toStringAsFixed(1)}%');
    buf.writeln('');
    buf.writeln('Due Students');
    buf.writeln('Name,Grade,Due,Paid,Total');
    for (final s in (report['dueStudents'] as List<dynamic>)) {
      final row = s as Map<String, dynamic>;
      buf.writeln(
        '${row['studentName']},${row['grade']},${row['dueAmount']},${row['paidAmount']},${row['totalAmount']}',
      );
    }
    buf.writeln('');
    buf.writeln('Grade-wise Breakdown');
    buf.writeln('Grade,Billed,Collected,Paid,Due,Students');
    for (final e in (report['gradeWise'] as Map<String, dynamic>).entries) {
      final g = e.value as Map<String, dynamic>;
      buf.writeln(
        '${e.key},${g['totalBilled']},${g['totalCollected']},${g['paidCount']},${g['dueCount']},${g['studentCount']}',
      );
    }
    return buf.toString();
  }

  Widget _buildExportButton(BuildContext context, Map<String, dynamic> report) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      child: ElevatedButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: _buildCsv(report)));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.success,
                content: Text(
                  '✓ রিপোর্ট কপি হয়েছে — এখন যেকোনো জায়গায় (Excel/Sheets/নোট) পেস্ট করুন',
                  style: GoogleFonts.outfit(color: Colors.white),
                ),
              ),
            );
          }
        },
        icon: const Icon(Icons.copy_rounded),
        label: Text(
          'রিপোর্ট কপি করুন (CSV)',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
    );
  }
}
