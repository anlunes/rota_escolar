import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/driver_repository.dart';
import '../domain/models/student_in_route.dart';
import '../../../../app/core/constants/status_constants.dart';
import '../../../../app/core/services/rtdb_service.dart';

// ---------------------------------------------------------------------------
// Payment record
// ---------------------------------------------------------------------------

class PaymentRecord {
  final String studentName;
  final String month;
  final double amount;
  final bool paid;
  final bool paidInCash;

  const PaymentRecord({
    required this.studentName,
    required this.month,
    required this.amount,
    required this.paid,
    this.paidInCash = false,
  });
}

// ---------------------------------------------------------------------------
// Opportunity
// ---------------------------------------------------------------------------

class CandidateOpportunity {
  final String id;
  final int alunoId;
  final String studentName;
  final String guardianName;
  final String guardianWhatsapp;
  final String address;
  final String school;
  final String period;
  bool accepted;
  bool declined;

  CandidateOpportunity({
    required this.id,
    required this.alunoId,
    required this.studentName,
    required this.guardianName,
    required this.guardianWhatsapp,
    required this.address,
    required this.school,
    required this.period,
    this.accepted = false,
    this.declined = false,
  });
}

// ---------------------------------------------------------------------------
// Driver Home State
// ---------------------------------------------------------------------------

class DriverHomeState {
  final List<StudentInRoute> students;
  final RoutePeriod selectedPeriod;
  final List<PaymentRecord> payments;
  final List<CandidateOpportunity> opportunities;
  final bool isLoading;

  const DriverHomeState({
    required this.students,
    required this.selectedPeriod,
    required this.payments,
    required this.opportunities,
    this.isLoading = false,
  });

  DriverHomeState copyWith({
    List<StudentInRoute>? students,
    RoutePeriod? selectedPeriod,
    List<PaymentRecord>? payments,
    List<CandidateOpportunity>? opportunities,
    bool? isLoading,
  }) {
    return DriverHomeState(
      students: students ?? this.students,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      payments: payments ?? this.payments,
      opportunities: opportunities ?? this.opportunities,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<StudentInRoute> get todayStudents =>
      students.where((s) => s.goToday).toList();

  List<StudentInRoute> get studentsForCurrentPeriod {
    return students.where((s) => s.participatesIn(selectedPeriod)).toList();
  }

  int get talkRequestCount =>
      students.where((s) => s.talkRequested && !s.talkAcknowledged).length;
}

// ---------------------------------------------------------------------------
// Driver Home Notifier
// ---------------------------------------------------------------------------

class DriverHomeNotifier extends StateNotifier<DriverHomeState> {
  final DriverRepository _repository;
  final Map<String, StreamSubscription<bool?>> _goTodaySubs = {};
  final Map<String, StreamSubscription<({bool requested, bool acknowledged})?>> _talkRequestSubs = {};

  @override
  void dispose() {
    for (final sub in _goTodaySubs.values) sub.cancel();
    for (final sub in _talkRequestSubs.values) sub.cancel();
    super.dispose();
  }

  DriverHomeNotifier(this._repository)
      : super(
          const DriverHomeState(
            students: [],
            selectedPeriod: RoutePeriod.morningOutbound,
            payments: [],
            opportunities: [],
          ),
        ) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _repository.fetchRouteStudents(),
        _repository.fetchPayments(),
        _repository.fetchOpportunities(),
      ]);
      final students = results[0] as List<StudentInRoute>;
      state = state.copyWith(
        students:      students,
        payments:      results[1] as List<PaymentRecord>,
        opportunities: results[2] as List<CandidateOpportunity>,
        isLoading: false,
      );
      _subscribeToGoToday(students);
      _subscribeToTalkRequest(students);
    } catch (e) {
      debugPrint('[DriverHomeNotifier] _loadInitialData error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() => _loadInitialData();

  /// Subscreve ao RTDB para atualizações de vai_hoje em tempo real.
  /// Usa [refreshMs] para ignorar dados gravados antes do último refresh.
  void _subscribeToGoToday(List<StudentInRoute> students) {
    for (final sub in _goTodaySubs.values) {
      sub.cancel();
    }
    _goTodaySubs.clear();

    final refreshMs = DateTime.now().millisecondsSinceEpoch;

    for (final student in students) {
      _goTodaySubs[student.id] = RtdbService.instance
          .watchGoToday(student.id, afterMs: refreshMs)
          .listen((goToday) {
        if (!mounted || goToday == null) return;
        state = state.copyWith(
          students: state.students.map((s) {
            if (s.id == student.id) return s.copyWith(goToday: goToday);
            return s;
          }).toList(),
        );
      }, onError: (e) {
        debugPrint('[DriverHomeNotifier] RTDB watchGoToday error (${student.id}): $e');
      });
    }
  }

  void setPeriod(RoutePeriod period) {
    state = state.copyWith(selectedPeriod: period);
  }

  /// Reorder within the currently selected period's filtered view
  void reorderStudentsInPeriod(int oldIndex, int newIndex) {
    final period = state.selectedPeriod;
    final fullList = List<StudentInRoute>.from(state.students);

    final participatingIndices = fullList
        .asMap()
        .entries
        .where((e) => e.value.participatesIn(period))
        .map((e) => e.key)
        .toList();

    if (newIndex > oldIndex) newIndex -= 1;

    final fromFullIndex = participatingIndices[oldIndex];
    final item = fullList.removeAt(fromFullIndex);

    final newParticipatingIndices = fullList
        .asMap()
        .entries
        .where((e) => e.value.participatesIn(period))
        .map((e) => e.key)
        .toList();

    final int toFullIndex;
    if (newIndex >= newParticipatingIndices.length) {
      toFullIndex = fullList.length;
    } else {
      toFullIndex = newParticipatingIndices[newIndex];
    }

    fullList.insert(toFullIndex, item);
    state = state.copyWith(students: fullList);

    // Persist reorder to API (fire and forget)
    final orderedIds = fullList
        .where((s) => s.participatesIn(period))
        .map((s) => s.id)
        .toList();
    _repository.reorderStudents(orderedIds, period).catchError((_) => false);
  }

  void updateStudentStatus(String studentId, StudentStatus newStatus) {
    // Atualiza UI imediatamente
    final updated = state.students.map<StudentInRoute>((s) {
      if (s.id == studentId) return s.copyWith(status: newStatus);
      return s;
    }).toList();
    state = state.copyWith(students: updated);

    // Persiste no Firebase RTDB (tempo real para o responsável)
    RtdbService.instance.writeStatus(studentId, newStatus).catchError((e) {
      debugPrint('[DriverHomeNotifier] RTDB writeStatus error: $e');
      return null;
    });

    // Persiste no MySQL (histórico)
    _repository.updateStudentStatus(studentId, newStatus).catchError((_) => false);
  }

  /// Subscreve ao RTDB para atualizações de talk_requested em tempo real.
  void _subscribeToTalkRequest(List<StudentInRoute> students) {
    for (final sub in _talkRequestSubs.values) sub.cancel();
    _talkRequestSubs.clear();

    final refreshMs = DateTime.now().millisecondsSinceEpoch;

    for (final student in students) {
      _talkRequestSubs[student.id] = RtdbService.instance
          .watchTalkRequest(student.id, afterMs: refreshMs)
          .listen((payload) {
        if (!mounted || payload == null) return;
        state = state.copyWith(
          students: state.students.map((s) {
            if (s.id == student.id) {
              return s.copyWith(
                talkRequested:   payload.requested,
                talkAcknowledged: payload.acknowledged,
              );
            }
            return s;
          }).toList(),
        );
      }, onError: (e) {
        debugPrint('[DriverHomeNotifier] RTDB watchTalkRequest error (${student.id}): $e');
      });
    }
  }

  void acknowledgeTalkRequest(String studentId) {
    // Otimista
    final updated = state.students.map<StudentInRoute>((s) {
      if (s.id == studentId) return s.copyWith(talkAcknowledged: true);
      return s;
    }).toList();
    state = state.copyWith(students: updated);

    // RTDB — responsável vê em tempo real
    RtdbService.instance.writeTalkAcknowledged(studentId).catchError((e) {
      debugPrint('[DriverHomeNotifier] RTDB writeTalkAcknowledged error: $e');
      return null;
    });

    // MySQL
    _repository.ackTalkRequest(studentId).catchError((_) => false);
  }

  void removeTalkRequest(String studentId) {
    final updated = state.students.map<StudentInRoute>((s) {
      if (s.id == studentId) {
        return s.copyWith(talkRequested: false, talkAcknowledged: false);
      }
      return s;
    }).toList();
    state = state.copyWith(students: updated);
  }

  void addOpportunity(CandidateOpportunity opp) {
    state = state.copyWith(opportunities: [...state.opportunities, opp]);
  }

  void removeStudentFromRoute(String studentId, RoutePeriod period) {
    final updated = state.students.map<StudentInRoute>((s) {
      if (s.id == studentId) {
        final current = s.activeRoutes ?? RoutePeriod.values;
        final newRoutes = current.where((r) => r != period).toList();
        return s.copyWith(activeRoutes: newRoutes);
      }
      return s;
    }).toList();
    state = state.copyWith(students: updated);
  }

  void markPaymentCash(int index) {
    final list = List<PaymentRecord>.from(state.payments);
    final p = list[index];
    list[index] = PaymentRecord(
      studentName: p.studentName,
      month: p.month,
      amount: p.amount,
      paid: true,
      paidInCash: true,
    );
    state = state.copyWith(payments: list);

    // Persist to API (fire and forget)
    _repository.markPayment('payment_$index').catchError((_) => false);
  }

  Future<void> acceptOpportunity(String id) async {
    final opp = state.opportunities.firstWhere((o) => o.id == id);

    // Persiste no banco
    final ok = await _repository.respondOpportunity(opp.alunoId, 'accept');
    if (!ok) return;

    final list = state.opportunities.map((o) {
      if (o.id == id) {
        o.accepted = true;
        o.declined = false;
      }
      return o;
    }).toList();

    final newStudent = StudentInRoute(
      id: opp.alunoId.toString(),
      name: opp.studentName,
      address: opp.address,
      school: opp.school,
      status: StudentStatus.waitingVan,
      goToday: false,
      talkRequested: false,
      guardianWhatsapp: opp.guardianWhatsapp,
      guardianName: opp.guardianName,
      paymentPaid: true,
    );

    state = state.copyWith(
      opportunities: list,
      students: [...state.students, newStudent],
    );
  }

  Future<void> declineOpportunity(String id) async {
    final opp = state.opportunities.firstWhere((o) => o.id == id);
    await _repository.respondOpportunity(opp.alunoId, 'decline');

    final list = state.opportunities.map((o) {
      if (o.id == id) {
        o.declined = true;
        o.accepted = false;
      }
      return o;
    }).toList();
    state = state.copyWith(opportunities: list);
  }
}

final driverHomeProvider =
    StateNotifierProvider<DriverHomeNotifier, DriverHomeState>((ref) {
  return DriverHomeNotifier(ref.read(driverRepositoryProvider));
});
