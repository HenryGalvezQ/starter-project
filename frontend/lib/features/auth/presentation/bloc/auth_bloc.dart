import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import '../../domain/usecases/get_auth_state.dart';
import '../../domain/usecases/login_user.dart';
import '../../domain/usecases/logout_user.dart';
import '../../domain/usecases/register_user.dart'; // IMPORTAR
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final GetAuthStateUseCase _getAuthStateUseCase;
  final LoginUserUseCase _loginUserUseCase;
  final LogoutUserUseCase _logoutUserUseCase;
  final RegisterUserUseCase _registerUserUseCase; // NUEVA DEPENDENCIA

  AuthBloc(
    this._getAuthStateUseCase,
    this._loginUserUseCase,
    this._logoutUserUseCase,
    this._registerUserUseCase, // NUEVO PARÁMETRO
  ) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLogin>(_onAuthLogin);
    on<AuthLogout>(_onAuthLogout);
    on<AuthRegister>(_onAuthRegister); // REGISTRAR HANDLER
  }

  void _onAuthCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    await emit.forEach(
      _getAuthStateUseCase(),
      onData: (user) {
        if (user != null) {
          return Authenticated(user);
        } else {
          return Unauthenticated();
        }
      },
    );
  }

  void _onAuthLogin(AuthLogin event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await _loginUserUseCase(params: LoginParams(email: event.email, password: event.password));
    
    if (result is DataFailed) {
      emit(AuthError(result.error?.error.toString() ?? "Error desconocido al entrar"));
      emit(Unauthenticated());
    }
  }

  // NUEVA LÓGICA DE REGISTRO
  void _onAuthRegister(AuthRegister event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    final result = await _registerUserUseCase(params: RegisterParams(
      email: event.email, 
      password: event.password, 
      username: event.username
    ));

    if (result is DataFailed) {
      emit(AuthError(result.error?.error.toString() ?? "Error desconocido al registrar"));
      emit(Unauthenticated());
    }
    // Si es DataSuccess, no hacemos nada manual.
    // Firebase Auth avisará automáticamente al stream (_onAuthCheckRequested) 
    // y emitirá 'Authenticated'.
  }

  void _onAuthLogout(AuthLogout event, Emitter<AuthState> emit) async {
    await _logoutUserUseCase();
  }
}