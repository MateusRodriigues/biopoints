// lib/view/campaigns/campanhas_screen.dart (Corrigido para tratar retorno de List<Campanha>)
import 'package:biopoints/models/user_unit_details.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

import '../../models/campanha.dart';
import '../../models/UserProfile.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';

class CampanhasScreen extends StatefulWidget {
  const CampanhasScreen({super.key});

  @override
  State<CampanhasScreen> createState() => _CampanhasScreenState();
}

class _CampanhasScreenState extends State<CampanhasScreen> {
  ApiService? _apiService;
  SharedPreferences? _prefs;
  List<Campanha> _campanhas = [];
  bool _isLoading = true;
  String? _errorMessage;

  UserProfile? _userProfile;
  bool _isLoadingProfile = true;

  final _currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  bool _isRedeeming = false;
  int? _redeemingCampaignId;

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
      _errorMessage = null;
    });
    try {
      _prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _apiService = ApiService(baseUrl: apiBaseUrl, sharedPreferences: _prefs!);

      await _fetchUserProfile(); // Primeiro carrega o perfil do usuário

      if (mounted && _userProfile != null) {
        // Só busca campanhas se o perfil foi carregado
        await _fetchCampanhas();
      } else if (mounted && _errorMessage == null) {
        // Se o perfil não carregou e não há erro específico, define um erro genérico
        _setErrorMessage(
            "Não foi possível carregar dados do usuário para buscar campanhas.");
      }
    } catch (e) {
      if (kDebugMode)
        print(
            "[CampanhasScreen DEBUG] Erro ao inicializar CampanhasScreen: $e");
      if (mounted) _setErrorMessage("Erro ao carregar dados: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Loading geral da tela
          _isLoadingProfile = false; // Loading específico do perfil
        });
      }
    }
  }

  Future<void> _fetchUserProfile() async {
    if (!mounted || _apiService == null) return;
    if (kDebugMode) print("[CampanhasScreen DEBUG] Fetching user profile...");

    // Não reseta _isLoadingProfile para true aqui se for um refresh silencioso
    // Apenas se for parte da carga inicial em _initializeAndFetchData

    try {
      _userProfile = await _apiService!
          .getUserProfile(); // ApiService agora retorna UserProfile ou lança exceção
      if (mounted) {
        setState(() {
          // O perfil é atualizado, _isLoadingProfile será tratado no finally do _initializeAndFetchData
          if (kDebugMode) {
            print(
                "[CampanhasScreen DEBUG] Perfil carregado: ${_userProfile?.unitSpecificDetails.length} unit details");
          }
        });
      }
    } catch (e) {
      if (kDebugMode)
        print('[CampanhasScreen DEBUG] Exceção ao buscar perfil: $e');
      if (mounted)
        _setErrorMessage(e.toString().replaceFirst("Exception: ", ""));
    }
    // _isLoadingProfile será setado para false no finally de _initializeAndFetchData
  }

  Future<void> _fetchCampanhas() async {
    if (_apiService == null) {
      if (mounted) _setErrorMessage("Serviço API indisponível.");
      return;
    }
    if (!mounted) return;

    // Se não for a carga inicial e já houver um erro, limpe-o
    if (!_isLoading && _errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    // Se não estiver na carga inicial, mas sim num refresh, indica o loading das campanhas
    if (!_isLoading) {
      setState(
          () => _isLoading = true); // Indica loading específico das campanhas
    }

    try {
      // ApiService.getMinhasCampanhas() agora retorna Future<List<Campanha>> ou lança uma exceção
      final List<Campanha> campanhasList =
          await _apiService!.getMinhasCampanhas();
      if (!mounted) return;

      setState(() {
        _campanhas = campanhasList;
        _errorMessage = null; // Limpa erro se sucesso
      });

      if (kDebugMode) {
        print(
            "[CampanhasScreen DEBUG] ${_campanhas.length} campanhas carregadas.");
      }
    } catch (e) {
      if (kDebugMode)
        print("[CampanhasScreen DEBUG] Erro ao buscar campanhas: $e");
      if (mounted)
        _setErrorMessage(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted)
        setState(() => _isLoading = false); // Termina o loading das campanhas
    }
  }

  void _setErrorMessage(String message) {
    if (!mounted) return;
    if (_errorMessage == null || _errorMessage != message) {
      // Evita rebuilds desnecessários se a msg for a mesma
      if (mounted) setState(() => _errorMessage = message);
    }
  }

  int? _getPointsForLevel(Campanha campanha, UserUnitDetails? unitDetails) {
    final level = unitDetails?.level?.toLowerCase();
    // Se unitDetails for nulo ou o nível não for encontrado, padrão para bronze se disponível
    if (level == null) return campanha.costPointsBronze;
    switch (level) {
      case "bronze":
        return campanha.costPointsBronze;
      case "prata":
        return campanha.costPointsPrata;
      case "ouro":
        return campanha.costPointsOuro;
      default:
        return campanha.costPointsBronze; // Fallback para bronze
    }
  }

  double? _getPriceForLevel(Campanha campanha, UserUnitDetails? unitDetails) {
    final level = unitDetails?.level?.toLowerCase();
    if (level == null) return campanha.priceBronze;
    switch (level) {
      case "bronze":
        return campanha.priceBronze;
      case "prata":
        return campanha.pricePrata;
      case "ouro":
        return campanha.priceOuro;
      default:
        return campanha.priceBronze; // Fallback para bronze
    }
  }

  Future<void> _redeemCampaign(Campanha campanha) async {
    if (_apiService == null ||
        _isLoadingProfile ||
        _userProfile == null ||
        _isRedeeming) {
      _showInfoDialog("Aguarde",
          "Não é possível resgatar agora. Verifique seus dados ou aguarde a operação anterior.");
      return;
    }

    // A API de campanha (ParceiroCampanha) tem PcmUnidade, que é o ID da unidade à qual a oferta da campanha se aplica.
    // O modelo Campanha no Flutter não tem um campo pcmUnidade explícito, mas usa partnerId.
    // Assumindo que campanha.partnerId no Flutter corresponde a pcm_id_parceiro da API
    // E que a API no VouchersController.RedeemCampaign usa campanha.PcmUnidade.Value para VcUnidade.
    // É crucial que o `Campanha.fromJson` no Flutter esteja mapeando o `pcmUnidade` da API para um campo no modelo `Campanha` (ex: `unitId` ou similar).
    // Vou assumir que `campanha.partnerId` é, na verdade, o ID da Unidade da Campanha para fins de encontrar os detalhes do usuário.
    // Se o modelo Campanha do Flutter tiver um campo como `campaignUnitId` ou similar, use-o aqui.
    // O DTO CampanhaDto da API tem PartnerId e PartnerName, mas não explicitamente a Unidade da Campanha.
    // O `ParceiroCampanha.cs` (modelo da API) tem `PcmUnidade`. O `CampanhaDto.cs` deveria incluir este `PcmUnidade`.
    // Por ora, o VouchersController da API usa `campaign.PcmUnidade.Value`. O modelo `campanha.dart` PRECISA ter esse campo.
    // Vamos assumir que `campanha.id` é o `CampaignId` e que a API tem a lógica para determinar a `PcmUnidade` correta a partir do `CampaignId`.
    // Para a lógica de pontos do usuário, precisamos da unidade onde o resgate será feito (que é a unidade da campanha).

    // ***** REVISAR ESTA LÓGICA DEPOIS QUE O MODELO Campanha.dart e CampanhaDto.cs FOREM ALINHADOS COM PcmUnidade *****
    // Temporariamente, vamos assumir que a API lida com a unidade ao resgatar, e para verificar os pontos,
    // podemos tentar encontrar uma unidade vinculada que seja "parceira" ou relacionada.
    // Se `campanha.partnerName` for o nome da unidade, podemos usar isso.
    // Se não, esta lógica de pontos pode não ser precisa aqui sem o ID da unidade da campanha.

    UserUnitDetails? unitDetails;
    if (_userProfile!.unitSpecificDetails.isNotEmpty) {
      // Tenta encontrar uma unidade correspondente pelo partnerName se disponível e se fizer sentido.
      // Esta é uma suposição e pode precisar de ajuste dependendo da sua lógica de negócios.
      // O ideal é que a Campanha tenha um `unitId` associado.
      var foundUnit = _userProfile!.unitSpecificDetails.firstWhere(
          (ud) =>
              ud.unitName == campanha.partnerName ||
              ud.unitId ==
                  campanha
                      .partnerId, // Tenta por nome ou ID do parceiro como fallback
          orElse: () => _userProfile!.unitSpecificDetails
              .first // Fallback para a primeira unidade se nenhuma corresponder
          );
      unitDetails = foundUnit;
      if (kDebugMode)
        print(
            "[CampanhasScreen Redeem] Usando detalhes da unidade: ID ${unitDetails.unitId}, Nome: ${unitDetails.unitName} para campanha ${campanha.name}");
    } else {
      _showErrorDialog("Erro",
          "Você não está vinculado a nenhuma unidade para verificar seus pontos.");
      return;
    }

    final requiredPoints = _getPointsForLevel(campanha, unitDetails);

    if (requiredPoints == null || requiredPoints <= 0) {
      _showErrorDialog("Erro",
          "Campanha indisponível para resgate no seu nível (${unitDetails?.level ?? 'N/A'}) ou pontuação inválida.");
      return;
    }

    if ((unitDetails?.points ?? 0) < requiredPoints) {
      _showErrorDialog("Pontos Insuficientes",
          "Você precisa de $requiredPoints pontos na ${campanha.partnerName ?? 'farmácia do parceiro'}, mas tem apenas ${unitDetails?.points ?? 0}.");
      return;
    }

    final bool confirmed = await _showRedeemConfirmationDialog(
            campanha.name ?? 'esta campanha',
            requiredPoints,
            campanha.partnerName) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() {
      _isRedeeming = true;
      _redeemingCampaignId = campanha.id;
    });

    try {
      // O ApiService.redeemCampaignVoucher espera campaignId, selectedLevel, unitId
      // Precisamos do selectedLevel e do unitId correto.
      // A API espera apenas campaignId.
      final response = await _apiService!.redeemCampaignVoucher(
          campanha.id); // A API já foi corrigida para receber apenas CampaignID
      if (!mounted) return;

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final voucherCode = responseData['codigo'] ?? 'N/A';
        _showSuccessDialog("Resgate Concluído!",
            "Voucher para ${campanha.name} gerado!\nCódigo: $voucherCode\n\nVocê pode vê-lo na seção 'Meus Vouchers'.");
        if (mounted) {
          await _fetchUserProfile(); // Recarregar perfil para atualizar pontos
          await _fetchCampanhas(); // Recarregar campanhas (embora não deva mudar, para consistência)
        }
      } else {
        if (kDebugMode) {
          print(
              "[CampanhasScreen DEBUG Redeem Campaign] Erro API: ${response.statusCode} - ${response.body}");
        }
        String errorMsg = "Não foi possível resgatar a campanha.";
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody?['message'] != null) {
            errorMsg = errorBody['message'];
          }
        } catch (_) {}
        _showErrorDialog("Erro no Resgate", errorMsg);
      }
    } catch (e) {
      if (kDebugMode)
        print("[CampanhasScreen DEBUG Redeem Campaign] Exceção: $e");
      if (mounted) {
        _showErrorDialog("Erro no Resgate",
            "Ocorreu um erro de comunicação: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRedeeming = false;
          _redeemingCampaignId = null;
        });
      }
    }
  }

  Future<bool?> _showRedeemConfirmationDialog(
      String campaignName, int pointsCost, String? partnerName) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmar Resgate de Campanha"),
          content: SingleChildScrollView(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 16.0, color: kDarkGrey),
                children: <TextSpan>[
                  const TextSpan(text: 'Deseja realmente resgatar a campanha '),
                  TextSpan(
                      text: campaignName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (partnerName != null && partnerName.isNotEmpty)
                    TextSpan(text: ' de $partnerName'),
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
              style: TextButton.styleFrom(foregroundColor: kMediumGrey),
            ),
            ElevatedButton(
              child: const Text("Confirmar"),
              onPressed: () => Navigator.of(context).pop(true),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        title: Text(title,
            style: TextStyle(
                color: Colors.red.shade700, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
            child: Text(content, style: const TextStyle(color: kDarkGrey))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ok',
                style: TextStyle(
                    color: kPrimaryBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        title: Text(title,
            style: TextStyle(
                color: Colors.green.shade800, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
            child: Text(content, style: const TextStyle(color: kDarkGrey))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ok',
                style: TextStyle(
                    color: kPrimaryBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campanhas dos Parceiros',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryBlue,
        foregroundColor: kWhite,
        elevation: 1,
        iconTheme: const IconThemeData(color: kWhite),
      ),
      backgroundColor: kLightGrey.withOpacity(0.7),
      body: RefreshIndicator(
        onRefresh: _initializeAndFetchData,
        color: kPrimaryBlue,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading || (_isLoadingProfile && _userProfile == null)) {
      // Modificado para considerar _isLoadingProfile
      return const Center(
          child: CircularProgressIndicator(color: kPrimaryBlue));
    }
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }
    if (_campanhas.isEmpty) {
      return _buildEmptyListWidget();
    }
    return _buildCampaignList();
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
                  backgroundColor: kDarkGrey, foregroundColor: kWhite),
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
                Icon(Icons.campaign_outlined, color: kMediumGrey, size: 60),
                const SizedBox(height: 16),
                Text(
                  "Nenhuma campanha ativa encontrada.",
                  style: TextStyle(fontSize: 17, color: kMediumGrey),
                  textAlign: TextAlign.center,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Verifique novamente mais tarde ou vincule-se a mais farmácias/parceiros.",
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

  Widget _buildCampaignList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: _campanhas.length,
      itemBuilder: (context, index) {
        final campanha = _campanhas[index];

        UserUnitDetails? unitDetails;
        if (_userProfile != null &&
            _userProfile!.unitSpecificDetails.isNotEmpty) {
          // Tenta encontrar a unidade específica da campanha.
          // Assume que Campanha tem um campo 'unitId' ou que partnerId pode ser usado para isso.
          // Se Campanha não tiver um ID de unidade explícito, esta lógica pode precisar ser ajustada.
          // Por enquanto, usando partnerId como um placeholder para o ID da unidade da campanha, se aplicável.
          // Ou, se a campanha for global para o parceiro, pode-se pegar a primeira unidade vinculada ao parceiro.
          unitDetails = _userProfile!.unitSpecificDetails.firstWhere(
            (ud) =>
                ud.unitId ==
                campanha
                    .partnerId, // Ajustar se Campanha tiver um campo 'campaignUnitId'
            orElse: () => _userProfile!.unitSpecificDetails.first, // Fallback
          );
        } else {
          // Fallback se não houver detalhes de unidade ou perfil
          unitDetails = UserUnitDetails(unitId: 0, points: 0, level: "Bronze");
        }

        final requiredPoints = _getPointsForLevel(campanha, unitDetails);
        final currentPrice = _getPriceForLevel(campanha, unitDetails);
        final bool canAfford = (unitDetails.points >=
            (requiredPoints ?? double.maxFinite.toInt()));
        final bool isRedeemPossible =
            requiredPoints != null && requiredPoints > 0;

        final bool isThisLoading =
            _isRedeeming && _redeemingCampaignId == campanha.id;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (campanha.imageUrl != null && campanha.imageUrl!.isNotEmpty)
                ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(
                      campanha.imageUrl!,
                      height: 150,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const Center(
                                  heightFactor: 1,
                                  child: SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: kMediumGrey))),
                      errorBuilder: (context, error, stackTrace) => Container(
                          height: 150,
                          color: kLightGrey,
                          child: const Icon(Icons.error_outline,
                              color: kMediumGrey, size: 40)),
                    ))
              else
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: kLightBlue.withOpacity(0.3),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child:
                      const Icon(Icons.campaign, size: 50, color: kPrimaryBlue),
                ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campanha.name ?? "Campanha sem nome",
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kDarkGrey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Oferecido por: ${campanha.partnerName ?? 'Parceiro Desconhecido'} (${unitDetails?.unitName ?? 'Unidade não especificada'})",
                      style: const TextStyle(
                          fontSize: 13,
                          color: kMediumGrey,
                          fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      campanha.description ?? "Sem descrição.",
                      style: const TextStyle(
                          fontSize: 14, color: kDarkGrey, height: 1.4),
                    ),
                    if (campanha.observation != null &&
                        campanha.observation!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Obs: ${campanha.observation}",
                        style: const TextStyle(
                            fontSize: 12,
                            color: kMediumGrey,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                    const Divider(height: 24, thickness: 0.5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (currentPrice != null)
                          _buildDetailItem(
                              Icons.sell_outlined,
                              "Valor",
                              _currencyFormatter.format(currentPrice),
                              Colors.green.shade700),
                        if (requiredPoints != null && requiredPoints > 0)
                          _buildDetailItem(Icons.star_border_rounded, "Custo",
                              "$requiredPoints pts", kPrimaryBlue),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: isThisLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: kWhite))
                            : const Icon(Icons.card_giftcard_outlined,
                                size: 18),
                        label: Text(isThisLoading
                            ? "Processando..."
                            : (isRedeemPossible ? "Resgatar" : "Indisponível")),
                        onPressed:
                            isThisLoading || !isRedeemPossible || !canAfford
                                ? null
                                : () => _redeemCampaign(campanha),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRedeemPossible && canAfford
                              ? kPrimaryBlue
                              : kMediumGrey.withOpacity(0.6),
                          foregroundColor: kWhite,
                          disabledBackgroundColor: kMediumGrey.withOpacity(0.4),
                          disabledForegroundColor: kWhite.withOpacity(0.7),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    if (isRedeemPossible && !canAfford)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            "Pontos insuficientes em ${unitDetails?.unitName ?? 'esta unidade'}",
                            style: TextStyle(
                                color: Colors.red.shade600, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(
      IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text("$label: ",
            style: const TextStyle(fontSize: 14, color: kMediumGrey)),
        Text(value,
            style: const TextStyle(
                fontSize: 14, color: kDarkGrey, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
