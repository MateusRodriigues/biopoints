// lib/view/favorites/favorites_screen.dart (Corrigido: _favoritesLoaded e _showProductObservationDialog adicionados)
import 'package:biopoints/models/user_unit_details.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../models/produto.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../models/UserProfile.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  ApiService? _apiService;
  SharedPreferences? _prefs;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  List<Produto> _allProducts = [];
  List<Produto> _favoriteProducts = [];
  Set<String> _favoriteProductIds = {};

  UserProfile? _userProfile;

  bool _isLoadingProfile = true;
  bool _isRedeeming = false;
  int? _redeemingProductId;

  final _currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  final Key _visibilityKey = const Key('favoritesScreenVisibilityKey');
  bool _isCurrentlyVisible = false;
  int? _currentUserId;

  // Variável de estado que estava faltando
  bool _favoritesLoaded = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) print("[FavoritesScreen initState]");
    _fetchAllDataFirstTime();
  }

  Future<void> _fetchAllDataFirstTime({bool isRefresh = false}) async {
    if (!mounted) return;
    if (kDebugMode) {
      print("[FavoritesScreen] Fetching ALL data (isRefresh: $isRefresh)...");
    }

    setState(() {
      if (!isRefresh)
        _isLoading = true;
      else
        _isRefreshing = true;
      _isLoadingProfile = true;
      _favoritesLoaded = false; // Reseta ao buscar dados
      _errorMessage = null;
      _currentUserId = null;
    });

    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (!mounted) return;

      _currentUserId = _prefs!.getInt('user_id');
      if (_currentUserId == null) {
        throw Exception("ID do usuário não encontrado no SharedPreferences.");
      }
      if (kDebugMode) {
        print("[FavoritesScreen] Current User ID: $_currentUserId");
      }

      _apiService ??=
          ApiService(baseUrl: apiBaseUrl, sharedPreferences: _prefs!);
      if (!mounted) return;

      await _fetchUserProfile();

      if (mounted && _userProfile != null) {
        await Future.wait([
          _loadFavorites(),
          _fetchAllProducts(),
        ]);
      } else if (mounted && _errorMessage == null) {
        _setErrorMessage(
            "Não foi possível carregar dados do usuário para exibir favoritos.");
      }

      if (mounted && _errorMessage == null) {
        if (kDebugMode) {
          print("[FavoritesScreen] Filtering after ALL data fetch...");
        }
        _filterFavoriteProducts();
      } else if (mounted) {
        if (kDebugMode) {
          print(
              "[FavoritesScreen] Skipping filter due to error: $_errorMessage");
        }
      }
    } catch (e) {
      print("Erro em _fetchAllDataFirstTime: $e");
      if (mounted) {
        setState(
            () => _errorMessage = "Erro ao carregar dados: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _isLoadingProfile = false;
          _favoritesLoaded = true; // Marca favoritos como carregados no final
          if (kDebugMode) {
            print(
                "[FavoritesScreen] ALL data fetch finished. Loading: $_isLoading, FavLoaded: $_favoritesLoaded");
          }
        });
      }
    }
  }

  Future<void> _reloadFavoritesAndRefilter() async {
    if (!mounted || _isLoading || _isRefreshing || _currentUserId == null)
      return;
    if (kDebugMode) {
      print(
          "[FavoritesScreen _reloadFavoritesAndRefilter] Reloading favorite IDs for User $_currentUserId and filtering...");
    }
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (!mounted) return;

      final previousFavIds = Set<String>.from(_favoriteProductIds);

      await _loadFavorites();
      await _fetchUserProfile(); // Recarrega perfil para consistência de pontos/nível

      if (mounted &&
          (!setEquals(_favoriteProductIds, previousFavIds) ||
              _userProfile != null)) {
        if (_userProfile != null && _allProducts.isNotEmpty)
          _filterFavoriteProducts();
        if (kDebugMode) {
          print(
              "[FavoritesScreen _reloadFavoritesAndRefilter] Favorites or profile changed, list updated.");
        }
      } else if (mounted) {
        if (kDebugMode) {
          print(
              "[FavoritesScreen _reloadFavoritesAndRefilter] No changes in favorites detected.");
        }
      }
    } catch (e) {
      print("Error reloading/filtering favorites: $e");
      if (mounted) _setErrorMessage("Erro ao atualizar lista de favoritos.");
    }
  }

  Future<void> _loadFavorites() async {
    if (_prefs == null || _currentUserId == null) {
      print("[FavoritesScreen _loadFavorites] Erro: Prefs ou UserID nulos.");
      _favoriteProductIds = {};
      return;
    }
    try {
      final String userFavoritesKey = 'favorite_products_$_currentUserId';
      final List<String>? favoriteIds = _prefs!.getStringList(userFavoritesKey);
      if (kDebugMode) {
        print(
            "[FavoritesScreen _loadFavorites] IDs lidos de SharedPreferences (Key: $userFavoritesKey): $favoriteIds");
      }
      // Não chama setState aqui diretamente se for parte do Future.wait
      _favoriteProductIds = favoriteIds?.toSet() ?? {};
      if (kDebugMode) {
        print(
            "[FavoritesScreen _loadFavorites] _favoriteProductIds updated to: $_favoriteProductIds");
      }
    } catch (e) {
      print("Erro ao carregar favoritos para User $_currentUserId: $e");
      if (mounted)
        _favoriteProductIds = {}; // Garante que não seja nulo em caso de erro
    }
    // _favoritesLoaded é setado no finally de _fetchAllDataFirstTime ou _initializeAndFetchData
  }

  Future<void> _toggleFavorite(int productId) async {
    if (_prefs == null || _currentUserId == null) {
      _showErrorDialog("Erro",
          "Não foi possível salvar a alteração (usuário não identificado).");
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
      _filterFavoriteProducts();
    });
    if (kDebugMode) {
      print(
          "[FavoritesScreen _toggleFavorite] Toggled $productIdStr locally. New set: $_favoriteProductIds");
    }

    try {
      final String userFavoritesKey = 'favorite_products_$_currentUserId';
      await _prefs!
          .setStringList(userFavoritesKey, _favoriteProductIds.toList());
      if (kDebugMode) {
        print(
            "[FavoritesScreen _toggleFavorite] Saved updated favorites for User $_currentUserId to SharedPreferences.");
      }
    } catch (e) {
      print("Erro ao salvar favoritos para User $_currentUserId: $e");
      setState(() {
        _favoriteProductIds = previousFavoriteIds;
        _filterFavoriteProducts();
      });
      _showErrorDialog("Erro",
          "Não foi possível ${isCurrentlyFavorite ? 'desfavoritar' : 'favoritar'} o produto.");
    }
  }

  void _filterFavoriteProducts() {
    if (!mounted || _userProfile == null) return;
    if (kDebugMode) {
      print(
          "[FavoritesScreen _filterFavoriteProducts] Filtering... Favorite IDs: $_favoriteProductIds, All Product IDs: ${_allProducts.map((p) => p.id).toList()}");
    }

    final List<Produto> filtered = _allProducts.where((product) {
      bool isFav = _favoriteProductIds.contains(product.id.toString());
      return isFav;
    }).toList();

    if (!listEquals(_favoriteProducts, filtered)) {
      if (mounted) {
        setState(() {
          _favoriteProducts = filtered;
        });
      }
      if (kDebugMode) {
        print(
            "[FavoritesScreen _filterFavoriteProducts] Filtered list updated. Count: ${_favoriteProducts.length}, IDs: ${_favoriteProducts.map((p) => p.id).toList()}");
      }
    } else {
      if (kDebugMode) {
        print(
            "[FavoritesScreen _filterFavoriteProducts] Filtered list is the same. No UI update needed.");
      }
    }
  }

  Future<void> _fetchAllProducts() async {
    if (_apiService == null) {
      if (mounted) _setErrorMessage("Serviço indisponível.");
      return;
    }
    try {
      final response = await _apiService!.get('/api/products');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> decodedJson = jsonDecode(response.body);
        // Não chama setState aqui diretamente
        _allProducts =
            decodedJson.map((json) => Produto.fromJson(json)).toList();
        if (kDebugMode) {
          print(
              "[FavoritesScreen _fetchAllProducts] ${_allProducts.length} products fetched. IDs: ${_allProducts.map((p) => p.id).toList()}");
        }
      } else {
        String msg = "Erro ao buscar produtos (${response.statusCode})";
        try {
          msg = jsonDecode(response.body)['message'] ?? msg;
        } catch (_) {}
        _setErrorMessage(msg);
        if (kDebugMode) {
          print(
              "[FavoritesScreen _fetchAllProducts] Error ${response.statusCode}: $msg");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[FavoritesScreen _fetchAllProducts] Exception: $e');
      }
      _setErrorMessage('Erro de comunicação ao buscar produtos.');
    }
  }

  Future<void> _fetchUserProfile() async {
    if (!mounted || _apiService == null) return;
    if (kDebugMode) print("[FavoritesScreen] Fetching user profile...");
    // Não seta _isLoadingProfile aqui se for parte de _fetchAllDataFirstTime
    try {
      final response = await _apiService!.get('/api/profile/me');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        // Não chama setState aqui diretamente
        _userProfile = UserProfile.fromJson(decodedJson);
        if (kDebugMode) {
          print(
              "[FavoritesScreen _fetchUserProfile] Profile loaded: ${_userProfile?.unitSpecificDetails.length} unit details.");
        }
      } else {
        _setErrorMessage(
            "Erro ao carregar dados do usuário (${response.statusCode}).");
        if (kDebugMode) {
          print(
              "[FavoritesScreen _fetchUserProfile] Error ${response.statusCode}");
        }
      }
    } catch (e) {
      _setErrorMessage("Erro ao carregar dados do usuário.");
      if (kDebugMode) {
        print("[FavoritesScreen _fetchUserProfile] Exception: $e");
      }
    }
    // _isLoadingProfile é setado no finally de _fetchAllDataFirstTime
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
      _showErrorDialog("Erro", "Dados do usuário não carregados para resgate.");
      return;
    }

    UserUnitDetails? unitDetails = _userProfile!.unitSpecificDetails.firstWhere(
      (ud) => ud.unitId == product.unitId,
      orElse: () {
        if (kDebugMode) {
          print(
              "[FavoritesScreen Redeem] Detalhes da unidade ${product.unitId} não encontrados. Usando fallback.");
        }
        return UserUnitDetails(
            unitId: product.unitId, points: 0, level: "Bronze");
      },
    );

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
          "Você precisa de $requiredPoints pontos na ${product.unitName ?? 'farmácia do produto'}, mas tem apenas $availablePointsInUnit.");
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
      final response = await _apiService!.post(endpoint, body: body);

      if (!mounted) return;

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final voucherCode = responseData['codigo'] ?? 'N/A';
        _showSuccessDialog("Resgate Concluído!",
            "Voucher para ${product.name} gerado!\nCódigo: $voucherCode\n\nVocê pode vê-lo na seção 'Meus Vouchers'.");
        if (mounted) {
          await _fetchUserProfile(); // Recarrega o perfil para atualizar pontos
        }
      } else {
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
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(foregroundColor: kMediumGrey)),
            ElevatedButton(
                child: const Text("Confirmar"),
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue, foregroundColor: kWhite)),
          ],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        );
      },
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
                      color: kPrimaryBlue, fontWeight: FontWeight.bold)))
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
                      color: kPrimaryBlue, fontWeight: FontWeight.bold)))
        ],
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      ),
    );
  }

  // Método _showProductObservationDialog (copiado de product_search_screen.dart)
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
                    // Chamada ao helper
                    Icons.shield_outlined,
                    Colors.brown.shade400,
                    "Bronze",
                    product.priceBronze,
                    product.costPointsBronze,
                    currentLevelForProductUnit == "Bronze"),
                const SizedBox(height: 5),
                _buildTierDetailRow(
                    // Chamada ao helper
                    Icons.shield_outlined,
                    Colors.grey.shade500,
                    "Prata",
                    product.pricePrata,
                    product.costPointsPrata,
                    currentLevelForProductUnit == "Prata"),
                const SizedBox(height: 5),
                _buildTierDetailRow(
                    // Chamada ao helper
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

  // Método _buildTierDetailRow (copiado de product_search_screen.dart)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos Favoritos',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryBlue,
        foregroundColor: kWhite,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: kWhite,
      body: VisibilityDetector(
        key: _visibilityKey,
        onVisibilityChanged: (visibilityInfo) {
          final visiblePercentage = visibilityInfo.visibleFraction * 100;
          final bool becameVisible =
              visiblePercentage > 80 && !_isCurrentlyVisible;
          _isCurrentlyVisible = visiblePercentage > 80;

          if (becameVisible && !_isLoading && !_isLoadingProfile) {
            if (kDebugMode) {
              print(
                  "[FavoritesScreen VisibilityDetector] Screen became visible. Reloading favorites and profile...");
            }
            _reloadFavoritesAndRefilter();
          }
        },
        child: RefreshIndicator(
          onRefresh: () => _fetchAllDataFirstTime(isRefresh: true),
          color: kPrimaryBlue,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading || (_isLoadingProfile && _userProfile == null)) {
      return const Center(
          child: CircularProgressIndicator(color: kPrimaryBlue));
    }
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }
    if (!_favoritesLoaded) {
      // Checa se favoritos foram carregados
      return const Center(
          child: Text("Carregando favoritos...",
              style: TextStyle(color: kMediumGrey)));
    }
    if (_favoriteProducts.isEmpty) {
      return _buildEmptyListWidget();
    }
    return _buildFavoriteProductList();
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
              onPressed: () => _fetchAllDataFirstTime(isRefresh: true),
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
                Icon(Icons.favorite_outline, color: kMediumGrey, size: 60),
                const SizedBox(height: 16),
                Text(
                  "Você ainda não favoritou nenhum produto.",
                  style: TextStyle(fontSize: 17, color: kMediumGrey),
                  textAlign: TextAlign.center,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Marque produtos como favoritos na tela de Produtos.",
                    style: TextStyle(
                        fontSize: 14, color: kMediumGrey.withOpacity(0.8)),
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

  Widget _buildFavoriteProductList() {
    if (_userProfile == null) {
      return Center(
          child: Text("Carregando dados do usuário...",
              style: TextStyle(color: kMediumGrey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: _favoriteProducts.length,
      itemBuilder: (context, index) {
        final Produto product = _favoriteProducts[index];

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
                                  loadingBuilder: (context, child,
                                          loadingProgress) =>
                                      loadingProgress == null
                                          ? child
                                          : Center(
                                              child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2.0,
                                                          color: kMediumGrey))),
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image_outlined,
                                          size: 30, color: kMediumGrey),
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
                        icon: Icon(Icons.favorite, color: Colors.redAccent),
                        tooltip: 'Desfavoritar',
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
                            borderRadius: BorderRadius.circular(8)),
                        elevation: canRedeem && !isItemLoading ? 2 : 0,
                      ),
                    ),
                  ),
                  if (!isItemLoading &&
                      (requiredPoints != null && requiredPoints > 0) &&
                      !hasEnoughPointsInUnit)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "Pontos insuficientes em ${product.unitName ?? 'esta farmácia'} (${unitDetails.points} de $requiredPoints)",
                          style: TextStyle(
                              color: Colors.red.shade600, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
