import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import 'package:news_app_clean_architecture/core/usecase/usecase.dart';
import '../entities/user.dart';
import '../repository/auth_repository.dart';

class LoginUserUseCase implements UseCase<DataState<UserEntity>, LoginParams> {
  final AuthRepository _authRepository;

  LoginUserUseCase(this._authRepository);

  @override
  Future<DataState<UserEntity>> call({LoginParams? params}) {
    return _authRepository.login(params!.email, params.password);
  }
}

class LoginParams {
  final String email;
  final String password;
  LoginParams({required this.email, required this.password});
}