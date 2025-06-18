// lib/models/user_profile.dart (MODIFICADO)
import 'user_unit_details.dart'; // Importa o novo modelo

class UserProfile {
  final int id;
  final String? nome;
  final String? cpf;
  final String? dataNascimento; // Já vem formatado dd/MM/yyyy da API
  final String? celular;
  final String? telefone;
  final String? email;
  final String? endereco;
  final String? avatarUrl; // URL Completa
  final String?
      nomeUnidade; // Pode ser removido se não for mais usado globalmente

  // --- CAMPOS ANTIGOS REMOVIDOS ---
  // final int pontos;
  // final String? nivel;
  // --- FIM CAMPOS REMOVIDOS ---

  // --- NOVO CAMPO PARA DETALHES POR UNIDADE ---
  final List<UserUnitDetails> unitSpecificDetails;
  // --- FIM NOVO CAMPO ---

  UserProfile({
    required this.id,
    this.nome,
    this.cpf,
    this.dataNascimento,
    this.celular,
    this.telefone,
    this.email,
    this.endereco,
    this.avatarUrl,
    this.nomeUnidade, // Mantido por enquanto
    required this.unitSpecificDetails, // Adicionado ao construtor
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    var detailsList = <UserUnitDetails>[];
    if (json['unitSpecificDetails'] != null &&
        json['unitSpecificDetails'] is List) {
      detailsList = (json['unitSpecificDetails'] as List)
          .map((item) => UserUnitDetails.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return UserProfile(
      id: json['id'] as int? ?? 0,
      nome: json['nome'] as String?,
      cpf: json['cpf'] as String?,
      dataNascimento: json['dataNascimento'] as String?,
      celular: json['celular'] as String?,
      telefone: json['telefone'] as String?,
      email: json['email'] as String?,
      endereco: json['endereco'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      nomeUnidade: json['nomeUnidade'] as String?, // Se ainda precisar
      unitSpecificDetails: detailsList, // Parse da lista
    );
  }
}
