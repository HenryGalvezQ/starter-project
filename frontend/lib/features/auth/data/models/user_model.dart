import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user.dart';

class UserModel extends UserEntity {
  const UserModel({
    String? uid,
    String? email,
    String? displayName,
  }) : super(uid: uid, email: email, displayName: displayName);

  factory UserModel.fromFirebase(User firebaseUser) {
    return UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
    );
  }
}