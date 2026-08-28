import '../../../../app/core/constants/status_constants.dart';

class AuthUserModel {
  final String uid;
  final String email;
  final String nome;
  final UserRole role;
  final String? telefone;
  final String? photoUrl;

  const AuthUserModel({
    required this.uid,
    required this.email,
    required this.nome,
    required this.role,
    this.telefone,
    this.photoUrl,
  });

  AuthUserModel copyWith({
    String? uid,
    String? email,
    String? nome,
    UserRole? role,
    String? telefone,
    String? photoUrl,
  }) {
    return AuthUserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      nome: nome ?? this.nome,
      role: role ?? this.role,
      telefone: telefone ?? this.telefone,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
