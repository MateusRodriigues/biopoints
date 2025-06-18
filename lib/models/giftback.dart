// lib/models/giftback.dart
// import 'package:intl/intl.dart'; // Se precisar formatar datas

class Giftback {
  final int id;
  final int userId;
  final int?
      unitId; // Pode ser nulo se o giftback não for específico de unidade
  final String? unitName; // Nome da unidade
  final String description;
  final double value;
  final DateTime? expiryDate; // Data de expiração
  final String status; // Ex: "PENDENTE", "UTILIZADO", "EXPIRADO"
  final DateTime createdAt;
  final String? voucherCode; // Código do voucher, se aplicável
  final String? originSaleId; // ID da venda que originou o giftback

  Giftback({
    required this.id,
    required this.userId,
    this.unitId,
    this.unitName,
    required this.description,
    required this.value,
    this.expiryDate,
    required this.status,
    required this.createdAt,
    this.voucherCode,
    this.originSaleId,
  });

  factory Giftback.fromJson(Map<String, dynamic> json) {
    return Giftback(
      id: json['id'] as int? ?? 0,
      userId: json['userId'] as int? ?? 0,
      unitId: json['unitId'] as int?,
      unitName: json['unitName'] as String?,
      description: json['description'] as String? ?? 'Giftback',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      expiryDate: json['expiryDate'] == null
          ? null
          : DateTime.tryParse(json['expiryDate'] as String),
      status: json['status'] as String? ?? 'DESCONHECIDO',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      voucherCode: json['voucherCode'] as String?,
      originSaleId: json['originSaleId'] as String?,
    );
  }

  // Exemplo de getter formatado para data (se necessário)
  // String get formattedExpiryDate {
  //   if (expiryDate == null) return 'N/A';
  //   return DateFormat('dd/MM/yyyy').format(expiryDate!);
  // }
}
