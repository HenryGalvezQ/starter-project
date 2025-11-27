import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import '../../domain/usecases/get_auth_state.dart';
import '../../domain/usecases/login_user.dart';
import '../../domain/usecases/logout_user.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final GetAuthStateUseCase _getAuthStateUseCase;
  final LoginUserUseCase _loginUserUseCase;
  final LogoutUserUseCase _logoutUserUseCase;

  AuthBloc(
    this._getAuthStateUseCase,
    this._loginUserUseCase,
    this._logoutUserUseCase,
  ) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLogin>(_onAuthLogin);
    on<AuthLogout>(_onAuthLogout);
  }

  void _onAuthCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    // Suscribirse al stream.
    // NOTA: En un caso real usaríamos emit.forEach para streams,
    // pero para simplicidad inicial, tomaremos el primer valor o escucharemos.
    // La forma correcta en Bloc para Streams:
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
      emit(AuthError(result.error?.error.toString() ?? "Error desconocido"));
      emit(Unauthenticated()); // Volvemos a estado invitado si falla
    }
    // Si es Success, el Stream de _onAuthCheckRequested se encargará de emitir Authenticated automáticamente
  }

  void _onAuthLogout(AuthLogout event, Emitter<AuthState> emit) async {
    await _logoutUserUseCase();
    // El stream emitirá Unauthenticated
  }
}