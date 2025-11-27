import 'package:news_app_clean_architecture/core/usecase/usecase.dart';
import '../entities/user.dart';
import '../repository/auth_repository.dart';

// Este UseCase no retorna Future, sino Stream, es un caso especial
class GetAuthStateUseCase {
  final AuthRepository _authRepository;

  GetAuthStateUseCase(this._authRepository);

  Stream<UserEntity?> call() {
    return _authRepository.getAuthState();
  }
}