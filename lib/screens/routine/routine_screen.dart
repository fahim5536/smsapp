import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/class_routine_model.dart';
import '../../models/student_model.dart';
import '../../providers/routine_provider.dart';
import '../../providers/student_provider.dart';

class RoutineScreen extends ConsumerStatefulWidget {
  const RoutineScreen({super.key});

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  @override
  Widget build(BuildContext context) {
    final filteredRoutinesAsync = ref.watch(filteredRoutinesProvider);
    final selectedDay = ref.watch(routineDayFilterProvider);
    final studentsAsync = ref.watch(studentsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Text(
          '📅 ক্লাস রুটিন (Schedule)',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Day of Week Selector Bar ──────────────────────────
          _buildDaySelector(selectedDay),

          // ── Routines List ─────────────────────────────────────
          Expanded(
            child: filteredRoutinesAsync.when(
              data: (routines) {
                if (routines.isEmpty) {
                  return _buildEmptyView();
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: routines.length,
                  itemBuilder: (context, index) {
                    final routine = routines[index];
                    return _RoutineCard(
                      routine: routine,
                      students: studentsAsync.value ?? [],
                      onEdit: () => _showAddEditRoutineDialog(routine: routine),
                      onDelete: () => _confirmDelete(routine),
                      onSendSms: () => _showSendRoutineSmsDialog(
                        routine: routine,
                        students: studentsAsync.value ?? [],
                      ),
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => _showAddEditRoutineDialog(),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'নতুন শিডিউল',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildDaySelector(int selectedDay) {
    const days = [
      (0, 'সকল দিন'),
      (1, 'সোম'),
      (2, 'মঙ্গল'),
      (3, 'বুধ'),
      (4, 'বৃহস্পতি'),
      (5, 'শুক্র'),
      (6, 'শনি'),
      (7, 'রবি'),
    ];

    final todayWeekday = DateTime.now().weekday;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: days.map((d) {
          final isSelected = selectedDay == d.$1;
          final isToday = d.$1 == todayWeekday;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: isToday
                  ? const Icon(Icons.today, size: 14, color: Colors.amberAccent)
                  : null,
              label: Text(isToday ? '${d.$2} (আজ)' : d.$2),
              selected: isSelected,
              onSelected: (_) =>
                  ref.read(routineDayFilterProvider.notifier).setDay(d.$1),
              selectedColor: AppTheme.primary,
              backgroundColor: AppTheme.cardDark,
              labelStyle: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white70,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy_rounded,
              size: 52, color: Colors.white24),
          const SizedBox(height: 14),
          Text(
            'এই দিনে কোনো ক্লাস নেই',
            style: GoogleFonts.outfit(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            'নিচের বাটনে ট্যাপ করে নতুন ক্লাস যোগ করুন।',
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  void _showAddEditRoutineDialog({ClassRoutineModel? routine}) {
    final isEdit = routine != null;
    final subjectCtrl = TextEditingController(text: routine?.subject);
    final topicCtrl = TextEditingController(text: routine?.topic);
    final startCtrl = TextEditingController(text: routine?.startTime ?? '10:00 AM');
    final endCtrl = TextEditingController(text: routine?.endTime ?? '11:30 AM');
    final locationCtrl = TextEditingController(text: routine?.location ?? 'ব্যাচ এ');
    int dayOfWeek = routine?.dayOfWeek ?? DateTime.now().weekday;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                    isEdit ? 'শিডিউল সম্পাদনা' : 'নতুন ক্লাস শিডিউল',
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
              const SizedBox(height: 12),
              // Day of week dropdown
              DropdownButtonFormField<int>(
                initialValue: dayOfWeek,
                dropdownColor: AppTheme.cardDark,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'সপ্তাহের দিন',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
                items: List.generate(7, (i) {
                  final dayIndex = i + 1;
                  return DropdownMenuItem(
                    value: dayIndex,
                    child: Text(ClassRoutineModel.dayNamesBn[i]),
                  );
                }),
                onChanged: (val) {
                  if (val != null) setModalState(() => dayOfWeek = val);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: subjectCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'বিষয় (Subject) *',
                  hintText: 'যেমন: পদার্থবিজ্ঞান বা গণিত',
                  prefixIcon: Icon(Icons.menu_book_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: topicCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'টপিক বা অধ্যায় (Topic / Chapter)',
                  hintText: 'যেমন: বলবিদ্যা - গতিসূত্র',
                  prefixIcon: Icon(Icons.topic_outlined),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'শুরু',
                        hintText: '10:00 AM',
                        prefixIcon: Icon(Icons.access_time_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'শেষ',
                        hintText: '11:30 AM',
                        prefixIcon: Icon(Icons.access_time_filled_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: locationCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'ব্যাচ / রুম (Batch / Room)',
                  hintText: 'যেমন: রুম ১০১ অথবা সকালের ব্যাচ',
                  prefixIcon: Icon(Icons.room_rounded),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (subjectCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);

                  final newRoutine = ClassRoutineModel(
                    id: routine?.id ?? '',
                    teacherId: SupabaseService.currentUserId,
                    subject: subjectCtrl.text.trim(),
                    topic: topicCtrl.text.trim().isEmpty ? null : topicCtrl.text.trim(),
                    dayOfWeek: dayOfWeek,
                    startTime: startCtrl.text.trim(),
                    endTime: endCtrl.text.trim(),
                    location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                    createdAt: routine?.createdAt ?? DateTime.now(),
                  );

                  final notifier = ref.read(routineMutationProvider.notifier);
                  final success = isEdit
                      ? await notifier.updateRoutine(newRoutine)
                      : await notifier.addRoutine(newRoutine);

                  if (mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.success,
                        content: Text(
                          isEdit ? '✓ শিডিউল আপডেট করা হয়েছে' : '✓ নতুন শিডিউল যোগ হয়েছে',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                      ),
                    );
                  }
                },
                child: Text(isEdit ? 'আপডেট করুন' : 'যোগ করুন'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSendRoutineSmsDialog({
    required ClassRoutineModel routine,
    required List<StudentModel> students,
  }) {
    final customPhoneCtrl = TextEditingController();
    StudentModel? selectedStudent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                    'রুটিন আপডেট SMS পাঠান',
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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${routine.dayNameBn}: ${routine.subject} (${routine.timeRange})',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (routine.topic != null && routine.topic!.isNotEmpty)
                      Text(
                        'টপিক: ${routine.topic}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppTheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'শিক্ষার্থী নির্বাচন করুন (অভিভাবকের ফোন স্বয়ংক্রিয়ভাবে বসবে):',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<StudentModel>(
                initialValue: selectedStudent,
                dropdownColor: AppTheme.cardDark,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'শিক্ষার্থী বেছে নিন...',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: students.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text('${s.fullName} (${s.parentPhone})'),
                  );
                }).toList(),
                onChanged: (val) {
                  setModalState(() {
                    selectedStudent = val;
                    if (val != null) {
                      customPhoneCtrl.text = val.parentPhone;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              Text(
                'অথবা সরাসরি ফোন নম্বর লিখুন:',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: customPhoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'ফোন নম্বর (Phone Number)',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: () async {
                  final phone = customPhoneCtrl.text.trim();
                  if (phone.isEmpty) return;
                  Navigator.pop(ctx);

                  final launched = await ref
                      .read(routineMutationProvider.notifier)
                      .sendRoutineSms(
                        routine: routine,
                        recipientPhone: phone,
                      );

                  if (mounted && launched) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.success,
                        content: Text(
                          '✓ রুটিন SMS অ্যাপে লোড হয়েছে ($phone)',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.sms_rounded),
                label: const Text('রুটিন SMS পাঠান'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ClassRoutineModel routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'শিডিউল মুছে ফেলবেন?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'আপনি কি "${routine.subject} (${routine.dayNameBn})" শিডিউলটি মুছে ফেলতে চান?',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('বাতিল', style: GoogleFonts.outfit(color: Colors.white54)),
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

    if (confirmed == true && mounted) {
      await ref.read(routineMutationProvider.notifier).deleteRoutine(routine.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text(
              '✓ শিডিউল মুছে ফেলা হয়েছে',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
      }
    }
  }
}

// ── Routine Card Widget ─────────────────────────────────────────
class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.students,
    required this.onEdit,
    required this.onDelete,
    required this.onSendSms,
  });

  final ClassRoutineModel routine;
  final List<StudentModel> students;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSendSms;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  routine.dayNameBn,
                  style: GoogleFonts.outfit(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  routine.subject,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white60),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Colors.amberAccent),
              const SizedBox(width: 6),
              Text(
                routine.timeRange,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (routine.location != null && routine.location!.isNotEmpty) ...[
                const SizedBox(width: 12),
                const Icon(Icons.room_rounded, size: 14, color: Colors.white38),
                const SizedBox(width: 4),
                Text(
                  routine.location!,
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.white60),
                ),
              ],
            ],
          ),
          if (routine.topic != null && routine.topic!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.topic_outlined, size: 14, color: AppTheme.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'টপিক: ${routine.topic}',
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: onSendSms,
                icon: const Icon(Icons.sms_rounded, size: 15, color: AppTheme.primary),
                label: Text(
                  'রুটিন SMS দিন',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
