abstract class AuthEvent {
  const AuthEvent();
}

class AuthCheckRequested extends AuthEvent {}

class AuthLogin extends AuthEvent {
  final String email;
  final String password;
  const AuthLogin(this.email, this.password);
}

class AuthLogout extends AuthEvent {}