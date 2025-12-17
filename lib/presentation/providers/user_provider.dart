import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/get_user_profile_use_case.dart';
import '../../infrastructure/datasources/user_remote_datasource.dart';
import '../../infrastructure/repositories/user_repository_impl.dart';

final userProvider = StateNotifierProvider<UserNotifier, AsyncValue<User?>>((ref) {
  final dio = Dio();
  const baseUrl = 'http://localhost:5000/api';
  final remoteDataSource = UserRemoteDataSource(dio, baseUrl);
  final repository = UserRepositoryImpl(remoteDataSource);
  const secureStorage = FlutterSecureStorage();
  final getUserProfileUseCase = GetUserProfileUseCase(repository, secureStorage);
  
  return UserNotifier(getUserProfileUseCase);
});

class UserNotifier extends StateNotifier<AsyncValue<User?>> {
  final GetUserProfileUseCase _getUserProfileUseCase;

  UserNotifier(this._getUserProfileUseCase) : super(const AsyncValue.loading()) {
    loadUserProfile();
  }

  Future<void> loadUserProfile() async {
    try {
      final user = await _getUserProfileUseCase.execute();
      state = AsyncValue.data(user);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
} 