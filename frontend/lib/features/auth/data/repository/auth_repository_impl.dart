import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import '../../domain/entities/user.dart';
import '../../domain/repository/auth_repository.dart';
import '../models/user_model.dart';
import 'package:dio/dio.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl(this._firebaseAuth, this._firestore);

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
  Future<DataState<UserEntity>> register(String email, String password, String username) async {
    try {
      User? user;
      
      try {
        // INTENTO PRINCIPAL
        final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        user = credential.user;
      } catch (e) {
        // TRUCO PARA EL BUG DE PIGEON:
        // Si falla con el error de tipo, PERO el usuario actual ya no es nulo,
        // significa que Firebase sí lo creó y logueó, solo falló el retorno.
        if (_firebaseAuth.currentUser != null) {
          print("⚠️ Alerta: Auth lanzó error pero el usuario SÍ se creó (Bug de librería ignorado).");
          user = _firebaseAuth.currentUser;
        } else {
          // Si el usuario es nulo, entonces el error fue real (ej: email en uso).
          rethrow; // Relanzamos el error para que lo capture el catch de abajo
        }
      }

      // SI LLEGAMOS AQUÍ CON UN USUARIO, GUARDAMOS EN FIRESTORE
      if (user != null) {
        print("✅ AUTH CONFIRMADO: UID ${user.uid}");

        try {
          // Usamos set con merge para evitar sobrescribir si por milagro ya existiera
          await _firestore.collection('users').doc(user.uid).set({
            'email': email,
            'displayName': username,
            'photoURL': '',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
          print("✅ FIRESTORE: Documento guardado.");
        } catch (e) {
          print("🔥 ERROR FIRESTORE: $e");
          // No detenemos el flujo, permitimos que el usuario entre aunque falle la BD
        }

        return DataSuccess(UserModel(
            uid: user.uid,
            email: email,
            displayName: username
        ));
      }
      
      return DataFailed(DioException(
          requestOptions: RequestOptions(path: 'register'),
          error: "No se pudo obtener el usuario creado",
          type: DioExceptionType.badResponse
      ));

    } on FirebaseAuthException catch (e) {
      // Errores normales de Firebase (Email en uso, contraseña débil, etc)
      return DataFailed(DioException(
        requestOptions: RequestOptions(path: 'register'),
        error: e.message ?? "Error de Firebase Auth",
        type: DioExceptionType.badResponse
      ));
    } catch (e) {
      // Errores de Pigeon o Crash desconocidos que no pudimos mitigar arriba
      print("💥 Error no controlado: $e");
      
      // ÚLTIMO RECURSO: Verificamos una última vez si estamos logueados
      if (_firebaseAuth.currentUser != null) {
         return DataSuccess(UserModel.fromFirebase(_firebaseAuth.currentUser!));
      }

      return DataFailed(DioException(
        requestOptions: RequestOptions(path: 'register'),
        error: e.toString(),
        type: DioExceptionType.unknown
      ));
    }
  }
}