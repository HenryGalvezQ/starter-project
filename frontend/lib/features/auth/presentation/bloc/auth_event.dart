abstract class AuthEvent {
  const AuthEvent();
}

class AuthCheckRequested extends AuthEvent {}

class AuthLogin extends AuthEvent {
  final String email;
  final String password;
  const AuthLogin(this.email, this.password);
}

// NUEVO EVENTO
class AuthRegister extends AuthEvent {
  final String email;
  final String password;
  final String username;

  const AuthRegister({
    required this.email,
    required this.password,
    required this.username,
  });
}

class AuthLogout extends AuthEvent {}