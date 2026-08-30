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
  final Map<String, StreamSubscription<StudentStatus?>> _statusSubs = {};

  GuardianHomeNotifier(this._ref, this._studentsRepository)
      : super(const GuardianHomeState(students: [])) {
    loadStudents();
  }

  @override
  void dispose() {
    for (final sub in _statusSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> loadStudents() async {
    state = state.copyWith(isLoading: true);
    try {
      final students = await _studentsRepository.fetchStudents();
      state = state.copyWith(students: students, isLoading: false);
      _subscribeToRtdbStatus(students);
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
          .listen((newStatus) {
        if (newStatus == null || !mounted) return;
        final now = _formattedNow();
        state = state.copyWith(
          students: state.students.map((s) {
            if (s.id == student.id) {
              return s.copyWith(status: newStatus, lastUpdateTime: now);
            }
            return s;
          }).toList(),
        );
      }, onError: (e) {
        debugPrint('[GuardianHomeNotifier] RTDB watchStatus error (${student.id}): $e');
      });
    }
  }

  String _formattedNow() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void toggleGoToday(String studentId) {
    final updated = state.students.map<StudentSummary>((s) {
      if (s.id == studentId) return s.copyWith(goToday: !s.goToday);
      return s;
    }).toList();
    state = state.copyWith(students: updated);
  }

  void toggleTalkRequest(String studentId) {
    final updated = state.students.map<StudentSummary>((s) {
      if (s.id == studentId) {
        return s.copyWith(
          talkRequested: !s.talkRequested,
          talkAcknowledgedByDriver: false,
        );
      }
      return s;
    }).toList();
    state = state.copyWith(students: updated);
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
