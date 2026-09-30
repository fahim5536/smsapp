import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/student_model.dart';
import '../repositories/student_repository.dart';

// ── Repository provider ────────────────────────────────────────
final studentRepositoryProvider = Provider<StudentRepository>(
  (_) => StudentRepository(),
);

// ── Real-time stream provider ──────────────────────────────────
/// Emits a new list of students on every Supabase INSERT/UPDATE/DELETE.
final studentsStreamProvider = StreamProvider<List<StudentModel>>((ref) {
  final repo = ref.watch(studentRepositoryProvider);
  return repo.watchStudents();
});

// ── Debounced search query ──────────────────────────────────────
/// Debounced search notifier — waits 300ms after the last keystroke
/// before emitting, so the list does not rebuild on every character.
class DebouncedSearchNotifier extends Notifier<String> {
  Timer? _timer;

  @override
  String build() {
    ref.onDispose(() => _timer?.cancel());
    return '';
  }

  void update(String query, {Duration delay = const Duration(milliseconds: 300)}) {
    _timer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      // Clearing the box should filter immediately, not after the delay.
      _timer = null;
      state = '';
      return;
    }
    _timer = Timer(delay, () => state = trimmed);
  }

  void clear() {
    _timer?.cancel();
    state = '';
  }
}

final studentSearchQueryProvider =
    NotifierProvider<DebouncedSearchNotifier, String>(DebouncedSearchNotifier.new);

// Filtered students derived from the stream + debounced search query.
final filteredStudentsProvider = Provider<AsyncValue<List<StudentModel>>>((ref) {
  final studentsAsync = ref.watch(studentsStreamProvider);
  final query = ref.watch(studentSearchQueryProvider).toLowerCase();

  return studentsAsync.whenData((students) {
    if (query.isEmpty) return students;
    return students.where((s) {
      return s.fullName.toLowerCase().contains(query) ||
          s.grade.toLowerCase().contains(query) ||
          s.subject.toLowerCase().contains(query) ||
          s.parentPhone.contains(query);
    }).toList();
  });
});

// ── Mutation state ─────────────────────────────────────────────
class StudentMutationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  StudentRepository get _repo => ref.read(studentRepositoryProvider);

  Future<bool> addStudent(StudentModel student) async {
    state = const AsyncLoading();
    try {
      await _repo.addStudent(student);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> updateStudent(StudentModel student) async {
    state = const AsyncLoading();
    try {
      await _repo.updateStudent(student);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> deleteStudent(String id) async {
    state = const AsyncLoading();
    try {
      await _repo.deleteStudent(id);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final studentMutationProvider =
    NotifierProvider<StudentMutationNotifier, AsyncValue<void>>(
      StudentMutationNotifier.new,
    );
