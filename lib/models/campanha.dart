// lib/models/campanha.dart

// Representa os dados de uma campanha como recebidos da API (CampanhaDto)
class Campanha {
  final int id;
  final String? name;
  final String? description;
  final String? observation;
  final String? imageUrl; // URL Completa
  final int partnerId;
  final String? partnerName;

  // Preço em Dinheiro para cada nível
  final double? priceBronze;
  final double? pricePrata;
  final double? priceOuro;

  // Custo em Pontos para Resgate para cada nível
  final int? costPointsBronze;
  final int? costPointsPrata;
  final int? costPointsOuro;

  Campanha({
    required this.id,
    this.name,
    this.description,
    this.observation,
    this.imageUrl,
    required this.partnerId,
    this.partnerName,
    this.priceBronze,
    this.costPointsBronze,
    this.pricePrata,
    this.costPointsPrata,
    this.priceOuro,
    this.costPointsOuro,
  });

  // Factory constructor para criar uma Campanha a partir de um JSON (Map)
  factory Campanha.fromJson(Map<String, dynamic> json) {
    // Funções auxiliares para parse seguro
    double? tryParseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int? tryParseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    return Campanha(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String?,
      description: json['description'] as String?,
      observation: json['observation'] as String?,
      imageUrl: json['imageUrl'] as String?,
      partnerId: json['partnerId'] as int? ?? 0,
      partnerName: json['partnerName'] as String?,
      priceBronze: tryParseDouble(json['priceBronze']),
      costPointsBronze:
          tryParseInt(json['pointsBronze']), // API usa pointsBronze
      pricePrata: tryParseDouble(json['pricePrata']),
      costPointsPrata: tryParseInt(json['pointsPrata']), // API usa pointsPrata
      priceOuro: tryParseDouble(json['priceOuro']),
      costPointsOuro: tryParseInt(json['pointsOuro']), // API usa pointsOuro
    );
  }
}
