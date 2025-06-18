// lib/models/transaction_history_item.dart
import 'package:intl/intl.dart';

class TransactionHistoryItem {
  final DateTime date;
  final String
      type; // Ex: "PONTOS GANHOS (COMPRA DIRETA)", "RESGATE DE VOUCHER", etc.
  final String description;
  final String? unitName;
  final int points; // Positivo para ganho, negativo para resgate/perda
  final double? value; // Valor da compra ou do item resgatado
  final String? productName;
  final String? voucherCode;

  TransactionHistoryItem({
    required this.date,
    required this.type,
    required this.description,
    this.unitName,
    required this.points,
    this.value,
    this.productName,
    this.voucherCode,
  });

  factory TransactionHistoryItem.fromJson(Map<String, dynamic> json) {
    return TransactionHistoryItem(
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      type: json['type'] as String? ?? 'DESCONHECIDO',
      description: json['description'] as String? ?? 'N/A',
      unitName: json['unitName'] as String?,
      points: json['points'] as int? ?? 0,
      value: (json['value'] as num?)?.toDouble(),
      productName: json['productName'] as String?,
      voucherCode: json['voucherCode'] as String?,
    );
  }

  String get formattedDate {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
    } catch (e) {
      // Fallback em caso de data inválida, embora tryParse no factory deva prevenir isso.
      return "Data Inválida";
    }
  }

  String get pointsDisplay {
    if (type == "VOUCHER_UTILIZADO") {
      // Para "VOUCHER_UTILIZADO", os pontos são 0 por definição do evento
      return ""; // Não mostrar "+0 pontos" ou "0 pontos"
    }
    if (points == 0) {
      return "0 pts"; // Caso algum outro tipo de transação tenha 0 pontos
    }
    return points > 0 ? '+${points} pts' : '${points} pts';
  }

  // Getters para facilitar a identificação do tipo de transação na UI
  bool get isPointGain {
    return type == "PONTOS GANHOS (COMPRA DIRETA)" ||
        type == "PONTOS GANHOS (COMPRA C/ VOUCHER)";
  }

  bool get isPointLoss {
    return type == "RESGATE DE VOUCHER" ||
        type == "PONTOS PERDIDOS (DESVÍNCULO)" ||
        type == "PONTOS EXPIRADOS";
  }

  bool get isVoucherRelated {
    // Para resgates e usos
    return type == "RESGATE DE VOUCHER" ||
        type == "VOUCHER_UTILIZADO" ||
        type == "PONTOS GANHOS (COMPRA C/ VOUCHER)";
  }
}
