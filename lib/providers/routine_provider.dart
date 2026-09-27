import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/sms_service.dart';
import '../models/class_routine_model.dart';
import '../repositories/routine_repository.dart';
import 'attendance_provider.dart';

final routineRepositoryProvider =
    Provider<RoutineRepository>((_) => RoutineRepository());

// ── Stream of all routines ──────────────────────────────────────
final routinesStreamProvider = StreamProvider<List<ClassRoutineModel>>((ref) {
  final repo = ref.watch(routineRepositoryProvider);
  return repo.watchRoutines();
});

// ── Selected Day Filter (0 = All, 1 = Mon ... 7 = Sun) ──────────
class DayFilterNotifier extends Notifier<int> {
  @override
  int build() {
    // Default to today's day of week (DateTime.monday is 1, sunday is 7)
    return DateTime.now().weekday;
  }

  void setDay(int day) => state = day;
}

final routineDayFilterProvider =
    NotifierProvider<DayFilterNotifier, int>(DayFilterNotifier.new);

// ── Filtered Routines Provider ──────────────────────────────────
final filteredRoutinesProvider =
    Provider<AsyncValue<List<ClassRoutineModel>>>((ref) {
  final routinesAsync = ref.watch(routinesStreamProvider);
  final dayFilter = ref.watch(routineDayFilterProvider);

  return routinesAsync.whenData((routines) {
    if (dayFilter == 0) return routines;
    return routines.where((r) => r.dayOfWeek == dayFilter).toList();
  });
});

// ── Routine Mutation Notifier ───────────────────────────────────
class RoutineMutationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  RoutineRepository get _repo => ref.read(routineRepositoryProvider);

  Future<bool> addRoutine(ClassRoutineModel routine) async {
    state = const AsyncLoading();
    try {
      await _repo.addRoutine(routine);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> updateRoutine(ClassRoutineModel routine) async {
    state = const AsyncLoading();
    try {
      await _repo.updateRoutine(routine);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> deleteRoutine(String id) async {
    state = const AsyncLoading();
    try {
      await _repo.deleteRoutine(id);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// Sends a schedule update SMS to a guardian or student
  Future<bool> sendRoutineSms({
    required ClassRoutineModel routine,
    required String recipientPhone,
    String? dayOrDate,
  }) async {
    final coaching = ref.read(coachingNameProvider);
    return await SmsService.sendRoutineSms(
      recipientPhone: recipientPhone,
      subject: routine.subject,
      timeRange: routine.timeRange,
      topic: routine.topic,
      dayOrDate: dayOrDate ?? routine.dayNameBn,
      customCoachingName: coaching,
    );
  }
}

final routineMutationProvider =
    NotifierProvider<RoutineMutationNotifier, AsyncValue<void>>(
  RoutineMutationNotifier.new,
);
