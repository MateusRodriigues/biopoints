// lib/models/produto.dart (Arquivo Completo Corrigido)

// Representa os dados de um produto como recebidos da API (ProdutoDto)
class Produto {
  final int id;
  final String? name;
  final String? description;
  final String? observation;
  final String? imageUrl; // URL Completa
  final int unitId;
  final String? unitName; // Nome da Unidade/Farmácia

  // --- NOMES CORRIGIDOS ---
  // Preço em Dinheiro para cada nível
  final double? priceBronze;
  final double? pricePrata;
  final double? priceOuro;

  // Custo em Pontos para Resgate para cada nível
  final int? costPointsBronze; // <- Renomeado de pointsBronze
  final int? costPointsPrata; // <- Renomeado de pointsPrata
  final int? costPointsOuro; // <- Renomeado de pointsOuro
  // --- FIM NOMES CORRIGIDOS ---

  Produto({
    required this.id,
    this.name,
    this.description,
    this.observation,
    this.imageUrl,
    required this.unitId,
    this.unitName, // Adicionado ao construtor
    // Construtor atualizado com nomes corrigidos
    this.priceBronze,
    this.costPointsBronze, // <- Atualizado
    this.pricePrata,
    this.costPointsPrata, // <- Atualizado
    this.priceOuro,
    this.costPointsOuro, // <- Atualizado
  });

  // Factory constructor para criar um Produto a partir de um JSON (Map)
  factory Produto.fromJson(Map<String, dynamic> json) {
    // Função auxiliar para tentar fazer parse de double (preços)
    double? tryParseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    // Função auxiliar para tentar fazer parse de int (pontos)
    int? tryParseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    return Produto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String?,
      description: json['description'] as String?,
      observation: json['observation'] as String?,
      imageUrl: json['imageUrl'] as String?,
      unitId: json['unitId'] as int? ?? 0,
      unitName: json['unitName'] as String?, // Mapeia o nome da unidade
      // Mapeamento atualizado com nomes corretos da API
      priceBronze: tryParseDouble(json['priceBronze']),
      costPointsBronze:
          tryParseInt(json['pointsBronze']), // API usa pointsBronze para custo
      pricePrata: tryParseDouble(json['pricePrata']),
      costPointsPrata:
          tryParseInt(json['pointsPrata']), // API usa pointsPrata para custo
      priceOuro: tryParseDouble(json['priceOuro']),
      costPointsOuro:
          tryParseInt(json['pointsOuro']), // API usa pointsOuro para custo
    );
  }
}
