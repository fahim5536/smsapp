import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/services/sms_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/sms_provider.dart';
import '../../providers/student_provider.dart';

class SmsHistoryScreen extends ConsumerWidget {
  const SmsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(smsLogProvider);
    final filterType = ref.watch(smsFilterTypeProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Text(
          '📜 SMS ইতিহাস (History)',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          PopupMenuButton<SmsType?>(
            tooltip: 'Filter by type',
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white70),
            onSelected: (type) =>
                ref.read(smsFilterTypeProvider.notifier).state = type,
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('সকল টাইপ (All)')),
              const PopupMenuDivider(),
              ...SmsType.values.map(
                (type) => PopupMenuItem(
                  value: type,
                  child: Text(_getTypeLabel(type)),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Clear history',
            icon: const Icon(
              Icons.delete_sweep_outlined,
              color: Colors.white70,
            ),
            onPressed: () => _confirmClearLogs(context, ref),
          ),
        ],
      ),
      body: logsAsync.when(
        data: (logs) {
          final filteredLogs = filterType == null
              ? logs
              : logs.where((log) => log.type == filterType).toList();

          if (filteredLogs.isEmpty) {
            return _buildEmptyState(context, logs.isEmpty);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: filteredLogs.length,
            itemBuilder: (context, index) {
              final log = filteredLogs[index];
              return _SmsLogCard(log: log);
            },
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => _showBulkSmsDialog(context, ref),
        icon: const Icon(Icons.send_rounded),
        label: Text(
          'বাল্ক SMS (Bulk SMS)',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool hasNoLogsAtAll) {
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
            child: const Icon(
              Icons.sms_outlined,
              size: 56,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasNoLogsAtAll
                ? 'কোনো SMS ইতিহাস নেই'
                : 'এই ফিল্টারের জন্য কোনো লগ নেই',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasNoLogsAtAll
                ? 'SMS পাঠালে এখানে দেখাবে।'
                : 'অন্য ফিল্টার বেছে নিন।',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(SmsType type) {
    switch (type) {
      case SmsType.absent:
        return 'অনুপস্থিত (Absent)';
      case SmsType.feeDue:
        return 'ফি বকেয়া (Fee Due)';
      case SmsType.feePaid:
        return 'ফি পরিশোধ (Fee Paid)';
      case SmsType.routine:
        return 'রুটিন (Routine)';
      case SmsType.welcome:
        return 'স্বাগত (Welcome)';
      case SmsType.exam:
        return 'পরীক্ষা (Exam)';
      case SmsType.custom:
        return 'কাস্টম (Custom)';
      case SmsType.bulk:
        return 'বাল্ক (Bulk)';
    }
  }

  Future<void> _confirmClearLogs(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'ইতিহাস মুছে ফেলবেন?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'সকল SMS ইতিহাস স্থায়ীভাবে মুছে যাবে।',
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
              'মুছে ফেলুন',
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
      await ref.read(smsLogProvider.notifier).clearLogs();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text(
              '✓ ইতিহাস মুছে ফেলা হয়েছে',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  void _showBulkSmsDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _BulkSmsDialog(),
    );
  }
}

class _BulkSmsDialog extends ConsumerStatefulWidget {
  const _BulkSmsDialog();

  @override
  ConsumerState<_BulkSmsDialog> createState() => _BulkSmsDialogState();
}

class _BulkSmsDialogState extends ConsumerState<_BulkSmsDialog> {
  String _selectedTemplate = SmsService.templateAbsent;
  final TextEditingController _customMessageCtrl = TextEditingController();
  final List<BulkSmsRecipient> _recipients = [];
  bool _isSending = false;
  BulkSmsResult? _result;

  @override
  void dispose() {
    _customMessageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsStreamProvider);
    final coachingName = ref.watch(coachingNameProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'বাল্ক SMS পাঠান',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Template Selector
          DropdownButtonFormField<String>(
            initialValue: _selectedTemplate,
            dropdownColor: AppTheme.cardDark,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'টেমপ্লেট বেছে নিন',
              prefixIcon: Icon(Icons.description_outlined),
            ),
            items: SmsService.getAvailableTemplates().map((key) {
              return DropdownMenuItem(
                value: key,
                child: Text(SmsService.getTemplateDescription(key)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedTemplate = val;
                  _customMessageCtrl.text = SmsService.getTemplate(val);
                });
              }
            },
          ),
          const SizedBox(height: 12),

          // Template Variables Help
          if (SmsService.getTemplateVariables(_selectedTemplate).isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'উপলব্ধ ভেরিয়েবল (Variables):',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: SmsService.getTemplateVariables(_selectedTemplate)
                        .map(
                          (v) => Chip(
                            label: Text(
                              '{{$v}}',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: AppTheme.primary.withValues(
                              alpha: 0.2,
                            ),
                            side: BorderSide(
                              color: AppTheme.primary.withValues(alpha: 0.4),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Custom Message Editor (for custom template)
          if (_selectedTemplate == SmsService.templateCustom) ...[
            TextField(
              controller: _customMessageCtrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'কাস্টম মেসেজ লিখুন',
                hintText: 'ভেরিয়েবল ব্যবহার করুন: {{student_name}}, {{due_amount}}, ইত্যাদি',
                prefixIcon: Icon(Icons.edit_rounded),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Recipient Selection
          Text(
            'প্রাপ্তকারী বেছে নিন (${_recipients.length} জন নির্বাচিত)',
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 8),

          // Students list for selection
          SizedBox(
            height: 200,
            child: studentsAsync.when(
              data: (students) {
                if (students.isEmpty) {
                  return Center(
                    child: Text(
                      'কোনো শিক্ষার্থী নেই',
                      style: GoogleFonts.outfit(color: Colors.white38),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final isSelected = _recipients.any(
                      (r) => r.phone == student.parentPhone,
                    );
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _recipients.add(
                              BulkSmsRecipient.fromStudent(
                                phone: student.parentPhone,
                                studentName: student.fullName,
                              ),
                            );
                          } else {
                            _recipients.removeWhere(
                              (r) => r.phone == student.parentPhone,
                            );
                          }
                        });
                      },
                      title: Text(
                        student.fullName,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        student.parentPhone,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                      secondary: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primary.withValues(
                          alpha: 0.2,
                        ),
                        child: Text(
                          student.initials,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      activeColor: AppTheme.primary,
                      checkColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      dense: true,
                    );
                  },
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

          const SizedBox(height: 16),

          // Action Buttons
          if (_result != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _result!.allSent
                    ? AppTheme.success.withValues(alpha: 0.2)
                    : AppTheme.danger.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _result!.allSent ? AppTheme.success : AppTheme.danger,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _result!.allSent
                        ? Icons.check_circle_rounded
                        : Icons.warning_rounded,
                    color: _result!.allSent
                        ? AppTheme.success
                        : AppTheme.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'পাঠানো হয়েছে: ${_result!.sent}/${_result!.total} | ব্যর্থ: ${_result!.failed}',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  label: Text(
                    'বাতিল',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: _isSending || _recipients.isEmpty
                      ? null
                      : () => _sendBulkSms(context, ref, coachingName),
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSending ? 'পাঠাচ্ছি...' : 'SMS পাঠান',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendBulkSms(
    BuildContext context,
    WidgetRef ref,
    String coachingName,
  ) async {
    setState(() => _isSending = true);

    final commonVariables = <String, dynamic>{};

    // Extract variables from custom message if using custom template
    if (_selectedTemplate == SmsService.templateCustom) {
      // Could parse variables from custom message
    }

    try {
      final result = await SmsService.sendBulkSms(
        recipients: _recipients,
        templateKey: _selectedTemplate,
        commonVariables: commonVariables,
        customCoachingName: coachingName,
        onProgress: (sent, total) {
          // Could show progress
        },
      );

      // Log each sent SMS
      for (final recipient in _recipients) {
        await ref
            .read(smsLogProvider.notifier)
            .addLog(
              SmsLogEntry(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                phone: recipient.phone,
                studentName: recipient.studentName,
                message: 'Bulk SMS: $_selectedTemplate',
                type: SmsType.bulk,
                status: SmsStatus.sent,
                sentAt: DateTime.now(),
              ),
            );
      }

      if (mounted) {
        setState(() {
          _isSending = false;
          _result = result;
        });
      }

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: result.allSent
                ? AppTheme.success
                : AppTheme.danger,
            content: Text(
              result.allSent
                  ? '✓ সকল SMS পাঠানো হয়েছে (${result.sent}/${result.total})'
                  : 'আংশিক সফল: ${result.sent}/${result.total} পাঠানো হয়েছে',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
      }
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text(
              'ত্রুটি: $e',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
      }
    }
  }
}

// ── SMS Log Card ────────────────────────────────────────────────
class _SmsLogCard extends ConsumerWidget {
  const _SmsLogCard({required this.log});
  final SmsLogEntry log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _getStatusColor(log.status);
    final typeIcon = _getTypeIcon(log.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getTypeColor(log.type).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(typeIcon, size: 16, color: _getTypeColor(log.type)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.studentName,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      log.phone,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getStatusLabel(log.status),
                  style: GoogleFonts.outfit(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            log.message,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.white70,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('dd MMM yyyy, hh:mm a', 'bn').format(log.sentAt),
                style: GoogleFonts.outfit(fontSize: 10, color: Colors.white38),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'পুনরায় পাঠান',
                    icon: const Icon(
                      Icons.replay_rounded,
                      size: 18,
                      color: Colors.white38,
                    ),
                    onPressed: () => _resendSms(context, ref, log),
                  ),
                  IconButton(
                    tooltip: 'কপি করুন',
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: Colors.white38,
                    ),
                    onPressed: () => _copyMessage(context, log.message),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(SmsType type) {
    switch (type) {
      case SmsType.absent:
        return AppTheme.danger;
      case SmsType.feeDue:
        return Colors.amber;
      case SmsType.feePaid:
        return AppTheme.success;
      case SmsType.routine:
        return AppTheme.accent;
      case SmsType.welcome:
        return AppTheme.primary;
      case SmsType.exam:
        return Colors.purpleAccent;
      case SmsType.custom:
        return Colors.tealAccent;
      case SmsType.bulk:
        return Colors.deepOrangeAccent;
    }
  }

  IconData _getTypeIcon(SmsType type) {
    switch (type) {
      case SmsType.absent:
        return Icons.person_off_rounded;
      case SmsType.feeDue:
        return Icons.money_off_rounded;
      case SmsType.feePaid:
        return Icons.payments_rounded;
      case SmsType.routine:
        return Icons.schedule_rounded;
      case SmsType.welcome:
        return Icons.person_add_rounded;
      case SmsType.exam:
        return Icons.quiz_rounded;
      case SmsType.custom:
        return Icons.edit_rounded;
      case SmsType.bulk:
        return Icons.send_rounded;
    }
  }

  Color _getStatusColor(SmsStatus status) {
    switch (status) {
      case SmsStatus.sent:
        return AppTheme.success;
      case SmsStatus.failed:
        return AppTheme.danger;
      case SmsStatus.pending:
        return Colors.amber;
      case SmsStatus.scheduled:
        return AppTheme.accent;
    }
  }

  String _getStatusLabel(SmsStatus status) {
    switch (status) {
      case SmsStatus.sent:
        return 'পাঠানো হয়েছে';
      case SmsStatus.failed:
        return 'ব্যর্থ';
      case SmsStatus.pending:
        return 'লম্বিত';
      case SmsStatus.scheduled:
        return 'নির্ধারিত';
    }
  }

  Future<void> _resendSms(
    BuildContext context,
    WidgetRef ref,
    SmsLogEntry log,
  ) async {
    final sent = await SmsService.sendCustomSms(
      phone: log.phone,
      message: log.message,
    );
    await ref.read(smsLogProvider.notifier).logSms(
          phone: log.phone,
          studentName: log.studentName,
          message: log.message,
          type: log.type,
          success: sent,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: sent ? AppTheme.success : AppTheme.danger,
          content: Text(
            sent
                ? '✓ SMS অ্যাপ খোলা হয়েছে: ${log.phone}'
                : 'SMS পাঠানো সম্ভব হয়নি (${log.phone})',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _copyMessage(BuildContext context, String message) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'মেসেজ কপি করা হয়েছে',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
        ),
      );
    }
  }
}
