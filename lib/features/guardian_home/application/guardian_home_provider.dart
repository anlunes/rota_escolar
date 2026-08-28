import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/students_repository.dart';
import '../domain/models/student_summary.dart';
import '../../../../app/core/constants/status_constants.dart';
import '../../driver_home/application/driver_home_provider.dart';

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

  GuardianHomeNotifier(this._ref, this._studentsRepository)
      : super(const GuardianHomeState(students: [])) {
    loadStudents();
  }

  Future<void> loadStudents() async {
    state = state.copyWith(isLoading: true);
    try {
      final students = await _studentsRepository.fetchStudents();
      state = state.copyWith(students: students, isLoading: false);
    } catch (e) {
      debugPrint('[GuardianHomeNotifier] loadStudents error: $e');
      state = state.copyWith(isLoading: false);
    }
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
    required String residenceCep,
    String? vanCode,
    String? existingId,
    String? photoUrl,
  }) {
    final id = existingId ?? 'st_${DateTime.now().millisecondsSinceEpoch}';
    final existing = state.students.any((s) => s.id == id);

    final student = StudentSummary(
      id: id,
      name: name,
      school: school,
      residenceCep: residenceCep,
      cicloEscolar: 'A definir',
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

    // Save to API first and update state with real ID
    _studentsRepository
        .saveStudent(
      name: name,
      school: school,
      residenceCep: residenceCep,
      vanCode: vanCode,
      existingId: existingId,
    )
        .then((savedStudent) {
      if (savedStudent != null) {
        // Update state with real ID from API
        final updated = state.students.map((s) {
          if (s.id == id) return savedStudent;
          return s;
        }).toList();
        state = state.copyWith(students: updated);
      }
    }).catchError((e) {
      // API unavailable — local state already updated with mock ID
      return null;
    });

    // If vanCode provided, send opportunity to driver provider
    if (vanCode != null && vanCode.trim().isNotEmpty) {
      final opp = CandidateOpportunity(
        id: 'opp_$id',
        studentName: name,
        guardianName: 'Responsável',
        guardianWhatsapp: '11999999999',
        address: 'CEP: $residenceCep',
        school: school,
        period: 'A definir',
      );
      _ref.read(driverHomeProvider.notifier).addOpportunity(opp);
    }
  }
}

final guardianHomeProvider =
    StateNotifierProvider<GuardianHomeNotifier, GuardianHomeState>((ref) {
  return GuardianHomeNotifier(ref, ref.read(studentsRepositoryProvider));
});
