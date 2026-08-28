/// Status do aluno durante o transporte escolar
enum StudentStatus {
  waitingVan('waiting_van', 'Aguardando Van'),
  toSchool('to_school', 'A caminho da Escola'),
  atSchool('at_school', 'Na Escola'),
  toHome('to_home', 'A caminho de Casa'),
  atHome('at_home', 'Em Casa');

  final String value;
  final String label;

  const StudentStatus(this.value, this.label);

  static StudentStatus fromValue(String? value) {
    return StudentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => StudentStatus.waitingVan,
    );
  }
}

/// Períodos de rota do dia
enum RoutePeriod {
  morningOutbound('morning_outbound', 'Manhã - Ida Escola'),
  morningReturn('morning_return', 'Manhã - Volta Casa'),
  afternoonOutbound('afternoon_outbound', 'Tarde - Ida Escola'),
  afternoonReturn('afternoon_return', 'Tarde - Volta Casa');

  final String value;
  final String label;

  const RoutePeriod(this.value, this.label);

  static RoutePeriod fromValue(String? value) {
    return RoutePeriod.values.firstWhere(
      (period) => period.value == value,
      orElse: () => RoutePeriod.morningOutbound,
    );
  }

  bool get isOutbound =>
      this == RoutePeriod.morningOutbound ||
      this == RoutePeriod.afternoonOutbound;

  bool get isReturn =>
      this == RoutePeriod.morningReturn || this == RoutePeriod.afternoonReturn;
}

/// Roles de usuário no sistema
enum UserRole {
  guardian('responsavel', 'Responsável'),
  driver('motorista', 'Motorista'),
  admin('admin', 'Administrador');

  final String value;
  final String label;

  const UserRole(this.value, this.label);

  static UserRole fromValue(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.guardian,
    );
  }
}

/// Status de aprovação de escola
enum SchoolApprovalStatus {
  pending('pending', 'Pendente'),
  approved('approved', 'Aprovada'),
  rejected('rejected', 'Rejeitada');

  final String value;
  final String label;

  const SchoolApprovalStatus(this.value, this.label);

  static SchoolApprovalStatus fromValue(String? value) {
    return SchoolApprovalStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SchoolApprovalStatus.pending,
    );
  }
}

/// Status da rota do dia
enum RouteDayStatus {
  planned('planned', 'Planejada'),
  inProgress('in_progress', 'Em Andamento'),
  completed('completed', 'Concluída'),
  cancelled('cancelled', 'Cancelada');

  final String value;
  final String label;

  const RouteDayStatus(this.value, this.label);

  static RouteDayStatus fromValue(String? value) {
    return RouteDayStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => RouteDayStatus.planned,
    );
  }
}

/// Status de solicitação de conversa
enum TalkRequestStatus {
  pending('pending', 'Pendente'),
  acknowledged('acknowledged', 'Reconhecida'),
  resolved('resolved', 'Resolvida');

  final String value;
  final String label;

  const TalkRequestStatus(this.value, this.label);

  static TalkRequestStatus fromValue(String? value) {
    return TalkRequestStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TalkRequestStatus.pending,
    );
  }
}
