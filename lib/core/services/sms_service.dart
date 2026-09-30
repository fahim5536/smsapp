import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Enhanced SMS Service with templates, bulk SMS, history, and scheduling
class SmsService {
  SmsService._();

  /// Default coaching name used in SMS footer
  static String coachingName = 'উদ্দীপন কোচিং সেন্টার';

  // ─────────────────────────────────────────────────────────────
  // SMS TEMPLATE SYSTEM
  // ─────────────────────────────────────────────────────────────

  /// Built-in template keys
  static const String templateAbsent = 'absent_notification';
  static const String templateFeeDue = 'fee_due_reminder';
  static const String templateRoutine = 'routine_update';
  static const String templateFeePaid = 'fee_paid_confirmation';
  static const String templateWelcome = 'welcome_student';
  static const String templateExam = 'exam_notification';
  static const String templateCustom = 'custom';

  /// Default templates with variable placeholders
  static final Map<String, String> _defaultTemplates = {
    templateAbsent:
        'সম্মানিত অভিভাবক, আপনার সন্তান {{student_name}} {{date}} কোচিংয়ে উপস্থিত নেই। - {{coaching_name}}',
    templateFeeDue:
        'সম্মানিত অভিভাবক, {{month_year}} মাসের জন্য {{student_name}}-এর কোচিং ফি {{due_amount}} বকেয়া রয়েছে। অনুগ্রহ করে দ্রুত পরিশোধ করার অনুরোধ করা হলো। - {{coaching_name}}',
    templateFeePaid:
        'সম্মানিত অভিভাবক, {{student_name}}-এর {{month_year}} মাসের ফি {{paid_amount}} গ্রহণ করা হয়েছে। ধন্যবাদ। - {{coaching_name}}',
    templateRoutine:
        'বিজ্ঞপ্তি: {{day_or_date}}-এর ক্লাস শিডিউল:\nবিষয়: {{subject}}\nসময়: {{time_range}}\n{{#if topic}}টপিক: {{topic}}\n{{/if}}- {{coaching_name}}',
    templateWelcome:
        'স্বাগতম {{student_name}}! আপনি {{coaching_name}}-এ {{grade}} {{subject}} ব্যাচে ভর্তি হয়েছেন। ক্লাস: {{schedule}}। - {{coaching_name}}',
    templateExam:
        'বিজ্ঞপ্তি: {{exam_name}} পরীক্ষা {{exam_date}}-এ অনুষ্ঠিত হবে। বিষয়: {{subject}}। সকল শিক্ষার্থীকে উপস্থিত থাকতে বলা হয়েছে। - {{coaching_name}}',
  };

  /// Get template by key (falls back to default)
  static String getTemplate(String key) {
    return _defaultTemplates[key] ?? '';
  }

  /// Reset to default template
  static void resetTemplate(String key) {
    if (_defaultTemplates.containsKey(key)) {
      // Keep default - in real app, load from storage
    }
  }

  /// Render template with variables
  static String renderTemplate(
    String template, {
    required Map<String, dynamic> variables,
  }) {
    String result = template;

    // Simple variable replacement {{variable_name}}
    for (final entry in variables.entries) {
      final placeholder = '{{${entry.key}}}';
      final value = entry.value?.toString() ?? '';
      result = result.replaceAll(placeholder, value);
    }

    // Handle conditional blocks {{#if variable}}...{{/if}}
    final conditionalRegex = RegExp(r'\{\{#if\s+(\w+)\}\}(.*?)\{\{/if\}\}', dotAll: true);
    result = result.replaceAllMapped(conditionalRegex, (match) {
      final varName = match.group(1)!;
      final content = match.group(2)!;
      final hasValue = variables[varName] != null &&
          variables[varName].toString().isNotEmpty;
      return hasValue ? content : '';
    });

    // Strip any placeholder that had no matching variable, so the
    // recipient never sees raw {{tokens}} in the message.
    result = result.replaceAll(RegExp(r'\{\{\s*#?\w*\s*\}\}'), '');

    // Tidy up blank lines left behind by stripped conditional blocks.
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    return result;
  }

  // ─────────────────────────────────────────────────────────────
  // 1. ABSENT NOTIFICATION
  // ─────────────────────────────────────────────────────────────
  static String generateAbsentMessage({
    required String studentName,
    String? customCoachingName,
    DateTime? date,
  }) {
    final institute = (customCoachingName != null && customCoachingName.trim().isNotEmpty)
        ? customCoachingName.trim()
        : coachingName;

    final dateStr = date != null
        ? DateFormat('d MMMM yyyy', 'bn').format(date)
        : DateFormat('d MMMM yyyy', 'bn').format(DateTime.now());

    return renderTemplate(getTemplate(templateAbsent), variables: {
      'student_name': studentName,
      'date': dateStr,
      'coaching_name': institute,
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 2. FEE DUE REMINDER
  // ─────────────────────────────────────────────────────────────
  static String generateFeeDueMessage({
    required String studentName,
    required double dueAmount,
    required String monthYear,
    String? customCoachingName,
  }) {
    final institute = (customCoachingName != null && customCoachingName.trim().isNotEmpty)
        ? customCoachingName.trim()
        : coachingName;

    final amountFormatted = NumberFormat.currency(symbol: '৳', decimalDigits: 0).format(dueAmount);

    return renderTemplate(getTemplate(templateFeeDue), variables: {
      'student_name': studentName,
      'due_amount': amountFormatted,
      'month_year': monthYear,
      'coaching_name': institute,
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 3. FEE PAID CONFIRMATION
  // ─────────────────────────────────────────────────────────────
  static String generateFeePaidMessage({
    required String studentName,
    required double paidAmount,
    required String monthYear,
    String? customCoachingName,
  }) {
    final institute = (customCoachingName != null && customCoachingName.trim().isNotEmpty)
        ? customCoachingName.trim()
        : coachingName;

    final amountFormatted = NumberFormat.currency(symbol: '৳', decimalDigits: 0).format(paidAmount);

    return renderTemplate(getTemplate(templateFeePaid), variables: {
      'student_name': studentName,
      'paid_amount': amountFormatted,
      'month_year': monthYear,
      'coaching_name': institute,
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 4. CLASS ROUTINE / SCHEDULE UPDATE
  // ─────────────────────────────────────────────────────────────
  static String generateRoutineMessage({
    required String subject,
    required String timeRange,
    String? topic,
    String? dayOrDate,
    String? customCoachingName,
  }) {
    final institute = (customCoachingName != null && customCoachingName.trim().isNotEmpty)
        ? customCoachingName.trim()
        : coachingName;

    return renderTemplate(getTemplate(templateRoutine), variables: {
      'subject': subject,
      'time_range': timeRange,
      'topic': topic ?? '',
      'day_or_date': dayOrDate ?? '',
      'coaching_name': institute,
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 5. CUSTOM MESSAGE
  // ─────────────────────────────────────────────────────────────
  static Future<bool> sendCustomSms({
    required String phone,
    required String message,
  }) async {
    return launchSms(phone: phone, message: message);
  }

  // ─────────────────────────────────────────────────────────────
  // 6. BULK SMS
  // ─────────────────────────────────────────────────────────────

  /// Result of bulk SMS operation
  static Future<BulkSmsResult> sendBulkSms({
    required List<BulkSmsRecipient> recipients,
    required String templateKey,
    required Map<String, dynamic> commonVariables,
    String? customCoachingName,
    Function(int sent, int total)? onProgress,
  }) async {
    int sent = 0;
    int failed = 0;
    final List<String> failedNumbers = [];

    for (int i = 0; i < recipients.length; i++) {
      final recipient = recipients[i];
      final variables = {
        ...commonVariables,
        ...recipient.variables,
        'student_name': recipient.studentName,
      };

      String message;
      switch (templateKey) {
        case templateAbsent:
          message = generateAbsentMessage(
            studentName: recipient.studentName,
            customCoachingName: customCoachingName,
          );
          break;
        case templateFeeDue:
          message = generateFeeDueMessage(
            studentName: recipient.studentName,
            dueAmount: (variables['due_amount'] as num?)?.toDouble() ?? 0,
            monthYear: variables['month_year']?.toString() ?? '',
            customCoachingName: customCoachingName,
          );
          break;
        case templateRoutine:
          message = generateRoutineMessage(
            subject: variables['subject']?.toString() ?? '',
            timeRange: variables['time_range']?.toString() ?? '',
            topic: variables['topic']?.toString(),
            dayOrDate: variables['day_or_date']?.toString(),
            customCoachingName: customCoachingName,
          );
          break;
        default:
          message = renderTemplate(getTemplate(templateKey), variables: variables);
      }

      final success = await launchSms(phone: recipient.phone, message: message);
      if (success) {
        sent++;
      } else {
        failed++;
        failedNumbers.add(recipient.phone);
      }

      onProgress?.call(sent + failed, recipients.length);

      // Small delay to avoid overwhelming the SMS app
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return BulkSmsResult(
      total: recipients.length,
      sent: sent,
      failed: failed,
      failedNumbers: failedNumbers,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 7. CORE NATIVE LAUNCHER HELPER
  // ─────────────────────────────────────────────────────────────
  static Future<bool> launchSms({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleanPhone.isEmpty) {
      debugPrint('[SmsService] Phone number is empty');
      return false;
    }

    try {
      final uri = Uri(
        scheme: 'sms',
        path: cleanPhone,
        queryParameters: <String, String>{
          'body': message,
        },
      );

      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final fallbackUri = Uri.parse(
          'sms:$cleanPhone?body=${Uri.encodeComponent(message)}',
        );
        return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[SmsService] Failed to launch SMS: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 8. TEMPLATE MANAGEMENT
  // ─────────────────────────────────────────────────────────────

  /// Get all available template keys
  static List<String> getAvailableTemplates() {
    return _defaultTemplates.keys.toList();
  }

  /// Get template description for UI
  static String getTemplateDescription(String key) {
    switch (key) {
      case templateAbsent:
        return 'অনুপস্থিত বিজ্ঞপ্তি (Absent Notification)';
      case templateFeeDue:
        return 'ফি বকেয়া রিমাইন্ডার (Fee Due Reminder)';
      case templateFeePaid:
        return 'ফি পরিশোধিত নিশ্চিতকরণ (Fee Paid Confirmation)';
      case templateRoutine:
        return 'ক্লাস রুটিন আপডেট (Routine Update)';
      case templateWelcome:
        return 'স্বাগত বার্তা (Welcome Message)';
      case templateExam:
        return 'পরীক্ষা বিজ্ঞপ্তি (Exam Notification)';
      case templateCustom:
        return 'কাস্টম মেসেজ (Custom Message)';
      default:
        return key;
    }
  }

  /// Get template variables for UI
  static List<String> getTemplateVariables(String key) {
    switch (key) {
      case templateAbsent:
        return ['student_name', 'date', 'coaching_name'];
      case templateFeeDue:
        return ['student_name', 'due_amount', 'month_year', 'coaching_name'];
      case templateFeePaid:
        return ['student_name', 'paid_amount', 'month_year', 'coaching_name'];
      case templateRoutine:
        return ['subject', 'time_range', 'topic', 'day_or_date', 'coaching_name'];
      case templateWelcome:
        return ['student_name', 'grade', 'subject', 'schedule', 'coaching_name'];
      case templateExam:
        return ['exam_name', 'exam_date', 'subject', 'coaching_name'];
      default:
        return [];
    }
  }
}

// ─────────────────────────────────────────────────────────────
// SUPPORTING MODELS
// ─────────────────────────────────────────────────────────────

/// Recipient for bulk SMS
class BulkSmsRecipient {
  final String phone;
  final String studentName;
  final Map<String, dynamic> variables;

  const BulkSmsRecipient({
    required this.phone,
    required this.studentName,
    this.variables = const {},
  });

  factory BulkSmsRecipient.fromStudent({
    required String phone,
    required String studentName,
    Map<String, dynamic>? extraVariables,
  }) {
    return BulkSmsRecipient(
      phone: phone,
      studentName: studentName,
      variables: extraVariables ?? {},
    );
  }
}

/// Result of bulk SMS operation
class BulkSmsResult {
  final int total;
  final int sent;
  final int failed;
  final List<String> failedNumbers;

  const BulkSmsResult({
    required this.total,
    required this.sent,
    required this.failed,
    required this.failedNumbers,
  });

  double get successRate => total > 0 ? sent / total : 0.0;

  bool get allSent => failed == 0;

  @override
  String toString() =>
      'BulkSmsResult(total: $total, sent: $sent, failed: $failed, successRate: ${(successRate * 100).toStringAsFixed(1)}%)';
}

/// SMS Log entry for history tracking
class SmsLogEntry {
  final String id;
  final String phone;
  final String studentName;
  final String message;
  final SmsType type;
  final SmsStatus status;
  final DateTime sentAt;
  final String? errorMessage;

  const SmsLogEntry({
    required this.id,
    required this.phone,
    required this.studentName,
    required this.message,
    required this.type,
    required this.status,
    required this.sentAt,
    this.errorMessage,
  });

  factory SmsLogEntry.fromJson(Map<String, dynamic> json) {
    return SmsLogEntry(
      id: json['id'] as String,
      phone: json['phone'] as String,
      studentName: json['student_name'] as String,
      message: json['message'] as String,
      type: SmsType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SmsType.custom,
      ),
      status: SmsStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SmsStatus.pending,
      ),
      sentAt: DateTime.parse(json['sent_at'] as String),
      errorMessage: json['error_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'student_name': studentName,
        'message': message,
        'type': type.name,
        'status': status.name,
        'sent_at': sentAt.toIso8601String(),
        'error_message': errorMessage,
      };
}

enum SmsType {
  absent,
  feeDue,
  feePaid,
  routine,
  welcome,
  exam,
  custom,
  bulk,
}

enum SmsStatus {
  pending,
  sent,
  failed,
  scheduled,
}