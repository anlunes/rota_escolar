import '../../../../app/core/constants/status_constants.dart';

// Sentinel para distinguir "não passou" de "passou null explicitamente"
const _keep = Object();

class StudentSummary {
  final String id;
  final String name;
  final String school;
  final String residenceCep;
  final String cicloEscolar;
  final StudentStatus status;
  final bool goToday;
  final bool talkRequested;
  final bool talkAcknowledgedByDriver;
  final String? photoUrl;
  final String driverName;
  final String driverWhatsapp;
  final bool ativo;
  final String vanCode;
  final String logradouro;
  final String numero;
  final String complemento;
  final String bairro;
  final String turno;
  final String dataNascimento; // ISO: yyyy-MM-dd
  final String? lastUpdateTime;
  final List<String>? stepTimes;

  const StudentSummary({
    required this.id,
    required this.name,
    required this.school,
    required this.residenceCep,
    required this.cicloEscolar,
    required this.status,
    required this.goToday,
    required this.talkRequested,
    required this.talkAcknowledgedByDriver,
    this.photoUrl,
    required this.driverName,
    required this.driverWhatsapp,
    required this.ativo,
    this.vanCode = '',
    this.logradouro = '',
    this.numero = '',
    this.complemento = '',
    this.bairro = '',
    this.turno = '',
    this.dataNascimento = '',
    this.lastUpdateTime,
    this.stepTimes,
  });

  /// Aluno cadastrou van_code mas o motorista ainda não aceitou
  bool get awaitingDriverAccept => vanCode.isNotEmpty && driverName.isEmpty;

  StudentSummary copyWith({
    String? id,
    String? name,
    String? school,
    String? residenceCep,
    String? cicloEscolar,
    StudentStatus? status,
    bool? goToday,
    bool? talkRequested,
    bool? talkAcknowledgedByDriver,
    String? photoUrl,
    String? driverName,
    String? driverWhatsapp,
    bool? ativo,
    String? vanCode,
    String? logradouro,
    String? numero,
    String? complemento,
    String? bairro,
    String? turno,
    String? dataNascimento,
    Object? lastUpdateTime = _keep,
    List<String>? stepTimes,
  }) {
    return StudentSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      school: school ?? this.school,
      residenceCep: residenceCep ?? this.residenceCep,
      cicloEscolar: cicloEscolar ?? this.cicloEscolar,
      status: status ?? this.status,
      goToday: goToday ?? this.goToday,
      talkRequested: talkRequested ?? this.talkRequested,
      talkAcknowledgedByDriver:
          talkAcknowledgedByDriver ?? this.talkAcknowledgedByDriver,
      photoUrl: photoUrl ?? this.photoUrl,
      driverName: driverName ?? this.driverName,
      driverWhatsapp: driverWhatsapp ?? this.driverWhatsapp,
      ativo: ativo ?? this.ativo,
      vanCode: vanCode ?? this.vanCode,
      logradouro: logradouro ?? this.logradouro,
      numero: numero ?? this.numero,
      complemento: complemento ?? this.complemento,
      bairro: bairro ?? this.bairro,
      turno: turno ?? this.turno,
      dataNascimento: dataNascimento ?? this.dataNascimento,
      lastUpdateTime: lastUpdateTime == _keep
          ? this.lastUpdateTime
          : lastUpdateTime as String?,
      stepTimes: stepTimes ?? this.stepTimes,
    );
  }
}
