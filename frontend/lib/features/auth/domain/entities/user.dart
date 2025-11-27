import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String ? uid;
  final String ? email;
  final String ? displayName;

  const UserEntity({
    this.uid,
    this.email,
    this.displayName,
  });

  @override
  List < Object ? > get props {
    return [uid, email, displayName];
  }
}