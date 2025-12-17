import '../../core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user.dart';
import '../../domain/usecases/sign_up_use_case.dart';
import '../../domain/usecases/login_use_case.dart';
import '../../core/params/login_params.dart';
import '../../infrastructure/datasources/auth_remote_datasource.dart';
import '../../infrastructure/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/errors/auth_exception.dart';
import '../../domain/usecases/get_user_details_use_case.dart';


// Provider for the current user
final userProvider = StateProvider<User?>((ref) => null);

// Providers for dependencies
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  dio.options.baseUrl = 'http://localhost:5000/api'; // Corrected back to include /api
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      const secureStorage = FlutterSecureStorage();
      final token = await secureStorage.read(key: 'jwt_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (DioException e, handler) async {
      // Re-throw AuthException for the UI to handle, breaking circular dependency
      if (e.response?.statusCode == 401) {
        throw AuthException(e.response?.data['message'] ?? 'Unauthorized');
      }
      return handler.next(e);
    }
  ));
  return dio;
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  // Pass dio.options.baseUrl as the baseUrl to AuthRemoteDataSource as it now contains /api
  return AuthRemoteDataSource(dio, dio.options.baseUrl, ref);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.watch(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(remoteDataSource);
});

final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  const secureStorage = FlutterSecureStorage();
  return SignUpUseCase(repository, secureStorage);
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return LoginUseCase(authRepository);
});

final getUserDetailsUseCaseProvider = Provider<GetUserDetailsUseCase>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return GetUserDetailsUseCase(authRepository);
});

// Provider for authentication state
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  final signUpUseCase = ref.watch(signUpUseCaseProvider);
  final loginUseCase = ref.watch(loginUseCaseProvider);
  final getUserDetailsUseCase = ref.watch(getUserDetailsUseCaseProvider);
  
  // Immediately call init method when the notifier is created
  final notifier = AuthNotifier(signUpUseCase, loginUseCase, getUserDetailsUseCase, ref);
  notifier.init(); // Initialize the auth state
  return notifier;
});

// Provider for SharedPreferences instance (needs to be implemented elsewhere if not already)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(); // This should be overridden in main.dart
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final SignUpUseCase _signUpUseCase;
  final LoginUseCase _loginUseCase;
  final GetUserDetailsUseCase _getUserDetailsUseCase;
  final Ref _ref;

  AuthNotifier(
    this._signUpUseCase,
    this._loginUseCase,
    this._getUserDetailsUseCase,
    this._ref,
  ) : super(const AsyncValue.data(null));

  Future<void> init() async {
    state = const AsyncValue.loading();
    try {
      const secureStorage = FlutterSecureStorage();
      final storedToken = await secureStorage.read(key: 'jwt_token');
      final sharedPreferences = _ref.read(sharedPreferencesProvider);
      final storedUserId = sharedPreferences.getString('user_id');

      if (storedToken != null && storedUserId != null) {
        // Attempt to fetch user details if a token and userId exist
        final user = await _getUserDetailsUseCase.call(storedUserId);
        if (user != null) {
          _ref.read(userProvider.notifier).state = user;
          state = AsyncValue.data(user);
        } else {
          // Token or user details invalid, clear session
          await logout();
          state = const AsyncValue.data(null);
        }
      } else {
        state = const AsyncValue.data(null); // No previous session
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      // Log out in case of an error during initialization
      await logout();
    }
  }

  Future<void> signUp({
    required String username,
    required String email,
    required String password,
    required DateTime dateOfBirth,
    required String bloodType,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final user = await _signUpUseCase.execute(
        username: username,
        email: email,
        password: password,
        dateOfBirth: dateOfBirth,
        bloodType: bloodType,
      );
      
      _ref.read(userProvider.notifier).state = user;
      state = AsyncValue.data(user);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _loginUseCase.call(LoginParams(email: email, password: password));
      _ref.read(userProvider.notifier).state = user; // Update the userProvider with the logged-in user
      state = AsyncValue.data(user);
    } catch (error, stackTrace) {
      print('AuthNotifier.login error: $error'); // DEBUG PRINT
      if (error is AppException) {
        state = AsyncValue.error(error, stackTrace);
      } else {
        state = AsyncValue.error(AppException('User not found or incorrect credentials.'), stackTrace);
      }
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      const secureStorage = FlutterSecureStorage();
      await secureStorage.delete(key: 'jwt_token');
      final sharedPreferences = _ref.read(sharedPreferencesProvider); // Use ref to read sharedPreferencesProvider
      await sharedPreferences.remove('user_id');
      await sharedPreferences.remove('username');
      _ref.read(userProvider.notifier).state = null;
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
} 