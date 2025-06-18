// lib/models/unidade.dart
class Unidade {
  final int id;
  final String name;
  final String city;
  final String address;
  final String? photoUrl;
  final String? telefone; // Novo campo
  final String? celular; // Novo campo

  Unidade({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    this.photoUrl,
    this.telefone, // Adicionado ao construtor
    this.celular, // Adicionado ao construtor
  });

  factory Unidade.fromJson(Map<String, dynamic> json) {
    return Unidade(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Nome Indisponível',
      city: json['city'] as String? ?? 'Cidade Indisponível',
      address: json['address'] as String? ?? 'Endereço Indisponível',
      photoUrl: json['photoUrl'] as String?,
      telefone: json['telefone'] as String?, // Mapeando o novo campo
      celular: json['celular'] as String?, // Mapeando o novo campo
    );
  }
}
