class Estado {
  final int id;
  final String uf;
  final String nome;

  Estado({required this.id, required this.uf, required this.nome});

  factory Estado.fromJson(Map<String, dynamic> json) {
    return Estado(
      id: json['id'] as int,
      uf: json['uf'] as String,
      nome: json['nome'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'uf': uf, 'nome': nome};
}
