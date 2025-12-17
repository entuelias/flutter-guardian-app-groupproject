import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/medical_note.dart';
import '../../domain/repositories/medical_repository.dart';
import '../../infrastructure/datasources/medical_remote_datasource.dart';
import '../../infrastructure/repositories/medical_repository_impl.dart';
import '../../domain/usecases/get_medical_notes_usecase.dart';
import '../../domain/usecases/create_medical_note_usecase.dart';
import '../../domain/usecases/update_medical_note_usecase.dart';
import '../../domain/usecases/delete_medical_note_usecase.dart';
import './auth_provider.dart'; // Import auth_provider to get dioProvider

final medicalRemoteDataSourceProvider = Provider<MedicalRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider); // Use the shared dioProvider
  return MedicalRemoteDataSource(dio, dio.options.baseUrl);
});

final medicalRepositoryProvider = Provider<MedicalRepository>((ref) {
  final dataSource = ref.watch(medicalRemoteDataSourceProvider);
  return MedicalRepositoryImpl(dataSource);
});

final getMedicalNotesUseCaseProvider = Provider((ref) {
  final repository = ref.watch(medicalRepositoryProvider);
  return GetMedicalNotesUseCase(repository);
});

final createMedicalNoteUseCaseProvider = Provider((ref) {
  final repository = ref.watch(medicalRepositoryProvider);
  return CreateMedicalNoteUseCase(repository);
});

final updateMedicalNoteUseCaseProvider = Provider((ref) {
  final repository = ref.watch(medicalRepositoryProvider);
  return UpdateMedicalNoteUseCase(repository);
});

final deleteMedicalNoteUseCaseProvider = Provider((ref) {
  final repository = ref.watch(medicalRepositoryProvider);
  return DeleteMedicalNoteUseCase(repository);
});

final medicalNotesProvider = StateNotifierProvider<MedicalNotifier, AsyncValue<List<MedicalNote>>>((ref) {
  final getMedicalNotesUseCase = ref.watch(getMedicalNotesUseCaseProvider);
  final createMedicalNoteUseCase = ref.watch(createMedicalNoteUseCaseProvider);
  final updateMedicalNoteUseCase = ref.watch(updateMedicalNoteUseCaseProvider);
  final deleteMedicalNoteUseCase = ref.watch(deleteMedicalNoteUseCaseProvider);
  return MedicalNotifier(
    getMedicalNotesUseCase,
    createMedicalNoteUseCase,
    updateMedicalNoteUseCase,
    deleteMedicalNoteUseCase,
  );
});

class MedicalNotifier extends StateNotifier<AsyncValue<List<MedicalNote>>> {
  final GetMedicalNotesUseCase _getMedicalNotesUseCase;
  final CreateMedicalNoteUseCase _createMedicalNoteUseCase;
  final UpdateMedicalNoteUseCase _updateMedicalNoteUseCase;
  final DeleteMedicalNoteUseCase _deleteMedicalNoteUseCase;

  MedicalNotifier(
    this._getMedicalNotesUseCase,
    this._createMedicalNoteUseCase,
    this._updateMedicalNoteUseCase,
    this._deleteMedicalNoteUseCase,
  ) : super(const AsyncValue.loading());

  Future<void> loadMedicalNotes(String userId) async {
    state = const AsyncValue.loading();
    try {
      final notes = await _getMedicalNotesUseCase(userId);
      state = AsyncValue.data(notes);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> createMedicalNote(MedicalNote note) async {
    try {
      final newNote = await _createMedicalNoteUseCase(note);
      state.whenData((notes) {
        state = AsyncValue.data([...notes, newNote]);
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateMedicalNote(String noteId, MedicalNote note) async {
    try {
      final updatedNote = await _updateMedicalNoteUseCase(noteId, note);
      state.whenData((notes) {
        final updatedNotes = notes.map((n) => n.id == noteId ? updatedNote : n).toList();
        state = AsyncValue.data(updatedNotes);
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteMedicalNote(String noteId) async {
    try {
      await _deleteMedicalNoteUseCase(noteId);
      state.whenData((notes) {
        final updatedNotes = notes.where((note) => note.id != noteId).toList();
        state = AsyncValue.data(updatedNotes);
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
} 