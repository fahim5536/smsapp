import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/services/supabase_service.dart';
import '../models/student_model.dart';

/// All Supabase CRUD operations for the `students` table.
class StudentRepository {
  final SupabaseClient _db = SupabaseService.client;

  // ──────────────────────────────────────────────────────────
  // READ — real-time stream of all students
  // ──────────────────────────────────────────────────────────
  Stream<List<StudentModel>> watchStudents() {
    return _db
        .from(SupabaseConfig.studentsTable)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows.map(StudentModel.fromJson).toList());
  }

  // ──────────────────────────────────────────────────────────
  // READ — one-time fetch
  // ──────────────────────────────────────────────────────────
  Future<List<StudentModel>> fetchStudents() async {
    final data = await _db
        .from(SupabaseConfig.studentsTable)
        .select()
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(data)
        .map(StudentModel.fromJson)
        .toList();
  }

  // ──────────────────────────────────────────────────────────
  // READ — fetch single student by id
  // ──────────────────────────────────────────────────────────
  Future<StudentModel?> fetchStudentById(String id) async {
    final data = await _db
        .from(SupabaseConfig.studentsTable)
        .select()
        .eq('id', id)
        .maybeSingle();

    return data == null ? null : StudentModel.fromJson(data);
  }

  // ──────────────────────────────────────────────────────────
  // CREATE — insert a new student
  // ──────────────────────────────────────────────────────────
  Future<StudentModel> addStudent(StudentModel student) async {
    final data = await _db
        .from(SupabaseConfig.studentsTable)
        .insert(student.toJson())
        .select()
        .single();

    return StudentModel.fromJson(data);
  }

  // ──────────────────────────────────────────────────────────
  // UPDATE — update an existing student
  // ──────────────────────────────────────────────────────────
  Future<StudentModel> updateStudent(StudentModel student) async {
    final data = await _db
        .from(SupabaseConfig.studentsTable)
        .update(student.toJson())
        .eq('id', student.id)
        .select()
        .single();

    return StudentModel.fromJson(data);
  }

  // ──────────────────────────────────────────────────────────
  // DELETE — removes a student record
  // (Cascades to delete attendance and fees in PostgreSQL)
  // ──────────────────────────────────────────────────────────
  Future<void> deleteStudent(String id) async {
    await _db
        .from(SupabaseConfig.studentsTable)
        .delete()
        .eq('id', id);
  }
}
