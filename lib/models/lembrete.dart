// lib/models/lembrete.dart
import 'package:intl/intl.dart';

class Lembrete {
  final int id;
  final String mensagem;
  final DateTime proximaOcorrencia; // A API envia como DateTime
  final String cicloDescricao;
  final String duracaoDescricao;
  final String status; // "Ativo" ou "Inativo/Concluído"
  final String? nomeUnidade;
  final DateTime dataCriacao;
  final bool enviaPush; // Se o app deve tentar gerar notificação local
  final int? vendaId;

  Lembrete({
    required this.id,
    required this.mensagem,
    required this.proximaOcorrencia,
    required this.cicloDescricao,
    required this.duracaoDescricao,
    required this.status,
    this.nomeUnidade,
    required this.dataCriacao,
    required this.enviaPush,
    this.vendaId,
  });

  factory Lembrete.fromJson(Map<String, dynamic> json) {
    return Lembrete(
      id: json['id'] as int? ?? 0,
      mensagem: json['mensagem'] as String? ?? 'Lembrete sem mensagem',
      proximaOcorrencia:
          DateTime.tryParse(json['proximaOcorrencia'] ?? '') ?? DateTime.now(),
      cicloDescricao: json['cicloDescricao'] as String? ?? 'Não especificado',
      duracaoDescricao:
          json['duracaoDescricao'] as String? ?? 'Não especificada',
      status: json['status'] as String? ?? 'Desconhecido',
      nomeUnidade: json['nomeUnidade'] as String?,
      dataCriacao:
          DateTime.tryParse(json['dataCriacao'] ?? '') ?? DateTime.now(),
      enviaPush: json['enviaPush'] as bool? ?? false,
      vendaId: json['vendaId'] as int?,
    );
  }

  String get formattedProximaOcorrencia {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(proximaOcorrencia.toLocal());
    } catch (e) {
      return "Data Inválida";
    }
  }

  String get formattedDataCriacao {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(dataCriacao.toLocal());
    } catch (e) {
      return "Data Inválida";
    }
  }

  bool get isAtivo {
    return status.toLowerCase() == 'ativo';
  }
}
