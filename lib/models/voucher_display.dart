// lib/models/voucher_display.dart (Status Description Atualizado para Expirados)
import 'package:flutter/material.dart'; // Para Color
import 'package:intl/intl.dart'; // Para formatação de data
import '../utils/app_colors.dart'; // Para cores padrão (kPrimaryBlue, etc)

class VoucherDisplay {
  final int
      id; // Usando int aqui, mas API retorna long (vc_id). Dart int suporta 64 bits.
  final String? codigo;
  final DateTime?
      dataValidade; // Data vinda da API (espera-se UTC ou interpretável como local)
  final String? nomeProduto;
  final String? nomeUnidade;
  final int pontosGastos;
  final double? valorProduto; // Preço em dinheiro
  final String?
      status; // '1' Pendente, '2' Usado, '3' Expirado (da API), '4' Cancelado, etc.

  VoucherDisplay({
    required this.id,
    this.codigo,
    this.dataValidade,
    this.nomeProduto,
    this.nomeUnidade,
    required this.pontosGastos,
    this.valorProduto,
    this.status,
  });

  factory VoucherDisplay.fromJson(Map<String, dynamic> json) {
    // Função helper para parse de datas (pode retornar null)
    DateTime? tryParseDateTime(String? dateString) {
      if (dateString == null) return null;
      try {
        // Simplesmente faz o parse. Assume que a API envia no formato correto.
        // O Flutter interpretará como local se não houver info de fuso,
        // ou como UTC se a string indicar (ex: 'Z' no final).
        return DateTime.parse(dateString);
      } catch (e) {
        print("Erro ao parsear data $dateString: $e");
        return null;
      }
    }

    // Função helper para parse de double
    double? tryParseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return VoucherDisplay(
      id: json['id'] as int? ?? 0, // API retorna long, mas Dart int é 64 bits
      codigo: json['codigo'] as String?,
      dataValidade: tryParseDateTime(json['dataValidade'] as String?),
      nomeProduto: json['nomeProduto'] as String?,
      nomeUnidade: json['nomeUnidade'] as String?,
      pontosGastos: json['pontosGastos'] as int? ?? 0,
      valorProduto: tryParseDouble(json['valorProduto']), // Usa helper
      status: json['status'] as String?,
    );
  }

  // Helper para formatar data de validade para exibição
  String get formattedValidityDate {
    if (dataValidade == null) return 'N/A';
    // Converte para fuso local do dispositivo ANTES de formatar
    return DateFormat('dd/MM/yyyy HH:mm').format(dataValidade!.toLocal());
  }

  // --- Helper para obter descrição do status ATUALIZADO ---
  String get statusDescription {
    final now = DateTime.now();
    // Verifica se o voucher está potencialmente expirado pela data
    bool isDateExpired =
        dataValidade != null && dataValidade!.toLocal().isBefore(now);

    // Se o status for '1' (Pendente) E a data já passou, considera "Expirado"
    if (status == '1' && isDateExpired) {
      return 'Expirado';
    }

    // Caso contrário, usa a lógica original baseada no status vindo da API
    switch (status) {
      case '1':
        return 'Pendente';
      case '2':
        return 'Utilizado';
      case '3':
        return 'Expirado'; // Status '3' vindo da API (expirado no backend)
      case '4':
        return 'Cancelado';
      default:
        return status?.isNotEmpty ?? false
            ? 'Status ${status!}'
            : 'Desconhecido';
    }
  }
  // --- FIM DA ATUALIZAÇÃO ---

  // Helper para obter cor do status (Lógica existente já trata visualmente)
  Color get statusColor {
    final now = DateTime.now();
    bool isPotentiallyExpired =
        dataValidade != null && dataValidade!.toLocal().isBefore(now);

    switch (status) {
      case '1': // Pendente
        // Se for pendente mas a data já passou, mostra cor de expirado
        return isPotentiallyExpired ? Colors.orange.shade800 : kPrimaryBlue;
      case '2': // Utilizado
        return Colors.green.shade700;
      case '3': // Expirado (definido pela API)
        return Colors.orange.shade800;
      case '4': // Cancelado
        return Colors.red.shade700;
      default: // Desconhecido ou outro
        // Se for desconhecido mas a data já passou, considera expirado na cor
        return isPotentiallyExpired ? Colors.orange.shade800 : kMediumGrey;
    }
  }
}
