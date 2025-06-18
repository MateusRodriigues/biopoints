// lib/view/pharmacy/my_units_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Para kDebugMode
import 'package:url_launcher/url_launcher.dart';

// Imports locais
import '../../models/unidade.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../product/product_search_screen.dart';
import 'pharmacy_search_screen.dart'; // Importar a tela de busca de todas as farmácias

class MyUnitsScreen extends StatefulWidget {
  const MyUnitsScreen({super.key});

  @override
  State<MyUnitsScreen> createState() => _MyUnitsScreenState();
}

class _MyUnitsScreenState extends State<MyUnitsScreen> {
  ApiService? _apiService;
  SharedPreferences? _prefs;
  List<Unidade> _myUnits = [];
  bool _isLoading = true;
  String? _errorMessage;

  bool _isCheckingVouchers = false;
  bool _isUnlinking = false;
  int? _actionUnitId;

  @override
  void initState() {
    super.initState();
    _initializeAndFetchUnits();
  }

  Future<void> _initializeAndFetchUnits() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isCheckingVouchers = false;
      _isUnlinking = false;
      _actionUnitId = null;
    });
    try {
      _prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _apiService = ApiService(baseUrl: apiBaseUrl, sharedPreferences: _prefs!);
      await _fetchMyUnits();
    } catch (e) {
      print("Erro ao inicializar MyUnitsScreen: $e");
      if (mounted) {
        setState(() => _errorMessage = "Erro ao inicializar a tela.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMyUnits() async {
    if (_apiService == null) {
      if (mounted) setState(() => _errorMessage = "Serviço API indisponível.");
      return;
    }
    if (!mounted) return;

    bool isInitialLoad = _myUnits.isEmpty && _errorMessage == null;
    if (!isInitialLoad) {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    }

    try {
      final response = await _apiService!.get('/api/Units/my-linked');
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> decodedJson = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _myUnits =
                decodedJson.map((json) => Unidade.fromJson(json)).toList();
            _errorMessage = null;
          });
          if (kDebugMode) {
            print(
                "[MyUnitsScreen] ${_myUnits.length} unidades vinculadas carregadas.");
          }
        }
      } else {
        String msg = "Erro ao buscar suas unidades (${response.statusCode})";
        try {
          msg = jsonDecode(response.body)['message'] ?? msg;
        } catch (_) {}
        if (mounted) setState(() => _errorMessage = msg);
      }
    } catch (e) {
      print("Erro ao buscar minhas unidades: $e");
      if (mounted) {
        setState(
            () => _errorMessage = "Erro de comunicação ao buscar unidades.");
      }
    } finally {
      if (mounted && (isInitialLoad || _isLoading)) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _initiateUnlinkProcess(Unidade unidade) async {
    if (_apiService == null ||
        _isCheckingVouchers ||
        _isUnlinking ||
        !mounted) {
      return;
    }

    setState(() {
      _isCheckingVouchers = true;
      _actionUnitId = unidade.id;
    });

    try {
      if (kDebugMode) {
        print("[MyUnitsScreen] Verificando vouchers para UnitID ${unidade.id}");
      }
      final response = await _apiService!.checkPendingVouchers(unidade.id);

      if (!mounted) return;

      if (mounted) {
        setState(() {
          _isCheckingVouchers = false;
        });
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool hasPending = data['hasPendingVouchers'] ?? false;
        final int pendingCount = data['pendingCount'] ?? 0;
        if (kDebugMode) {
          print(
              "[MyUnitsScreen] Resposta Verificação: hasPending=$hasPending, count=$pendingCount");
        }

        if (!mounted) return;
        if (hasPending) {
          _showUnlinkWithWarningDialog(unidade, pendingCount, true);
        } else {
          _showUnlinkConfirmationDialog(unidade, true);
        }
      } else {
        String errorMsg =
            "Não foi possível verificar vouchers (${response.statusCode}).";
        try {
          errorMsg = jsonDecode(response.body)['message'] ?? errorMsg;
        } catch (_) {}
        if (mounted) {
          setState(() {
            if (_actionUnitId == unidade.id) _actionUnitId = null;
          });
        }
        _showErrorDialog("Erro na Verificação", errorMsg);
      }
    } catch (e) {
      print("Exceção ao verificar vouchers: $e");
      if (mounted) {
        setState(() {
          if (_actionUnitId == unidade.id) _actionUnitId = null;
          _isCheckingVouchers = false;
        });
        _showErrorDialog("Erro na Verificação", "Falha de comunicação.");
      }
    }
  }

  Future<void> _performUnlink(Unidade unidade) async {
    if (_apiService == null || _isUnlinking || !mounted) return;

    setState(() {
      _isUnlinking = true;
      _actionUnitId = unidade.id;
    });

    try {
      if (kDebugMode) {
        print(
            "[MyUnitsScreen] Chamando API para desvincular UnitID ${unidade.id}");
      }
      final response = await _apiService!.unlinkUnit(unidade.id);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (kDebugMode) print("[MyUnitsScreen] Desvínculo API OK.");

        final responseData = jsonDecode(response.body);
        final String? newLinkedUnitsString = responseData['linkedUnits'];
        await _prefs?.setString(
            'user_linked_units', newLinkedUnitsString ?? '');
        if (kDebugMode) print("[MyUnitsScreen] SharedPreferences atualizado.");

        await _fetchMyUnits();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Desvinculado de ${unidade.name} com sucesso. Vouchers e pontos da unidade foram cancelados/invalidados.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ));
        }
      } else {
        String errorMsg = "Falha ao desvincular (${response.statusCode})";
        try {
          errorMsg = jsonDecode(response.body)['message'] ?? errorMsg;
        } catch (_) {}
        _showErrorDialog("Erro ao Desvincular", errorMsg);
      }
    } catch (e) {
      print("Exceção ao desvincular: $e");
      if (mounted) {
        _showErrorDialog("Erro ao Desvincular", "Falha de comunicação.");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUnlinking = false;
          if (_actionUnitId == unidade.id) _actionUnitId = null;
        });
      }
    }
  }

  void _showUnlinkConfirmationDialog(Unidade unidade,
      [bool warnAboutPoints = false]) {
    if ((_isCheckingVouchers || _isUnlinking) &&
        _actionUnitId == unidade.id &&
        _actionUnitId != null) return;

    String warningMessage =
        "Tem certeza que deseja desvincular da farmácia ${unidade.name}?";
    if (warnAboutPoints) {
      warningMessage +=
          "\n\nTodos os seus pontos BioPoints adquiridos nesta unidade serão perdidos permanentemente e não poderão ser recuperados.";
    }

    showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
              title: const Text("Confirmar Desvínculo"),
              content: SingleChildScrollView(
                  child: Text(warningMessage,
                      style: const TextStyle(height: 1.4))),
              actions: <Widget>[
                TextButton(
                    child: const Text("Cancelar"),
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    style: TextButton.styleFrom(foregroundColor: kMediumGrey)),
                ElevatedButton(
                    child: const Text("Confirmar"),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryBlue, foregroundColor: kWhite))
              ],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0)));
        }).then((confirmed) {
      if (confirmed == true) {
        _performUnlink(unidade);
      } else {
        if (mounted) {
          setState(() {
            if (_actionUnitId == unidade.id) {
              _actionUnitId = null;
              _isCheckingVouchers = false;
              _isUnlinking = false;
            }
          });
        }
      }
    });
  }

  void _showUnlinkWithWarningDialog(Unidade unidade, int pendingCount,
      [bool alsoWarnAboutPoints = true]) {
    if ((_isCheckingVouchers || _isUnlinking) &&
        _actionUnitId == unidade.id &&
        _actionUnitId != null) return;

    String mainMessage =
        "Você possui $pendingCount voucher(s) pendente(s) para ${unidade.name}.\n\nAo se desvincular, este(s) voucher(s) será(ão) CANCELADO(S) permanentemente.";
    if (alsoWarnAboutPoints) {
      mainMessage +=
          "\n\nAlém disso, todos os seus pontos BioPoints adquiridos nesta unidade serão PERDIDOS e não poderão ser recuperados.";
    }
    mainMessage += "\n\nDeseja continuar?";

    showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
              title: Row(children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade800),
                const SizedBox(width: 10),
                const Text("Atenção!")
              ]),
              content: SingleChildScrollView(
                  child: Text(mainMessage,
                      style: TextStyle(color: kDarkGrey, height: 1.4))),
              actions: <Widget>[
                TextButton(
                    child: const Text("Cancelar"),
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    style: TextButton.styleFrom(foregroundColor: kMediumGrey)),
                ElevatedButton(
                    child: Text("Sim, Desvincular"),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        foregroundColor: kWhite))
              ],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0)));
        }).then((confirmed) {
      if (confirmed == true) {
        _performUnlink(unidade);
      } else {
        if (mounted) {
          setState(() {
            if (_actionUnitId == unidade.id) {
              _actionUnitId = null;
              _isCheckingVouchers = false;
              _isUnlinking = false;
            }
          });
        }
      }
    });
  }

  void _showErrorDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text(title,
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
              child: Text(content, style: const TextStyle(color: kDarkGrey))),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Ok',
                    style: TextStyle(
                        color: kPrimaryBlue, fontWeight: FontWeight.bold)))
          ]),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll(RegExp(r'\D'), ''),
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Não foi possível realizar a chamada para $phoneNumber')),
          );
        }
        print('Could not launch $launchUri');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao tentar ligar: $e')),
        );
      }
      print('Error launching phone call: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // **** CORREÇÃO APLICADA AQUI ****
    // O Scaffold inteiro é envolvido por um SafeArea
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Minhas Farmácias",
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: kPrimaryBlue,
          foregroundColor: kWhite,
          elevation: 1,
          iconTheme: const IconThemeData(color: kWhite),
        ),
        backgroundColor: kVeryLightGrey,
        body: RefreshIndicator(
          onRefresh: _initializeAndFetchUnits,
          color: kPrimaryBlue,
          child: _buildBody(),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            // Navega para a tela de busca de todas as farmácias
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const PharmacySearchScreen()),
            ).then((_) {
              // Atualiza a lista de unidades vinculadas ao retornar
              _initializeAndFetchUnits();
            });
          },
          label: const Text('Buscar Farmácias'),
          icon: const Icon(Icons.search_rounded),
          backgroundColor: kAccentBlue,
          foregroundColor: kWhite,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: kPrimaryBlue));
    }
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }
    if (_myUnits.isEmpty) {
      return _buildEmptyListWidget();
    }
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: _buildUnitList(),
        ),
      );
    });
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
              onPressed: _initializeAndFetchUnits,
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
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined, color: kMediumGrey, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    "Você não está vinculado a nenhuma unidade.",
                    style: TextStyle(fontSize: 17, color: kMediumGrey),
                    textAlign: TextAlign.center,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Use o botão abaixo para pesquisar e se vincular a farmácias.",
                      style: TextStyle(
                          fontSize: 14, color: kMediumGrey.withOpacity(0.8)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildUnitList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 88.0),
      itemCount: _myUnits.length,
      itemBuilder: (context, index) {
        final unidade = _myUnits[index];
        final ImageProvider? bgImage =
            (unidade.photoUrl != null && unidade.photoUrl!.isNotEmpty)
                ? NetworkImage(unidade.photoUrl!)
                : null;

        final bool isThisUnitLoading = (_isCheckingVouchers || _isUnlinking) &&
            _actionUnitId == unidade.id;

        String? displayPhone = unidade.celular?.isNotEmpty == true
            ? unidade.celular
            : unidade.telefone;

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(16.0),
            onTap: () {
              if (kDebugMode) {
                print("Navegando para Produtos da Unidade ID: ${unidade.id}");
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductSearchScreen(
                      specificUnitId: unidade.id,
                      unitNameFromArgs: unidade.name),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: kLightBlue.withOpacity(0.4),
                        backgroundImage: bgImage,
                        onBackgroundImageError:
                            bgImage != null && bgImage is NetworkImage
                                ? (e, s) {
                                    if (kDebugMode) {
                                      print(
                                          "Erro Img Unidade ${unidade.id} (${(bgImage as NetworkImage).url}): $e");
                                    }
                                  }
                                : null,
                        child: (bgImage == null)
                            ? Icon(Icons.storefront_outlined,
                                size: 30, color: kPrimaryBlue.withOpacity(0.8))
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unidade.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: kDarkGrey),
                            ),
                            const SizedBox(height: 6),
                            _buildInfoRow(
                                Icons.location_on_outlined,
                                "${unidade.address ?? 'Endereço não informado'}, ${unidade.city}",
                                kMediumGrey),
                            if (displayPhone != null &&
                                displayPhone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _buildInfoRow(Icons.phone_outlined, displayPhone,
                                  kAccentBlue, onTap: () {
                                _makePhoneCall(displayPhone);
                              }),
                            ] else ...[
                              const SizedBox(height: 4),
                              _buildInfoRow(
                                  Icons.phone_outlined,
                                  "Telefone não disponível",
                                  kMediumGrey.withOpacity(0.7),
                                  isItalic: true),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isThisUnitLoading)
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: kPrimaryBlue),
                        )
                      else
                        IconButton(
                          icon: Icon(Icons.link_off_rounded,
                              color: Colors.red.shade400, size: 28),
                          tooltip: 'Desvincular de ${unidade.name}',
                          onPressed: () => _initiateUnlinkProcess(unidade),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.shopping_bag_outlined,
                          size: 16, color: kWhite),
                      label: Text("Ver Produtos",
                          style: TextStyle(fontSize: 13, color: kWhite)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductSearchScreen(
                              specificUnitId: unidade.id,
                              unitNameFromArgs: unidade.name,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentBlue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color,
      {VoidCallback? onTap, bool isItalic = false}) {
    Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                color: color,
                fontSize: 13.5,
                height: 1.3,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: content,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: content,
    );
  }
}
