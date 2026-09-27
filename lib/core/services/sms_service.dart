import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper service to handle triggering SMS messages to guardians & students
class SmsService {
  SmsService._();

  /// Default coaching name used in SMS footer
  static String coachingName = 'উদ্দীপন কোচিং সেন্টার';

  // ─────────────────────────────────────────────────────────────
  // 1. ABSENT NOTIFICATION
  // ─────────────────────────────────────────────────────────────
  static String generateAbsentMessage({
    required String studentName,
    String? customCoachingName,
  }) {
    final institute = (customCoachingName != null && customCoachingName.trim().isNotEmpty)
        ? customCoachingName.trim()
        : coachingName;

    return 'সম্মানিত অভিভাবক, আপনার সন্তান $studentName আজ কোচিংয়ে উপস্থিত নেই। - $institute';
  }

  static Future<bool> sendAbsentSms({
    required String guardianPhone,
    required String studentName,
    String? customCoachingName,
  }) async {
    final message = generateAbsentMessage(
      studentName: studentName,
      customCoachingName: customCoachingName,
    );
    return launchSms(phone: guardianPhone, message: message);
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

    return 'সম্মানিত অভিভাবক, $monthYear মাসের জন্য $studentName-এর কোচিং ফি $amountFormatted বকেয়া রয়েছে। অনুগ্রহ করে দ্রুত পরিশোধ করার অনুরোধ করা হলো। - $institute';
  }

  static Future<bool> sendFeeDueSms({
    required String guardianPhone,
    required String studentName,
    required double dueAmount,
    required String monthYear,
    String? customCoachingName,
  }) async {
    final message = generateFeeDueMessage(
      studentName: studentName,
      dueAmount: dueAmount,
      monthYear: monthYear,
      customCoachingName: customCoachingName,
    );
    return launchSms(phone: guardianPhone, message: message);
  }

  // ─────────────────────────────────────────────────────────────
  // 3. CLASS ROUTINE / SCHEDULE UPDATE
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

    final buffer = StringBuffer('বিজ্ঞপ্তি: ');
    if (dayOrDate != null && dayOrDate.isNotEmpty) {
      buffer.write('$dayOrDate-এর ');
    }
    buffer.write('ক্লাস শিডিউল:\n');
    buffer.write('বিষয়: $subject\n');
    buffer.write('সময়: $timeRange\n');
    if (topic != null && topic.trim().isNotEmpty) {
      buffer.write('টপিক/অধ্যায়: $topic\n');
    }
    buffer.write('- $institute');

    return buffer.toString();
  }

  static Future<bool> sendRoutineSms({
    required String recipientPhone,
    required String subject,
    required String timeRange,
    String? topic,
    String? dayOrDate,
    String? customCoachingName,
  }) async {
    final message = generateRoutineMessage(
      subject: subject,
      timeRange: timeRange,
      topic: topic,
      dayOrDate: dayOrDate,
      customCoachingName: customCoachingName,
    );
    return launchSms(phone: recipientPhone, message: message);
  }

  // ─────────────────────────────────────────────────────────────
  // 4. CORE NATIVE LAUNCHER HELPER
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
}
