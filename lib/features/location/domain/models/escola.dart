class Escola {
  final int id;
  final String nome;
  final int? bairroId;
  final String? bairroNome;

  Escola({required this.id, required this.nome, this.bairroId, this.bairroNome});

  factory Escola.fromJson(Map<String, dynamic> json) {
    return Escola(
      id: json['id'] as int,
      nome: json['nome'] as String,
      bairroId: json['bairro_id'] as int?,
      bairroNome: json['bairro_nome'] as String?,
    );
  }
}
