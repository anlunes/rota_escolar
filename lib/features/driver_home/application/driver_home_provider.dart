import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/driver_repository.dart';
import '../domain/models/student_in_route.dart';
import '../../../../app/core/constants/status_constants.dart';

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

  List<StudentInRoute> get studentsForCurrentPeriod =>
      students.where((s) => s.participatesIn(selectedPeriod)).toList();

  int get talkRequestCount =>
      students.where((s) => s.talkRequested && !s.talkAcknowledged).length;
}

// ---------------------------------------------------------------------------
// Driver Home Notifier
// ---------------------------------------------------------------------------

class DriverHomeNotifier extends StateNotifier<DriverHomeState> {
  final DriverRepository _repository;

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
      final students = await _repository.fetchRouteStudents();
      final payments = await _repository.fetchPayments();
      state = state.copyWith(
        students: students,
        payments: payments,
        isLoading: false,
        opportunities: [
          CandidateOpportunity(
            id: 'o1',
            studentName: 'Lucas Mendes',
            guardianName: 'Juliana Mendes',
            guardianWhatsapp: '11988881111',
            address: 'Rua Nova, 55 - Bela Vista',
            school: 'E.E. Prof. João Costa',
            period: 'Manhã (ida e volta)',
          ),
          CandidateOpportunity(
            id: 'o2',
            studentName: 'Sofia Rocha',
            guardianName: 'André Rocha',
            guardianWhatsapp: '11988882222',
            address: 'Av. Brasil, 200 - Centro',
            school: 'E.M. Nossa Senhora',
            period: 'Tarde (só ida)',
          ),
        ],
      );
    } catch (e) {
      debugPrint('[DriverHomeNotifier] _loadInitialData error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() => _loadInitialData();

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
    final updated = state.students.map<StudentInRoute>((s) {
      if (s.id == studentId) return s.copyWith(status: newStatus);
      return s;
    }).toList();
    state = state.copyWith(students: updated);
  }

  void acknowledgeTalkRequest(String studentId) {
    final updated = state.students.map<StudentInRoute>((s) {
      if (s.id == studentId) return s.copyWith(talkAcknowledged: true);
      return s;
    }).toList();
    state = state.copyWith(students: updated);
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

  void acceptOpportunity(String id) {
    final opp = state.opportunities.firstWhere((o) => o.id == id);
    final list = state.opportunities.map((o) {
      if (o.id == id) {
        o.accepted = true;
        o.declined = false;
      }
      return o;
    }).toList();

    final newStudent = StudentInRoute(
      id: 'new_$id',
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

  void declineOpportunity(String id) {
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
