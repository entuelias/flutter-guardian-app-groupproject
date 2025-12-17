import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/emergency_note.dart';
import '../../domain/repositories/emergency_repository.dart';
import '../../infrastructure/datasources/emergency_remote_datasource.dart';
import '../../infrastructure/repositories/emergency_repository_impl.dart';
import '../../domain/usecases/get_emergency_notes_usecase.dart';
import '../../domain/usecases/create_emergency_note_usecase.dart';
import '../../domain/usecases/update_emergency_note_usecase.dart';
import '../../domain/usecases/delete_emergency_note_usecase.dart';
import './auth_provider.dart';

final emergencyRemoteDataSourceProvider = Provider<EmergencyRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return EmergencyRemoteDataSource(dio, dio.options.baseUrl);
});

final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) {
  final dataSource = ref.watch(emergencyRemoteDataSourceProvider);
  return EmergencyRepositoryImpl(dataSource);
});

final getEmergencyNotesUseCaseProvider = Provider((ref) {
  final repository = ref.watch(emergencyRepositoryProvider);
  return GetEmergencyNotesUseCase(repository);
});

final createEmergencyNoteUseCaseProvider = Provider((ref) {
  final repository = ref.watch(emergencyRepositoryProvider);
  return CreateEmergencyNoteUseCase(repository);
});

final updateEmergencyNoteUseCaseProvider = Provider((ref) {
  final repository = ref.watch(emergencyRepositoryProvider);
  return UpdateEmergencyNoteUseCase(repository);
});

final deleteEmergencyNoteUseCaseProvider = Provider((ref) {
  final repository = ref.watch(emergencyRepositoryProvider);
  return DeleteEmergencyNoteUseCase(repository);
});

final emergencyNotesProvider = StateNotifierProvider<EmergencyNotifier, AsyncValue<List<EmergencyNote>>>((ref) {
  final getEmergencyNotesUseCase = ref.watch(getEmergencyNotesUseCaseProvider);
  final createEmergencyNoteUseCase = ref.watch(createEmergencyNoteUseCaseProvider);
  final updateEmergencyNoteUseCase = ref.watch(updateEmergencyNoteUseCaseProvider);
  final deleteEmergencyNoteUseCase = ref.watch(deleteEmergencyNoteUseCaseProvider);
  return EmergencyNotifier(
    getEmergencyNotesUseCase,
    createEmergencyNoteUseCase,
    updateEmergencyNoteUseCase,
    deleteEmergencyNoteUseCase,
  );
});

class EmergencyNotifier extends StateNotifier<AsyncValue<List<EmergencyNote>>> {
  final GetEmergencyNotesUseCase _getEmergencyNotesUseCase;
  final CreateEmergencyNoteUseCase _createEmergencyNoteUseCase;
  final UpdateEmergencyNoteUseCase _updateEmergencyNoteUseCase;
  final DeleteEmergencyNoteUseCase _deleteEmergencyNoteUseCase;

  EmergencyNotifier(
    this._getEmergencyNotesUseCase,
    this._createEmergencyNoteUseCase,
    this._updateEmergencyNoteUseCase,
    this._deleteEmergencyNoteUseCase,
  ) : super(const AsyncValue.loading());

  Future<void> loadEmergencyNotes(String userId) async {
    state = const AsyncValue.loading();
    try {
      final notes = await _getEmergencyNotesUseCase(userId);
      state = AsyncValue.data(notes);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> createEmergencyNote(EmergencyNote note) async {
    try {
      final newNote = await _createEmergencyNoteUseCase(note);
      state.whenData((notes) {
        state = AsyncValue.data([...notes, newNote]);
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateEmergencyNote(String noteId, EmergencyNote note) async {
    try {
      final updatedNote = await _updateEmergencyNoteUseCase(noteId, note);
      state.whenData((notes) {
        final updatedNotes = notes.map((n) => n.id == noteId ? updatedNote : n).toList();
        state = AsyncValue.data(updatedNotes);
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteEmergencyNote(String noteId) async {
    try {
      await _deleteEmergencyNoteUseCase(noteId);
      state.whenData((notes) {
        final updatedNotes = notes.where((note) => note.id != noteId).toList();
        state = AsyncValue.data(updatedNotes);
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
} 