import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/auth_exception.dart';
import '../../core/params/login_params.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../infrastructure/repositories/auth_repository_impl.dart';
import '../entities/user.dart';

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final authRepository = ref.read(authRepositoryProvider);
  return LoginUseCase(authRepository);
});

class LoginUseCase {
  final AuthRepository _authRepository;

  LoginUseCase(this._authRepository);

  Future<User> call(LoginParams params) async {
    try {
      return await _authRepository.login(params);
    } on AuthException catch (e) {
      throw AppException(e.message);
    } catch (e) {
      throw AppException('An unexpected error occurred.');
    }
  }
} 