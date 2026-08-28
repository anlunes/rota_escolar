class Municipio {
  final int id;
  final String nome;
  final int? ibge;

  Municipio({required this.id, required this.nome, this.ibge});

  factory Municipio.fromJson(Map<String, dynamic> json) {
    return Municipio(
      id: json['id'] as int,
      nome: json['nome'] as String,
      ibge: json['ibge'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'nome': nome, 'ibge': ibge};
}
