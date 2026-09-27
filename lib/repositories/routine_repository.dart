import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/services/supabase_service.dart';
import '../models/class_routine_model.dart';

/// Handles class routine / schedule storage in Supabase
class RoutineRepository {
  final SupabaseClient _db = SupabaseService.client;

  /// Real-time stream of all routines
  Stream<List<ClassRoutineModel>> watchRoutines() {
    return _db
        .from(SupabaseConfig.routinesTable)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((rows) => rows.map(ClassRoutineModel.fromJson).toList());
  }

  /// Fetches all routines
  Future<List<ClassRoutineModel>> fetchRoutines() async {
    final data = await _db
        .from(SupabaseConfig.routinesTable)
        .select()
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(data)
        .map(ClassRoutineModel.fromJson)
        .toList();
  }

  /// Creates a new routine entry
  Future<ClassRoutineModel> addRoutine(ClassRoutineModel routine) async {
    final data = await _db
        .from(SupabaseConfig.routinesTable)
        .insert(routine.toJson())
        .select()
        .single();

    return ClassRoutineModel.fromJson(data);
  }

  /// Updates an existing routine entry
  Future<ClassRoutineModel> updateRoutine(ClassRoutineModel routine) async {
    final data = await _db
        .from(SupabaseConfig.routinesTable)
        .update(routine.toJson())
        .eq('id', routine.id)
        .select()
        .single();

    return ClassRoutineModel.fromJson(data);
  }

  /// Deletes a routine entry
  Future<void> deleteRoutine(String id) async {
    await _db
        .from(SupabaseConfig.routinesTable)
        .delete()
        .eq('id', id);
  }
}
