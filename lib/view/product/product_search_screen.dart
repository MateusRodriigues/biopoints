// lib/view/product/product_search_screen.dart (Refatorado para condicional explícita no build)
import 'package:biopoints/models/user_unit_details.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../models/produto.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../models/UserProfile.dart';

class ProductSearchScreen extends StatefulWidget {
  final int? specificUnitId;
  final String? unitNameFromArgs;

  const ProductSearchScreen(
      {super.key, this.specificUnitId, this.unitNameFromArgs});

  @override
  _ProductSearchScreenState createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  ApiService? _apiService;
  SharedPreferences? _prefs;
  bool _isLoading = true;
  String? _errorMessage;
  List<Produto> _products = [];
  List<Produto> _filteredProducts = [];
  final TextEditingController _searchController = TextEditingController();
  final _currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  UserProfile? _userProfile;
  bool _isLoadingProfile = true;
  bool _isRedeeming = false;
  int? _redeemingProductId;

  Set<String> _favoriteProductIds = {};
  bool _favoritesLoaded = false;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeAndFetchData();
  }

  Future<void> _initializeAndFetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isLoadingProfile = true;
      _favoritesLoaded = false;
      _errorMessage = null;
      _currentUserId = null;
    });
    try {
      _prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      _currentUserId = _prefs!.getInt('user_id');
      if (_currentUserId == null) {
        if (mounted) {
          setState(() {
            _errorMessage =
                "Erro: Usuário não identificado para carregar favoritos e produtos.";
            _isLoading = false;
            _isLoadingProfile = false;
            _favoritesLoaded = true;
          });
        }
        return;
      }
      if (kDebugMode) print("[ProductSearch] Current User ID: $_currentUserId");

      _apiService = ApiService(baseUrl: apiBaseUrl, sharedPreferences: _prefs!);
      if (!mounted) return;

      await _fetchUserProfile();

      if (mounted && _userProfile != null) {
        await Future.wait([
          _loadFavorites(),
        ]);
        await _fetchProducts(unitId: widget.specificUnitId);
      } else if (mounted && _errorMessage == null) {
        _setErrorMessage(
            "Não foi possível carregar os dados do perfil do usuário.");
      }
    } catch (e) {
      print("Erro init ProductSearch: $e");
      if (mounted) {
        setState(() => _errorMessage = "Erro ao inicializar: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingProfile = false;
          _favoritesLoaded = true;
        });
      }
    }
  }

  Future<void> _loadFavorites() async {
    if (_prefs == null || _currentUserId == null) {
      print("[ProductSearch _loadFavorites] Erro: Prefs ou UserID nulos.");
      if (mounted) setState(() => _favoriteProductIds = {});
      return;
    }
    try {
      final String userFavoritesKey = 'favorite_products_$_currentUserId';
      final List<String>? favoriteIds = _prefs!.getStringList(userFavoritesKey);
      if (mounted) {
        setState(() {
          _favoriteProductIds = favoriteIds?.toSet() ?? {};
        });
        if (kDebugMode) {
          print(
              "[ProductSearch _loadFavorites] Favoritos para User $_currentUserId carregados: $_favoriteProductIds");
        }
      }
    } catch (e) {
      print("Erro ao carregar favoritos para User $_currentUserId: $e");
      if (mounted) setState(() => _favoriteProductIds = {});
    }
  }

  Future<void> _toggleFavorite(int productId) async {
    if (_prefs == null || _currentUserId == null) {
      _showErrorDialog("Erro",
          "Não foi possível salvar o favorito (usuário não identificado).");
      return;
    }
    final productIdStr = productId.toString();
    final isCurrentlyFavorite = _favoriteProductIds.contains(productIdStr);
    final previousFavoriteIds = Set<String>.from(_favoriteProductIds);

    setState(() {
      if (isCurrentlyFavorite) {
        _favoriteProductIds.remove(productIdStr);
      } else {
        _favoriteProductIds.add(productIdStr);
      }
    });

    try {
      final String userFavoritesKey = 'favorite_products_$_currentUserId';
      await _prefs!
          .setStringList(userFavoritesKey, _favoriteProductIds.toList());
      if (kDebugMode) {
        print(
            "[ProductSearch _toggleFavorite] Favoritos para User $_currentUserId salvos: $_favoriteProductIds");
      }
    } catch (e) {
      print("Erro ao salvar favoritos para User $_currentUserId: $e");
      setState(() {
        _favoriteProductIds = previousFavoriteIds;
      });
      _showErrorDialog("Erro",
          "Não foi possível ${isCurrentlyFavorite ? 'desfavoritar' : 'favoritar'} o produto.");
    }
  }

  Future<void> _fetchUserProfile() async {
    if (!mounted || _apiService == null) return;
    if (kDebugMode) print("[ProductSearch] Fetching user profile...");
    // _isLoadingProfile é setado por _initializeAndFetchData

    try {
      final response = await _apiService!.get('/api/profile/me');
      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        // Atribuição direta, setState será chamado no finally de _initializeAndFetchData
        _userProfile = UserProfile.fromJson(decodedJson);
        _errorMessage = null;
        if (kDebugMode) {
          print(
              "[ProductSearch] UserProfile loaded: ${_userProfile?.unitSpecificDetails.length} unit details.");
        }
      } else {
        if (kDebugMode) {
          print(
              '[ProductSearch] Error fetching profile: ${response.statusCode} - ${response.body}');
        }
        _setErrorMessage(
            "Erro ao carregar dados do usuário (${response.statusCode}).");
      }
    } catch (e) {
      if (kDebugMode) print('[ProductSearch] Exception fetching profile: $e');
      _setErrorMessage("Erro de comunicação ao carregar perfil.");
    }
    // _isLoadingProfile é setado no finally de _initializeAndFetchData
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts({int? unitId}) async {
    if (_apiService == null) {
      if (mounted) _setErrorMessage("Serviço indisponível.");
      return;
    }
    String endpoint =
        unitId != null ? '/api/products/unit/$unitId' : '/api/products';
    if (kDebugMode) print("[ProductSearch] Fetching products from: $endpoint");
    // _isLoading é setado por _initializeAndFetchData

    try {
      final response = await _apiService!.get(endpoint);
      if (kDebugMode)
        print("[ProductSearch] Products Status: ${response.statusCode}");
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> decodedJson = jsonDecode(response.body);
        // Atribuição direta
        _products = decodedJson.map((json) => Produto.fromJson(json)).toList();
        _filterProducts();
        _errorMessage = null;
      } else {
        String msg = "Erro ao buscar produtos (${response.statusCode})";
        try {
          msg = jsonDecode(response.body)['message'] ?? msg;
        } catch (_) {}
        _setErrorMessage(msg);
      }
    } catch (e) {
      if (kDebugMode) print('[ProductSearch] Exception fetching products: $e');
      _setErrorMessage('Erro de comunicação ao buscar produtos.');
    }
    // _isLoading é setado no finally de _initializeAndFetchData
  }

  void _filterProducts() {
    final query = _searchController.text.trim().toLowerCase();
    if (!mounted) return;
    setState(() {
      _filteredProducts = query.isEmpty
          ? List.from(_products)
          : _products
              .where((p) =>
                  (p.name?.toLowerCase().contains(query) ?? false) ||
                  (p.unitName?.toLowerCase().contains(query) ?? false))
              .toList();
    });
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(color: kMediumGrey, fontSize: 15),
      prefixIcon: Icon(icon, color: kMediumGrey, size: 22),
      filled: true,
      fillColor: kWhite,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: kAccentBlue.withOpacity(0.7), width: 1.5),
      ),
      suffixIcon: _searchController.text.isNotEmpty
          ? IconButton(
              icon: Icon(Icons.clear, color: kMediumGrey, size: 20),
              onPressed: () {
                _searchController.clear();
                _filterProducts();
              })
          : null,
    );
  }

  void _showProductObservationDialog(BuildContext context, Produto product) {
    UserUnitDetails? unitDetails = _userProfile?.unitSpecificDetails.firstWhere(
      (ud) => ud.unitId == product.unitId,
      orElse: () =>
          UserUnitDetails(unitId: product.unitId, points: 0, level: 'Bronze'),
    );
    String currentLevelForProductUnit = unitDetails?.level ?? "Bronze";

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            product.name ?? "Detalhes",
            style: const TextStyle(
                color: kPrimaryBlue, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.unitName != null &&
                    product.unitName!.isNotEmpty) ...[
                  Text(
                    "Unidade: ${product.unitName}",
                    style: TextStyle(
                        color: kDarkGrey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  "Preço e Custo em Pontos (Seu Nível: $currentLevelForProductUnit):",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kDarkGrey,
                      fontSize: 15),
                ),
                const SizedBox(height: 8),
                _buildTierDetailRow(
                    Icons.shield_outlined,
                    Colors.brown.shade400,
                    "Bronze",
                    product.priceBronze,
                    product.costPointsBronze,
                    currentLevelForProductUnit == "Bronze"),
                const SizedBox(height: 5),
                _buildTierDetailRow(
                    Icons.shield_outlined,
                    Colors.grey.shade500,
                    "Prata",
                    product.pricePrata,
                    product.costPointsPrata,
                    currentLevelForProductUnit == "Prata"),
                const SizedBox(height: 5),
                _buildTierDetailRow(
                    Icons.shield_outlined,
                    Colors.amber.shade600,
                    "Ouro",
                    product.priceOuro,
                    product.costPointsOuro,
                    currentLevelForProductUnit == "Ouro"),
                const Divider(height: 24, thickness: 1),
                const Text(
                  "Observações:",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kDarkGrey,
                      fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text(
                  product.observation?.isNotEmpty ?? false
                      ? product.observation!
                      : "Nenhuma observação disponível.",
                  style: const TextStyle(
                      color: kDarkGrey, height: 1.4, fontSize: 14),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Fechar',
                  style: TextStyle(
                      color: kPrimaryBlue, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        );
      },
    );
  }

  Widget _buildTierDetailRow(IconData icon, Color color, String label,
      double? price, int? pointsCost, bool isCurrentUserLevel) {
    String priceStr = price != null ? _currencyFormatter.format(price) : "N/D";
    String pointsStr = pointsCost != null ? "$pointsCost pts" : "N/D";
    return Container(
      padding: EdgeInsets.all(isCurrentUserLevel ? 6 : 4),
      decoration: BoxDecoration(
          color:
              isCurrentUserLevel ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text("$label: ",
              style: TextStyle(
                  fontWeight:
                      isCurrentUserLevel ? FontWeight.bold : FontWeight.w500,
                  color: color,
                  fontSize: 14)),
          Expanded(
              child: Text(priceStr,
                  style: TextStyle(
                      color: kDarkGrey,
                      fontSize: 14,
                      fontWeight: isCurrentUserLevel
                          ? FontWeight.bold
                          : FontWeight.normal),
                  textAlign: TextAlign.start)),
          Text(pointsStr,
              style: TextStyle(
                  color: kDarkGrey,
                  fontSize: 14,
                  fontWeight:
                      isCurrentUserLevel ? FontWeight.bold : FontWeight.normal),
              textAlign: TextAlign.end),
        ],
      ),
    );
  }

  int? _getPointsForLevel(Produto product, UserUnitDetails? unitDetails) {
    final level = unitDetails?.level?.toLowerCase();
    if (level == null) return product.costPointsBronze;
    switch (level) {
      case "bronze":
        return product.costPointsBronze;
      case "prata":
        return product.costPointsPrata;
      case "ouro":
        return product.costPointsOuro;
      default:
        return product.costPointsBronze;
    }
  }

  double? _getPriceForLevel(Produto product, UserUnitDetails? unitDetails) {
    final level = unitDetails?.level?.toLowerCase();
    if (level == null) return product.priceBronze;
    switch (level) {
      case "bronze":
        return product.priceBronze;
      case "prata":
        return product.pricePrata;
      case "ouro":
        return product.priceOuro;
      default:
        return product.priceBronze;
    }
  }

  Future<void> _redeemProduct(Produto product) async {
    if (_userProfile == null) {
      _showErrorDialog("Erro", "Dados do usuário não carregados.");
      return;
    }

    UserUnitDetails? unitDetails = _userProfile!.unitSpecificDetails.firstWhere(
      (ud) => ud.unitId == product.unitId,
      orElse: () {
        if (kDebugMode) {
          print(
              "[RedeemProduct] Detalhes da unidade ${product.unitId} não encontrados no perfil do usuário. Usando fallback.");
        }
        return UserUnitDetails(
            unitId: product.unitId, points: 0, level: "Bronze");
      },
    );

    if (!_userProfile!.unitSpecificDetails
        .any((ud) => ud.unitId == product.unitId)) {
      _showErrorDialog("Não Vinculado",
          "Você precisa ter vínculo ou pontos na farmácia '${product.unitName ?? 'desconhecida'}' para resgatar este produto.");
      return;
    }

    if (_apiService == null || _isLoadingProfile || _isRedeeming) {
      _showErrorDialog("Erro",
          "Não é possível resgatar agora. Verifique seus dados e conexão.");
      return;
    }

    final int availablePointsInUnit = unitDetails.points;
    final requiredPoints = _getPointsForLevel(product, unitDetails);

    if (requiredPoints == null || requiredPoints <= 0) {
      _showErrorDialog("Erro",
          "Produto indisponível para resgate no seu nível (${unitDetails.level}) nesta farmácia ou pontuação inválida.");
      return;
    }
    if (availablePointsInUnit < requiredPoints) {
      _showErrorDialog("Pontos Insuficientes",
          "Você precisa de $requiredPoints pontos na ${product.unitName ?? 'farmácia'}, mas tem apenas $availablePointsInUnit.");
      return;
    }

    final bool confirmed = await _showRedeemConfirmationDialog(
            product.name ?? 'este produto', requiredPoints, product.unitName) ??
        false;

    if (!confirmed || !mounted) return;
    setState(() {
      _isRedeeming = true;
      _redeemingProductId = product.id;
    });

    try {
      final endpoint = '/api/vouchers/redeem';
      final body = jsonEncode({'productId': product.id});
      if (kDebugMode) {
        print("[Redeem] Chamando POST $endpoint com productId=${product.id}");
      }

      final response = await _apiService!.post(endpoint, body: body);

      if (!mounted) return;

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final voucherCode = responseData['codigo'] ?? 'N/A';
        if (kDebugMode) print("[Redeem] Sucesso! Código: $voucherCode");
        _showSuccessDialog("Resgate Concluído!",
            "Voucher para ${product.name} gerado!\nCódigo: $voucherCode\n\nVocê pode vê-lo na seção 'Meus Vouchers'.");
        if (mounted) {
          await _fetchUserProfile();
        }
      } else {
        if (kDebugMode) {
          print("[Redeem] Erro API: ${response.statusCode} - ${response.body}");
        }
        String errorMsg = "Não foi possível resgatar o produto.";
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map && errorBody.containsKey('errors')) {
            final errors = errorBody['errors'] as Map<String, dynamic>;
            if (errors.isNotEmpty) {
              final firstErrorField = errors.values.first;
              if (firstErrorField is List && firstErrorField.isNotEmpty) {
                errorMsg = firstErrorField.first;
              }
            }
          } else if (errorBody?['message'] != null) {
            errorMsg = errorBody['message'];
          }
        } catch (_) {}
        _showErrorDialog("Erro no Resgate", errorMsg);
      }
    } catch (e) {
      if (kDebugMode) print("[Redeem] Exceção: $e");
      if (mounted) {
        _showErrorDialog(
            "Erro no Resgate", "Ocorreu um erro de comunicação: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRedeeming = false;
          _redeemingProductId = null;
        });
      }
    }
  }

  Future<bool?> _showRedeemConfirmationDialog(
      String productName, int pointsCost, String? unitName) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmar Resgate"),
          content: SingleChildScrollView(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 16.0, color: kDarkGrey),
                children: <TextSpan>[
                  const TextSpan(text: 'Deseja realmente resgatar '),
                  TextSpan(
                      text: productName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (unitName != null && unitName.isNotEmpty)
                    TextSpan(text: ' da $unitName'),
                  const TextSpan(text: ' por '),
                  TextSpan(
                      text: '$pointsCost pontos',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: '?'),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              style: TextButton.styleFrom(foregroundColor: kMediumGrey),
            ),
            ElevatedButton(
              child: const Text("Confirmar"),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue,
                foregroundColor: kWhite,
              ),
            ),
          ],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        );
      },
    );
  }

  void _showErrorDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title,
            style: TextStyle(
                color: Colors.red.shade700, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ok',
                style: TextStyle(
                    color: kPrimaryBlue, fontWeight: FontWeight.bold)),
          ),
        ],
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      ),
    );
  }

  void _showSuccessDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title,
            style: TextStyle(
                color: Colors.green.shade800, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ok',
                style: TextStyle(
                    color: kPrimaryBlue, fontWeight: FontWeight.bold)),
          ),
        ],
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      ),
    );
  }

  void _setErrorMessage(String message) {
    if (!mounted) return;
    if (_errorMessage == null || _errorMessage != message) {
      setState(() {
        _errorMessage = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = widget.specificUnitId == null
        ? "Produtos Disponíveis"
        : (widget.unitNameFromArgs ?? "Produtos da Unidade");

    // ---- CORREÇÃO DA LÓGICA CONDICIONAL NO BUILD ----
    Widget profileSectionWidget;
    if (!_isLoadingProfile && _userProfile != null) {
      profileSectionWidget = _buildContextualPointsAndLevelSection();
    } else if (_isLoadingProfile) {
      profileSectionWidget = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: kMediumGrey)),
            SizedBox(width: 8),
            Text("Carregando seus dados...",
                style: TextStyle(color: kMediumGrey, fontSize: 13))
          ],
        ),
      );
    } else {
      // Caso _userProfile seja null e _isLoadingProfile seja false (pode acontecer se _fetchUserProfile falhar)
      profileSectionWidget = SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryBlue,
        foregroundColor: kWhite,
        elevation: 1,
        iconTheme: const IconThemeData(color: kWhite),
      ),
      backgroundColor: kWhite,
      body: SafeArea(
        child: Column(
          children: [
            if (widget.specificUnitId == null)
              Container(
                color: kWhite,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: TextField(
                  controller: _searchController,
                  decoration: _buildInputDecoration(
                      "Nome do Produto ou Farmácia", Icons.search),
                  onChanged: (value) => _filterProducts(),
                ),
              ),
            profileSectionWidget, // Usa a variável do widget aqui
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: kPrimaryBlue))
                  : _errorMessage != null
                      ? _buildErrorWidget()
                      : _buildProductList(),
            ),
          ],
        ),
      ),
    );
  }
  // ---- FIM DA CORREÇÃO ----

  Widget _buildContextualPointsAndLevelSection() {
    UserUnitDetails? relevantUnitDetails;
    String displayText = "Seu Saldo";

    if (widget.specificUnitId != null && _userProfile != null) {
      relevantUnitDetails = _userProfile!.unitSpecificDetails.firstWhere(
        (ud) => ud.unitId == widget.specificUnitId,
        orElse: () => UserUnitDetails(
            unitId: widget.specificUnitId!, points: 0, level: "Bronze"),
      );
      displayText =
          "Saldo em: ${widget.unitNameFromArgs ?? relevantUnitDetails.unitName ?? 'Unidade'}";
    } else {
      return SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: kLightBlue.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kAccentBlue.withOpacity(0.3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(displayText,
                style: TextStyle(
                    color: kDarkGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.workspace_premium_outlined,
                    color: kPrimaryBlue, size: 18),
                SizedBox(width: 6),
                Text("Nível: ",
                    style: TextStyle(color: kDarkGrey, fontSize: 14)),
                Text(relevantUnitDetails.level ?? "N/A",
                    style: TextStyle(
                        color: kPrimaryBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                SizedBox(width: 16),
                Icon(Icons.monetization_on_outlined,
                    color: kPrimaryBlue, size: 18),
                SizedBox(width: 6),
                Text("Pontos: ",
                    style: TextStyle(color: kDarkGrey, fontSize: 14)),
                Text(relevantUnitDetails.points.toString(),
                    style: TextStyle(
                        color: kPrimaryBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kDarkGrey, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("Tentar Novamente"),
              onPressed: _initializeAndFetchData,
              style: ElevatedButton.styleFrom(
                  backgroundColor: kDarkGrey,
                  foregroundColor: kWhite,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyListWidget() {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, color: kMediumGrey, size: 60),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    _searchController.text.isEmpty
                        ? (widget.specificUnitId == null
                            ? "Nenhum produto disponível nas suas unidades vinculadas."
                            : "Nenhum produto encontrado para ${widget.unitNameFromArgs ?? 'esta unidade'}.")
                        : "Nenhum produto encontrado para \"${_searchController.text}\"",
                    style: TextStyle(fontSize: 17, color: kMediumGrey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildProductList() {
    if (!_favoritesLoaded || _userProfile == null) {
      return const Center(child: CircularProgressIndicator(color: kMediumGrey));
    }
    if (_filteredProducts.isEmpty) {
      return _buildEmptyListWidget();
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final Produto product = _filteredProducts[index];

        UserUnitDetails? unitDetails =
            _userProfile!.unitSpecificDetails.firstWhere(
          (ud) => ud.unitId == product.unitId,
          orElse: () => UserUnitDetails(
              unitId: product.unitId, points: 0, level: "Bronze"),
        );

        final requiredPoints = _getPointsForLevel(product, unitDetails);
        final currentPrice = _getPriceForLevel(product, unitDetails);

        final bool hasEnoughPointsInUnit =
            unitDetails.points >= (requiredPoints ?? 9999999);
        final bool canRedeem = !_isLoadingProfile &&
            hasEnoughPointsInUnit &&
            (requiredPoints != null && requiredPoints > 0);

        final bool isItemLoading =
            _isRedeeming && _redeemingProductId == product.id;
        final bool isFavorite =
            _favoriteProductIds.contains(product.id.toString());

        Widget buildValueRow(
            IconData icon, String label, String value, Color color) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 13, color: kMediumGrey)),
              SizedBox(width: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      color: kDarkGrey,
                      fontWeight: FontWeight.w500)),
              SizedBox(width: 10),
            ],
          );
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 1.5,
          shadowColor: Colors.grey.withOpacity(0.3),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _showProductObservationDialog(context, product),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Container(
                          width: 80,
                          height: 80,
                          color: kLightGrey,
                          child: product.imageUrl != null &&
                                  product.imageUrl!.isNotEmpty
                              ? Image.network(
                                  product.imageUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                        child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2.0,
                                                color: kMediumGrey)));
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    if (kDebugMode) {
                                      print(
                                          "Erro NetworkImage produto ${product.id}: $error");
                                    }
                                    return const Icon(
                                        Icons.broken_image_outlined,
                                        size: 30,
                                        color: kMediumGrey);
                                  },
                                )
                              : const Icon(Icons.image_not_supported_outlined,
                                  size: 30, color: kMediumGrey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name ?? "Produto sem nome",
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: kDarkGrey),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            if (product.unitName != null &&
                                product.unitName!.isNotEmpty)
                              Text(
                                product.unitName!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: kAccentBlue,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 5),
                            Text(product.description ?? "",
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: kMediumGrey,
                                    height: 1.3),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6.0,
                              runSpacing: 4.0,
                              children: [
                                if (currentPrice != null)
                                  buildValueRow(
                                      Icons.sell_outlined,
                                      "Preço:",
                                      _currencyFormatter.format(currentPrice),
                                      Colors.green.shade700),
                                if (requiredPoints != null &&
                                    requiredPoints > 0)
                                  buildValueRow(Icons.star_outline, "Custo:",
                                      "$requiredPoints pts", kPrimaryBlue),
                              ],
                            )
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.redAccent : kMediumGrey,
                        ),
                        tooltip: isFavorite ? 'Desfavoritar' : 'Favoritar',
                        onPressed: () => _toggleFavorite(product.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: isItemLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: kWhite))
                          : Icon(Icons.card_giftcard_outlined, size: 18),
                      label: Text(isItemLoading
                          ? "Resgatando..."
                          : (requiredPoints == null || requiredPoints <= 0)
                              ? "Indisponível"
                              : "Resgatar ($requiredPoints pts)"),
                      onPressed: isItemLoading || !canRedeem
                          ? null
                          : () => _redeemProduct(product),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canRedeem
                            ? kPrimaryBlue
                            : kMediumGrey.withOpacity(0.6),
                        foregroundColor: kWhite,
                        disabledBackgroundColor: kMediumGrey.withOpacity(0.4),
                        disabledForegroundColor: kWhite.withOpacity(0.7),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: canRedeem && !isItemLoading ? 2 : 0,
                      ),
                    ),
                  ),
                  // Chamada ao widget helper
                  _buildInsufficientPointsMessage(isItemLoading, requiredPoints,
                      hasEnoughPointsInUnit, product, unitDetails),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Widget helper para a mensagem de "Pontos insuficientes"
  Widget _buildInsufficientPointsMessage(
      bool isItemLoading,
      int? requiredPoints,
      bool hasEnoughPointsInUnit,
      Produto product,
      UserUnitDetails unitDetails) {
    if (!isItemLoading &&
        (requiredPoints != null && requiredPoints > 0) &&
        !hasEnoughPointsInUnit) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            "Pontos insuficientes em ${product.unitName ?? 'esta farmácia'} (${unitDetails.points} de $requiredPoints)",
            style: TextStyle(color: Colors.red.shade600, fontSize: 11),
          ),
        ),
      );
    }
    return SizedBox.shrink();
  }
}
