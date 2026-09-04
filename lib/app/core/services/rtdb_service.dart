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

  static const _weekDays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

  String _formatUpdate(DateTime dt) {
    final day  = _weekDays[dt.weekday % 7];
    final d    = dt.day.toString().padLeft(2, '0');
    final mo   = dt.month.toString().padLeft(2, '0');
    final h    = dt.hour.toString().padLeft(2, '0');
    final m    = dt.minute.toString().padLeft(2, '0');
    return '$day $d/$mo • $h:$m';
  }

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

  /// Responsável grava talk_requested no RTDB.
  Future<void> writeTalkRequest(String alunoId, bool requested) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _studentRef(alunoId).update({
      'talk_requested':    requested,
      'talk_ts':           ServerValue.timestamp,
      'talk_acknowledged': false, // reset ao fazer nova solicitação
    });
  }

  /// Motorista grava talk_acknowledged no RTDB.
  Future<void> writeTalkAcknowledged(String alunoId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _studentRef(alunoId).update({
      'talk_acknowledged': true,
      'talk_ack_ts':       ServerValue.timestamp,
    });
  }

  /// Stream de talk_requested — usado pelo motorista.
  /// Retorna ({requested, acknowledged}) para que o driver possa
  /// refletir o ack do RTDB sem sobrescrever o estado local incorretamente.
  /// Emite null se não houver dado de hoje ou anterior ao [afterMs].
  Stream<({bool requested, bool acknowledged})?> watchTalkRequest(
      String alunoId, {int? afterMs}) {
    return _studentRef(alunoId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      final map = Map<String, dynamic>.from(data as Map);

      final ts = map['talk_ts'];
      if (ts is! int) return null;

      final recorded = DateTime.fromMillisecondsSinceEpoch(ts);
      final today    = DateTime.now();
      if (recorded.year != today.year ||
          recorded.month != today.month ||
          recorded.day   != today.day) return null;

      if (afterMs != null && ts <= afterMs) return null;

      final requested = map['talk_requested'] as bool? ?? false;
      final acked     = map['talk_acknowledged'] as bool? ?? false;
      return (requested: requested, acknowledged: acked);
    });
  }

  /// Stream de talk_acknowledged — usado pelo responsável.
  Stream<({bool acknowledged, String? ackedAt})?> watchTalkAcknowledged(String alunoId) {
    return _studentRef(alunoId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      final map = Map<String, dynamic>.from(data as Map);

      final ts = map['talk_ack_ts'];
      if (ts is! int) return null;

      final recorded = DateTime.fromMillisecondsSinceEpoch(ts);
      final today    = DateTime.now();
      if (recorded.year != today.year ||
          recorded.month != today.month ||
          recorded.day   != today.day) return null;

      final acked  = map['talk_acknowledged'] as bool? ?? false;
      final ackedAt = acked ? _formatUpdate(recorded) : null;
      return (acknowledged: acked, ackedAt: ackedAt);
    });
  }

  /// Responsável grava o vai_hoje do aluno no RTDB.
  Future<void> writeGoToday(String alunoId, bool goToday) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _studentRef(alunoId).update({
      'vai_hoje':    goToday,
      'vai_hoje_ts': ServerValue.timestamp,
    });
  }

  /// Stream do vai_hoje do aluno — usado pelo motorista para atualização em tempo real.
  /// Emite null se não houver dado de hoje ou se o dado for anterior a [afterMs].
  /// [afterMs]: timestamp em ms do último refresh do motorista — ignora dados antigos.
  Stream<bool?> watchGoToday(String alunoId, {int? afterMs}) {
    return _studentRef(alunoId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;

      final map = Map<String, dynamic>.from(data as Map);

      final ts = map['vai_hoje_ts'];
      if (ts is! int) return null;

      // Ignora dados de dias anteriores
      final recorded = DateTime.fromMillisecondsSinceEpoch(ts);
      final today    = DateTime.now();
      final sameDay  = recorded.year  == today.year &&
                       recorded.month == today.month &&
                       recorded.day   == today.day;
      if (!sameDay) return null;

      // Ignora dados anteriores ao último refresh do motorista
      if (afterMs != null && ts <= afterMs) return null;

      final raw = map['vai_hoje'];
      if (raw == null) return null;
      return raw as bool;
    });
  }

  /// Stream do status do aluno — usado pelo responsável para atualização em tempo real.
  /// Emite null se não houver dado ou se o dado for de um dia anterior.
  /// Retorna ({status, lastUpdate}) onde lastUpdate é a hora real do movimento (HH:mm).
  Stream<({StudentStatus status, String lastUpdate})?> watchStatus(String alunoId) {
    return _studentRef(alunoId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;

      final map = Map<String, dynamic>.from(data as Map);

      // Ignora dados gravados em dias anteriores
      final ts = map['ts'];
      String lastUpdate;
      if (ts is int) {
        final recorded = DateTime.fromMillisecondsSinceEpoch(ts);
        final today = DateTime.now();
        final sameDay = recorded.year == today.year &&
            recorded.month == today.month &&
            recorded.day == today.day;
        if (!sameDay) return null;
        lastUpdate = _formatUpdate(recorded);
      } else {
        // ts ausente: usa hora atual como fallback
        lastUpdate = _formatUpdate(DateTime.now());
      }

      final raw = map['currentStatus'] as String?;
      if (raw == null) return null;
      return (status: StudentStatus.fromValue(raw), lastUpdate: lastUpdate);
    });
  }
}
