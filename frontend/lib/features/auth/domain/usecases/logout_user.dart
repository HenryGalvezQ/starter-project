import 'package:news_app_clean_architecture/core/usecase/usecase.dart';
import '../repository/auth_repository.dart';

class LogoutUserUseCase implements UseCase<void, void> {
  final AuthRepository _authRepository;

  LogoutUserUseCase(this._authRepository);

  @override
  Future<void> call({void params}) {
    return _authRepository.logout();
  }
}