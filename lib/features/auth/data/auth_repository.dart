import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/core/services/api_service.dart';
import '../../../app/core/constants/api_constants.dart';
import '../../../app/core/constants/status_constants.dart';
import '../domain/models/auth_user.dart';

/// Repositório de autenticação — Firebase Auth + registro na API PHP.
/// Se Firebase não estiver disponível, usa mock como fallback.
class AuthRepository {
  final FirebaseAuth? _firebaseAuth;
  final ApiService _apiService;

  AuthRepository({
    required ApiService apiService,
  })  : _firebaseAuth = _initFirebaseAuth(),
        _apiService = apiService;

  static FirebaseAuth? _initFirebaseAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      debugPrint('[AuthRepository] FirebaseAuth unavailable: $e');
      return null;
    }
  }

  bool get _isFirebaseAvailable => _firebaseAuth != null;

  /// Grava documento do usuário no Firestore (igual ao Van_Pro).
  Future<void> _writeUserToFirestore({
    required String uid,
    required String nome,
    required String email,
    required String role,
    required String telefone,
    String? vanCode,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      final data = <String, dynamic>{
        'uid': uid,
        'role': role,
        'email': email,
        'nome': nome,
        'telefone': telefone,
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': false,
      };
      if (vanCode != null) {
        data['vanCode'] = vanCode;
      }
      await db.collection('users').doc(uid).set(data);
      debugPrint('[AuthRepository] Firestore user document written for $uid');
    } catch (e) {
      debugPrint('[AuthRepository] _writeUserToFirestore error: $e');
    }
  }

  /// Lê role do usuário no Firestore com timeout.
  Future<String?> _getRoleFromFirestore(String uid) async {
    try {
      final db = FirebaseFirestore.instance;
      final doc = await db.collection('users').doc(uid).get().timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw Exception('Firestore timeout'),
      );
      if (doc.exists) {
        final data = doc.data();
        debugPrint('[AuthRepository] Firestore role read: ${data?['role']}');
        return data?['role'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[AuthRepository] _getRoleFromFirestore error: $e');
      return null;
    }
  }

  /// Atualiza emailVerified no Firestore.
  Future<void> _updateEmailVerifiedInFirestore(String uid) async {
    try {
      final db = FirebaseFirestore.instance;
      await db.collection('users').doc(uid).update({'emailVerified': true});
    } catch (e) {
      debugPrint('[AuthRepository] _updateEmailVerifiedInFirestore error: $e');
    }
  }

  /// Login com Firebase Auth real. Fallback para mock se Firebase falhar.
  Future<AuthUserModel> login(String email, String password) async {
    if (!_isFirebaseAvailable) {
      return _mockLogin(email, password);
    }

    try {
      final credential = await _firebaseAuth?.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fbUser = credential?.user;
      if (fbUser == null) {
        return _mockLogin(email, password);
      }

      // Atualiza emailVerified no Firestore se confirmado
      if (fbUser.emailVerified) {
        _updateEmailVerifiedInFirestore(fbUser.uid);
      }

      // Tenta obter role do Firestore primeiro
      final roleStr = await _getRoleFromFirestore(fbUser.uid);
      if (roleStr != null) {
        return AuthUserModel(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          nome: fbUser.displayName ?? fbUser.email ?? '',
          role: UserRole.fromValue(roleStr),
          photoUrl: fbUser.photoURL,
        );
      }

      // Fallback rápido: tenta API PHP com timeout curto
      try {
        return await _fetchProfile(fbUser).timeout(
          const Duration(seconds: 6),
          onTimeout: () => throw Exception('API timeout'),
        );
      } catch (e) {
        // Se tudo falhar, usa dados básicos do Firebase
        debugPrint('[AuthRepository] Profile fetch failed, using Firebase data: $e');
        return AuthUserModel(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          nome: fbUser.displayName ?? fbUser.email ?? '',
          role: UserRole.guardian,
          photoUrl: fbUser.photoURL,
        );
      }
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    } catch (e) {
      debugPrint('[AuthRepository] Login error, falling back to mock: $e');
      return _mockLogin(email, password);
    }
  }

  /// Registro com Firebase Auth real + criação de registro no MySQL via API.
  Future<AuthUserModel> register({
    required String name,
    required String email,
    required String password,
    required String whatsapp,
    required UserRole role,
  }) async {
    if (!_isFirebaseAvailable) {
      return _mockRegister(
        name: name,
        email: email,
        password: password,
        whatsapp: whatsapp,
        role: role,
      );
    }

    try {
      // 1. Cria usuário no Firebase Auth
      final credential = await _firebaseAuth?.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fbUser = credential?.user;
      if (fbUser == null) {
        throw Exception('Falha ao criar usuário no Firebase');
      }

      // 2. Atualiza displayName no Firebase
      await fbUser.updateDisplayName(name);

      // 3. Grava documento no Firestore (independente da API PHP)
      try {
        await _writeUserToFirestore(
          uid: fbUser.uid,
          nome: name,
          email: email,
          role: role.value,
          telefone: whatsapp,
        );
      } catch (e) {
        debugPrint('[AuthRepository] Firestore write failed, continuing: $e');
      }

      // 4. Registra no MySQL via API PHP (não bloqueia cadastro)
      try {
        final token = await fbUser.getIdToken();
        await _apiService.post(
          ApiConstants.authRegister,
          data: {
            'uid': fbUser.uid,
            'nome': name,
            'email': email,
            'telefone': whatsapp,
            'role': role.value,
          },
        );
        debugPrint('[AuthRepository] Registered UID=${fbUser.uid}, token_prefix=${token?.substring(0, 10)}');
      } catch (e) {
        debugPrint('[AuthRepository] API register call failed, continuing: $e');
      }

      // 5. Envia e-mail de verificação
      try {
        await fbUser.sendEmailVerification();
        debugPrint('[AuthRepository] Email verification sent to $email');
      } catch (e) {
        debugPrint('[AuthRepository] sendEmailVerification error: $e');
      }

      return AuthUserModel(
        uid: fbUser.uid,
        email: email,
        nome: name,
        role: role,
        telefone: whatsapp,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    } catch (e) {
      debugPrint('[AuthRepository] Register error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    if (_isFirebaseAvailable) {
      try {
        await _firebaseAuth?.signOut();
      } catch (e) {
        debugPrint('[AuthRepository] Logout error: $e');
      }
    }
  }

  /// Verifica se há usuário logado ao iniciar o app.
  Future<AuthUserModel?> currentUser() async {
    if (!_isFirebaseAvailable) return null;
    try {
      final fbUser = _firebaseAuth?.currentUser;
      if (fbUser == null) return null;

      // Atualiza emailVerified se confirmado
      if (fbUser.emailVerified) {
        _updateEmailVerifiedInFirestore(fbUser.uid);
      }

      // Tenta role do Firestore primeiro
      final roleStr = await _getRoleFromFirestore(fbUser.uid);
      if (roleStr != null) {
        return AuthUserModel(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          nome: fbUser.displayName ?? fbUser.email ?? '',
          role: UserRole.fromValue(roleStr),
          photoUrl: fbUser.photoURL,
        );
      }

      return _fetchProfile(fbUser);
    } catch (e) {
      debugPrint('[AuthRepository] currentUser error: $e');
      return null;
    }
  }

  /// Busca perfil do usuário na API PHP.
  Future<AuthUserModel> _fetchProfile(User fbUser) async {
    try {
      final response = await _apiService.get(ApiConstants.authProfile);
      final responseData = response.data as Map<String, dynamic>;
      final data = responseData['data'] as Map<String, dynamic>? ?? responseData;
      return AuthUserModel(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
        nome: data['nome'] ?? fbUser.displayName ?? fbUser.email ?? '',
        role: UserRole.fromValue(data['role'] as String?),
        telefone: data['telefone'] as String?,
        photoUrl: fbUser.photoURL,
      );
    } catch (e) {
      debugPrint('[AuthRepository] _fetchProfile failed, using Firebase data: $e');
      // Fallback: usa dados do Firebase Auth diretamente
      return AuthUserModel(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
        nome: fbUser.displayName ?? fbUser.email ?? '',
        role: UserRole.guardian,
        photoUrl: fbUser.photoURL,
      );
    }
  }

  // --- Mock fallbacks ---

  AuthUserModel _mockLogin(String email, String password) {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('E-mail e senha são obrigatórios.');
    }
    if (password.length < 6) {
      throw Exception('Senha deve ter pelo menos 6 caracteres.');
    }
    final role = (email.contains('motorista') || email.contains('driver'))
        ? UserRole.driver
        : UserRole.guardian;
    final name = email.split('@').first.replaceAll('.', ' ');
    return AuthUserModel(
      uid: 'mock_uid_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      nome: _capitalize(name),
      role: role,
      telefone: '11999999999',
    );
  }

  AuthUserModel _mockRegister({
    required String name,
    required String email,
    required String password,
    required String whatsapp,
    required UserRole role,
  }) {
    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      throw Exception('Preencha todos os campos obrigatórios.');
    }
    if (password.length < 6) {
      throw Exception('Senha deve ter pelo menos 6 caracteres.');
    }
    return AuthUserModel(
      uid: 'mock_uid_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      nome: name.trim(),
      role: role,
      telefone: whatsapp,
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Exception _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('Usuário não encontrado.');
      case 'wrong-password':
        return Exception('Senha incorreta.');
      case 'email-already-in-use':
        return Exception('E-mail já cadastrado.');
      case 'weak-password':
        return Exception('Senha muito fraca (mínimo 6 caracteres).');
      case 'invalid-email':
        return Exception('E-mail inválido.');
      case 'too-many-requests':
        return Exception('Muitas tentativas. Tente novamente mais tarde.');
      default:
        return Exception('Erro de autenticação: ${e.message}');
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(apiService: ref.read(apiServiceProvider));
});
