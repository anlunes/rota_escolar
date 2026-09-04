import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/students_repository.dart';
import '../domain/models/student_summary.dart';
import '../../../../app/core/constants/status_constants.dart';
import '../../../../app/core/services/rtdb_service.dart';

class GuardianHomeState {
  final List<StudentSummary> students;
  final bool showEvaluation;
  final bool isLoading;

  const GuardianHomeState({
    required this.students,
    this.showEvaluation = false,
    this.isLoading = false,
  });

  GuardianHomeState copyWith({
    List<StudentSummary>? students,
    bool? showEvaluation,
    bool? isLoading,
  }) {
    return GuardianHomeState(
      students: students ?? this.students,
      showEvaluation: showEvaluation ?? this.showEvaluation,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class GuardianHomeNotifier extends StateNotifier<GuardianHomeState> {
  final Ref _ref;
  final StudentsRepository _studentsRepository;
  final Map<String, StreamSubscription<({StudentStatus status, String lastUpdate})?>> _statusSubs = {};
  final Map<String, StreamSubscription<({bool acknowledged, String? ackedAt})?>> _talkAckSubs = {};

  GuardianHomeNotifier(this._ref, this._studentsRepository)
      : super(const GuardianHomeState(students: [])) {
    loadStudents();
  }

  @override
  void dispose() {
    for (final sub in _statusSubs.values) sub.cancel();
    for (final sub in _talkAckSubs.values) sub.cancel();
    super.dispose();
  }

  Future<void> loadStudents() async {
    state = state.copyWith(isLoading: true);
    try {
      final students = await _studentsRepository.fetchStudents();
      state = state.copyWith(students: students, isLoading: false);
      _subscribeToRtdbStatus(students);
      _subscribeToTalkAck(students);
    } catch (e) {
      debugPrint('[GuardianHomeNotifier] loadStudents error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Subscreve ao Firebase RTDB para atualizações de status em tempo real.
  void _subscribeToRtdbStatus(List<StudentSummary> students) {
    // Cancela subscrições antigas
    for (final sub in _statusSubs.values) {
      sub.cancel();
    }
    _statusSubs.clear();

    for (final student in students) {
      if (!student.ativo || student.driverName.isEmpty || student.driverName == 'Sem motorista') {
        continue; // Só escuta alunos que já têm motorista
      }

      _statusSubs[student.id] = RtdbService.instance
          .watchStatus(student.id)
          .listen((payload) {
        if (!mounted) return;
        state = state.copyWith(
          students: state.students.map((s) {
            if (s.id == student.id) {
              // null = nó deletado (reset) ou sem atividade hoje → volta ao início
              return s.copyWith(
                status: payload?.status ?? StudentStatus.waitingVan,
                lastUpdateTime: payload?.lastUpdate,
              );
            }
            return s;
          }).toList(),
        );
      }, onError: (e) {
        debugPrint('[GuardianHomeNotifier] RTDB watchStatus error (${student.id}): $e');
      });
    }
  }

  /// Subscreve ao RTDB para saber quando o motorista confirma leitura.
  void _subscribeToTalkAck(List<StudentSummary> students) {
    for (final sub in _talkAckSubs.values) sub.cancel();
    _talkAckSubs.clear();

    for (final student in students) {
      if (!student.ativo || student.driverName.isEmpty || student.driverName == 'Sem motorista') continue;

      _talkAckSubs[student.id] = RtdbService.instance
          .watchTalkAcknowledged(student.id)
          .listen((payload) {
        if (!mounted || payload == null) return;
        state = state.copyWith(
          students: state.students.map((s) {
            if (s.id == student.id) {
              return s.copyWith(
                talkAcknowledgedByDriver: payload.acknowledged,
                talkAcknowledgedAt: payload.acknowledged ? payload.ackedAt : null,
              );
            }
            return s;
          }).toList(),
        );
      }, onError: (e) {
        debugPrint('[GuardianHomeNotifier] RTDB watchTalkAcknowledged error (${student.id}): $e');
      });
    }
  }

  void toggleGoToday(String studentId) {
    final student = state.students.firstWhere((s) => s.id == studentId);
    final newGoToday = !student.goToday;

    // Otimista: atualiza UI imediatamente
    final updated = state.students.map<StudentSummary>((s) {
      if (s.id == studentId) return s.copyWith(goToday: newGoToday);
      return s;
    }).toList();
    state = state.copyWith(students: updated);

    // Persiste no RTDB (tempo real para o motorista)
    RtdbService.instance.writeGoToday(studentId, newGoToday).catchError((e) {
      debugPrint('[GuardianHomeNotifier] RTDB writeGoToday error: $e');
      return null;
    });

    // Persiste no MySQL
    _studentsRepository.toggleGoToday(studentId, newGoToday).catchError((e) {
      debugPrint('[GuardianHomeNotifier] toggleGoToday API error: $e');
    });
  }

  void toggleTalkRequest(String studentId) {
    final student = state.students.firstWhere((s) => s.id == studentId);
    final newRequested = !student.talkRequested;

    // Otimista
    final updated = state.students.map<StudentSummary>((s) {
      if (s.id == studentId) {
        return s.copyWith(
          talkRequested: newRequested,
          talkAcknowledgedByDriver: false,
        );
      }
      return s;
    }).toList();
    state = state.copyWith(students: updated);

    // RTDB — tempo real para o motorista
    RtdbService.instance.writeTalkRequest(studentId, newRequested).catchError((e) {
      debugPrint('[GuardianHomeNotifier] RTDB writeTalkRequest error: $e');
      return null;
    });

    // MySQL
    _studentsRepository.toggleTalkRequest(studentId, newRequested).catchError((e) {
      debugPrint('[GuardianHomeNotifier] toggleTalkRequest API error: $e');
    });
  }

  void simulateDriverAcknowledge(String studentId) {
    final updated = state.students.map<StudentSummary>((s) {
      if (s.id == studentId) {
        return s.copyWith(talkAcknowledgedByDriver: true);
      }
      return s;
    }).toList();
    state = state.copyWith(students: updated);
  }

  Future<void> deleteStudent(String studentId, {void Function(String)? onError}) async {
    try {
      await _studentsRepository.deleteStudent(studentId);
      // Marca como inativo no estado local (fica visível para reativar)
      final updated = state.students.map<StudentSummary>((s) {
        if (s.id == studentId) return s.copyWith(ativo: false);
        return s;
      }).toList();
      state = state.copyWith(students: updated);
    } catch (e) {
      onError?.call(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> reactivateStudent(String studentId, {void Function(String)? onError}) async {
    try {
      await _studentsRepository.reactivateStudent(studentId);
      final updated = state.students.map<StudentSummary>((s) {
        if (s.id == studentId) return s.copyWith(ativo: true);
        return s;
      }).toList();
      state = state.copyWith(students: updated);
    } catch (e) {
      onError?.call(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void updateStudentInfo({
    required String studentId,
    required String name,
    required String school,
    required String residenceCep,
  }) {
    final updated = state.students.map<StudentSummary>((s) {
      if (s.id == studentId) {
        return s.copyWith(
          name: name,
          school: school,
          residenceCep: residenceCep,
        );
      }
      return s;
    }).toList();
    state = state.copyWith(students: updated);
  }

  /// Register or update a child. If vanCode is provided, adds an opportunity
  /// to the driver's provider.
  void registerChild({
    required String name,
    required String school,
    int? escolaId,
    required String residenceCep,
    String? logradouro,
    String? numero,
    String? complemento,
    String? bairro,
    String? cicloEscolar,
    String? turno,
    String? dataNascimento,
    String? vanCode,
    String? existingId,
    String? photoUrl,
    void Function(String)? onError,
  }) {
    final id = existingId ?? 'st_${DateTime.now().millisecondsSinceEpoch}';
    final existing = state.students.any((s) => s.id == id);

    final student = StudentSummary(
      id: id,
      name: name,
      school: school,
      residenceCep: residenceCep,
      cicloEscolar: cicloEscolar ?? 'A definir',
      status: StudentStatus.waitingVan,
      goToday: false,
      talkRequested: false,
      talkAcknowledgedByDriver: false,
      driverName: vanCode != null ? 'Aguardando motorista' : 'Sem motorista',
      driverWhatsapp: '',
      ativo: true,
      photoUrl: photoUrl,
    );

    final List<StudentSummary> updated;
    if (existing) {
      updated = state.students.map((s) => s.id == id ? student : s).toList();
    } else {
      updated = [...state.students, student];
    }
    state = state.copyWith(students: updated);

    _studentsRepository.saveStudent(
      name: name,
      school: school,
      escolaId: escolaId,
      residenceCep: residenceCep,
      logradouro: logradouro,
      numero: numero,
      complemento: complemento,
      bairro: bairro,
      cicloEscolar: cicloEscolar,
      turno: turno,
      dataNascimento: dataNascimento,
      vanCode: vanCode,
      existingId: existingId,
    ).then((savedStudent) {
      if (savedStudent != null) {
        final updated = state.students
            .map((s) => s.id == id ? savedStudent : s)
            .toList();
        state = state.copyWith(students: updated);
      } else {
        // Remove da lista local se a API falhou
        state = state.copyWith(
          students: state.students.where((s) => s.id != id).toList(),
        );
      }
    }).catchError((e) {
      debugPrint('[GuardianHomeNotifier] registerChild error: $e');
      state = state.copyWith(
        students: state.students.where((s) => s.id != id).toList(),
      );
      onError?.call(e.toString().replaceFirst('Exception: ', ''));
      return null;
    });
  }
}

final guardianHomeProvider =
    StateNotifierProvider<GuardianHomeNotifier, GuardianHomeState>((ref) {
  return GuardianHomeNotifier(ref, ref.read(studentsRepositoryProvider));
});
