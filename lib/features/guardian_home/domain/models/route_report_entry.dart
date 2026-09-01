class RouteReportStudent {
  final String alunoId;
  final String nome;
  final String horarioEmbarque;
  final String horarioEscola;
  final String horarioVolta;
  final String horarioCasa;

  const RouteReportStudent({
    required this.alunoId,
    required this.nome,
    required this.horarioEmbarque,
    required this.horarioEscola,
    required this.horarioVolta,
    required this.horarioCasa,
  });

  factory RouteReportStudent.fromJson(Map<String, dynamic> json) {
    return RouteReportStudent(
      alunoId:          json['aluno_id']?.toString() ?? '',
      nome:             json['nome']?.toString() ?? '',
      horarioEmbarque:  json['horario_embarque']?.toString() ?? '--:--',
      horarioEscola:    json['horario_escola']?.toString() ?? '--:--',
      horarioVolta:     json['horario_volta']?.toString() ?? '--:--',
      horarioCasa:      json['horario_casa']?.toString() ?? '--:--',
    );
  }
}

class RouteReportEntry {
  final String date; // yyyy-MM-dd
  final List<RouteReportStudent> students;

  const RouteReportEntry({required this.date, required this.students});

  factory RouteReportEntry.fromJson(Map<String, dynamic> json) {
    final list = (json['students'] as List<dynamic>? ?? [])
        .map((e) => RouteReportStudent.fromJson(e as Map<String, dynamic>))
        .toList();
    return RouteReportEntry(date: json['date']?.toString() ?? '', students: list);
  }
}
