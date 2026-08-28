class Bairro {
  final int id;
  final String nome;

  Bairro({required this.id, required this.nome});

  factory Bairro.fromJson(Map<String, dynamic> json) {
    return Bairro(
      id: json['id'] as int,
      nome: json['nome'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'nome': nome};
}
