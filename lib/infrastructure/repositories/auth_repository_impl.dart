import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/params/login_params.dart';
import '../datasources/auth_remote_datasource.dart';
import '../../presentation/providers/auth_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = Dio();
  const baseUrl = 'http://localhost:5000/api'; // Replace with your backend URL

  // Add Dio interceptor for JWT here, as Dio instance is created here
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      const secureStorage = FlutterSecureStorage();
      final token = await secureStorage.read(key: 'jwt_token');
      if (token != null && token.isNotEmpty) { // Ensure token is not null and not empty
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
  ));

  final remoteDataSource = AuthRemoteDataSource(dio, baseUrl, ref); // Pass ref to remoteDataSource
  return AuthRepositoryImpl(remoteDataSource);
});

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  @override
  Future<Map<String, dynamic>> signUp(User user, String password) async {
    return await remoteDataSource.signUp(user, password);
  }

  @override
  Future<User> login(LoginParams params) async {
    return await remoteDataSource.login(params);
  }

  @override
  Future<void> logout() async {
    await remoteDataSource.logout();
  }

  @override
  Future<User?> getUserDetails(String userId) async {
    return await remoteDataSource.getUserDetails(userId);
  }
} 