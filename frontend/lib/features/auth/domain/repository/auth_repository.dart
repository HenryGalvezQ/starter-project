import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  // Escucha cambios en tiempo real
  Stream<UserEntity?> getAuthState();

  // Acciones
  Future<DataState<UserEntity>> login(String email, String password);
  Future<void> logout();
  
  // CAMBIO: Agregamos 'username' porque el Schema lo exige
  Future<DataState<UserEntity>> register(String email, String password, String username);
}