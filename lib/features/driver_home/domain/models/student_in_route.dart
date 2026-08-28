import '../../../../app/core/constants/status_constants.dart';

class StudentInRoute {
  final String id;
  final String name;
  final String address;
  final String school;
  final StudentStatus status;
  final bool goToday;
  final bool talkRequested;
  /// true after driver clicks "Ciente" but before clicking WhatsApp
  final bool talkAcknowledged;
  final String? photoUrl;
  final String guardianWhatsapp;
  final String guardianName;
  /// null = participates in all 4 routes
  final List<RoutePeriod>? activeRoutes;
  final bool paymentPaid;

  const StudentInRoute({
    required this.id,
    required this.name,
    required this.address,
    required this.school,
    required this.status,
    required this.goToday,
    required this.talkRequested,
    this.talkAcknowledged = false,
    this.photoUrl,
    required this.guardianWhatsapp,
    required this.guardianName,
    this.activeRoutes,
    this.paymentPaid = true,
  });

  bool participatesIn(RoutePeriod period) =>
      activeRoutes == null || activeRoutes!.contains(period);

  StudentInRoute copyWith({
    String? id,
    String? name,
    String? address,
    String? school,
    StudentStatus? status,
    bool? goToday,
    bool? talkRequested,
    bool? talkAcknowledged,
    String? photoUrl,
    String? guardianWhatsapp,
    String? guardianName,
    List<RoutePeriod>? activeRoutes,
    bool? paymentPaid,
  }) {
    return StudentInRoute(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      school: school ?? this.school,
      status: status ?? this.status,
      goToday: goToday ?? this.goToday,
      talkRequested: talkRequested ?? this.talkRequested,
      talkAcknowledged: talkAcknowledged ?? this.talkAcknowledged,
      photoUrl: photoUrl ?? this.photoUrl,
      guardianWhatsapp: guardianWhatsapp ?? this.guardianWhatsapp,
      guardianName: guardianName ?? this.guardianName,
      activeRoutes: activeRoutes ?? this.activeRoutes,
      paymentPaid: paymentPaid ?? this.paymentPaid,
    );
  }
}
