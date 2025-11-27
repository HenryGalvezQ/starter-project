import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  // Escucha cambios en tiempo real (Logueado <-> Guest)
  Stream<UserEntity?> getAuthState();

  // Acciones puntuales
  Future<DataState<UserEntity>> login(String email, String password);
  Future<void> logout();
  Future<DataState<UserEntity>> register(String email, String password);
}