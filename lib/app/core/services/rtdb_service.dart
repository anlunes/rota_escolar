import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../constants/status_constants.dart';

/// Serviço de leitura/escrita de status de alunos no Firebase Realtime DB.
///
/// Path (alinhado às regras existentes):
///   studentsRealtime/{alunoId}/currentStatus  → string (ex: "to_school")
///   studentsRealtime/{alunoId}/motoristaUid   → string
///   studentsRealtime/{alunoId}/ts             → server timestamp
class RtdbService {
  RtdbService._();
  static final instance = RtdbService._();

  // URL do banco — us-central1 (conforme configurado no Firebase Console)
  static const _dbUrl =
      'https://rota-escolar-6085e-default-rtdb.firebaseio.com';

  FirebaseDatabase get _db =>
      FirebaseDatabase.instanceFor(
        app: FirebaseDatabase.instance.app,
        databaseURL: _dbUrl,
      );

  DatabaseReference _studentRef(String alunoId) =>
      _db.ref('studentsRealtime/$alunoId');

  /// Motorista grava o novo status do aluno no RTDB.
  Future<void> writeStatus(String alunoId, StudentStatus status) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _studentRef(alunoId).update({
      'currentStatus': status.value,
      'motoristaUid': uid,
      'ts': ServerValue.timestamp,
    });
  }

  /// Stream do status do aluno — usado pelo responsável para atualização em tempo real.
  /// Emite null se não houver dado ou se o dado for de um dia anterior.
  Stream<StudentStatus?> watchStatus(String alunoId) {
    return _studentRef(alunoId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;

      final map = Map<String, dynamic>.from(data as Map);

      // Ignora dados gravados em dias anteriores
      final ts = map['ts'];
      if (ts is int) {
        final recorded = DateTime.fromMillisecondsSinceEpoch(ts);
        final today = DateTime.now();
        final sameDay = recorded.year == today.year &&
            recorded.month == today.month &&
            recorded.day == today.day;
        if (!sameDay) return null;
      }

      final raw = map['currentStatus'] as String?;
      if (raw == null) return null;
      return StudentStatus.fromValue(raw);
    });
  }
}
