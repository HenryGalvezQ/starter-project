import 'package:firebase_auth/firebase_auth.dart';
import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import '../../domain/entities/user.dart';
import '../../domain/repository/auth_repository.dart';
import '../models/user_model.dart';
import 'package:dio/dio.dart'; // Solo para usar DioException si fuera necesario mantener consistencia con DataState

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;

  AuthRepositoryImpl(this._firebaseAuth);

  @override
  Stream<UserEntity?> getAuthState() {
    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) {
        return null;
      }
      return UserModel.fromFirebase(firebaseUser);
    });
  }

  @override
  Future<DataState<UserEntity>> login(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return DataSuccess(UserModel.fromFirebase(credential.user!));
    } on FirebaseAuthException catch (e) {
      // Convertimos error de Firebase a DioException o un error genérico compatible
      // Para este ejemplo, simplifico retornando DataFailed con un error custom envuelto
      return DataFailed(DioException(
        requestOptions: RequestOptions(path: 'login'),
        error: e.message,
        type: DioExceptionType.badResponse
      ));
    }
  }

  @override
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<DataState<UserEntity>> register(String email, String password) async {
      // Implementación similar a login...
       try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return DataSuccess(UserModel.fromFirebase(credential.user!));
    } on FirebaseAuthException catch (e) {
       return DataFailed(DioException(
        requestOptions: RequestOptions(path: 'register'),
        error: e.message,
        type: DioExceptionType.badResponse
      ));
    }
  }
}