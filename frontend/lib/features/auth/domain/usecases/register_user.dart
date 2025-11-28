import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import 'package:news_app_clean_architecture/core/usecase/usecase.dart';
import '../entities/user.dart';
import '../repository/auth_repository.dart';

class RegisterUserUseCase implements UseCase<DataState<UserEntity>, RegisterParams> {
  final AuthRepository _authRepository;

  RegisterUserUseCase(this._authRepository);

  @override
  Future<DataState<UserEntity>> call({RegisterParams? params}) {
    return _authRepository.register(
      params!.email, 
      params.password, 
      params.username
    );
  }
}

class RegisterParams {
  final String email;
  final String password;
  final String username;

  RegisterParams({
    required this.email, 
    required this.password, 
    required this.username
  });
}