// lib/view/pharmacy/pharmacy_search_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Para ClientException
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // Para abrir chamadas telefônicas

// Imports locais
import '../../models/unidade.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../product/product_search_screen.dart';

class PharmacySearchScreen extends StatefulWidget {
  const PharmacySearchScreen({super.key});
  @override
  _PharmacySearchScreenState createState() => _PharmacySearchScreenState();
}

class _PharmacySearchScreenState extends State<PharmacySearchScreen> {
  List<Unidade> _fetchedUnidades = [];
  List<Unidade> _filteredUnidades = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;
  Set<int> _linkedUnitIds = {};
  bool _linkedUnitsLoaded = false;
  ApiService? _apiService;
  SharedPreferences? _prefs;

  bool _isCheckingVouchers = false;
  bool _isLinking = false;
  bool _isUnlinking = false;
  int? _actionUnitId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _linkedUnitsLoaded = false;
    });
    try {
      _prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _apiService = ApiService(baseUrl: apiBaseUrl, sharedPreferences: _prefs!);
      await _loadLinkedUnitIds();
      await _fetchUnidades();
    } catch (e) {
      print("Erro crítico ao inicializar PharmacySearchScreen: $e");
      if (mounted) {
        setState(() => _errorMessage = "Erro crítico na inicialização: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLinkedUnitIds() async {
    if (!mounted) return;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (!mounted) return;
      final String? unitsString = _prefs?.getString('user_linked_units');
      Set<int> ids = {};
      if (unitsString != null && unitsString.isNotEmpty) {
        ids = unitsString
            .split(',')
            .map((idStr) => int.tryParse(idStr.trim()))
            .where((id) => id != null)
            .cast<int>()
            .toSet();
      }
      if (mounted) setState(() => _linkedUnitIds = ids);
      if (kDebugMode) {
        print("[PharmacySearch] Linked Unit IDs loaded: $_linkedUnitIds");
      }
    } catch (e) {
      print("Erro ao ler/processar user_linked_units: $e");
      if (mounted) setState(() => _linkedUnitIds = {});
    } finally {
      if (mounted) setState(() => _linkedUnitsLoaded = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _fetchUnidades() async {
    if (_apiService == null) {
      if (mounted) setState(() => _errorMessage = "Serviço API indisponível.");
      return;
    }
    if (!mounted) return;

    bool isInitialLoad = _fetchedUnidades.isEmpty && _errorMessage == null;
    if (!isInitialLoad) {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    }

    try {
      final response = await _apiService!.get('/api/farmacias');
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> decodedJson = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _fetchedUnidades =
                decodedJson.map((json) => Unidade.fromJson(json)).toList();
            _filterUnits();
            _errorMessage = null;
          });
        }
      } else {
        String errorMsg = "Erro ao buscar farmácias (${response.statusCode})";
        try {
          errorMsg = jsonDecode(response.body)['message'] ?? errorMsg;
        } catch (_) {}
        if (mounted) setState(() => _errorMessage = errorMsg);
      }
    } catch (e) {
      print("Erro na busca de farmácias: $e");
      if (mounted) {
        setState(
            () => _errorMessage = "Erro de comunicação ao buscar farmácias.");
      }
    } finally {
      if (mounted && (isInitialLoad || _isLoading)) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterUnits([String? _]) {
    final lowerCaseQueryName = _nameController.text.trim().toLowerCase();
    final lowerCaseQueryCity = _cityController.text.trim().toLowerCase();
    if (mounted) {
      setState(() {
        _filteredUnidades = _fetchedUnidades.where((unidade) {
          bool matchesName = lowerCaseQueryName.isEmpty ||
              unidade.name.toLowerCase().contains(lowerCaseQueryName);
          bool matchesCity = lowerCaseQueryCity.isEmpty ||
              unidade.city.toLowerCase().contains(lowerCaseQueryCity);
          return matchesName && matchesCity;
        }).toList();
      });
    }
  }

  void _clearFilters() {
    FocusScope.of(context).unfocus();
    _nameController.clear();
    _cityController.clear();
    _filterUnits();
    if (_errorMessage != null && mounted) {
      setState(() => _errorMessage = null);
    }
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
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: kAccentBlue.withOpacity(0.7), width: 1.5)),
      suffixIcon: label == 'Nome da Farmácia' && _nameController.text.isNotEmpty
          ? IconButton(
              icon: Icon(Icons.clear, color: kMediumGrey),
              onPressed: () {
                _nameController.clear();
                _filterUnits();
              })
          : (label == 'Cidade' && _cityController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: kMediumGrey),
                  onPressed: () {
                    _cityController.clear();
                    _filterUnits();
                  })
              : null),
    );
  }

  Future<void> _saveLinkedUnitsToPrefs(String? newUnitIdsString) async {
    _prefs ??= await SharedPreferences.getInstance();
    if (_prefs == null) {
      print(
          "Erro crítico: SharedPreferences nulo em _saveLinkedUnitsToPrefs após tentativa de inicialização");
      return;
    }
    try {
      if (newUnitIdsString != null && newUnitIdsString.isNotEmpty) {
        await _prefs!.setString('user_linked_units', newUnitIdsString);
        if (kDebugMode) {
          print("[Prefs] Nova string de unidades salva: $newUnitIdsString");
        }
      } else {
        await _prefs!.remove('user_linked_units');
        if (kDebugMode) print("[Prefs] Chave user_linked_units removida.");
      }
    } catch (e) {
      print("Erro ao salvar user_linked_units no SharedPreferences: $e");
    }
  }

  Future<void> _initiateUnlinkProcess(Unidade unidade) async {
    if (_apiService == null ||
        !_linkedUnitIds.contains(unidade.id) ||
        _isCheckingVouchers ||
        _isLinking ||
        _isUnlinking ||
        !mounted) return;

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    setState(() {
      _isCheckingVouchers = true;
      _actionUnitId = unidade.id;
    });
    try {
      if (kDebugMode) {
        print(
            "[PharmacySearch] Verificando vouchers para UnitID ${unidade.id}");
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
              "[PharmacySearch] Resposta Verificação: hasPending=$hasPending, count=$pendingCount");
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
            "[PharmacySearch] Chamando API para desvincular UnitID ${unidade.id}");
      }
      final response = await _apiService!.unlinkUnit(unidade.id);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        final responseData = jsonDecode(response.body);
        final String? newLinkedUnitsString = responseData['linkedUnits'];
        await _saveLinkedUnitsToPrefs(newLinkedUnitsString);
        await _loadLinkedUnitIds();

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

  Future<void> _linkUnit(Unidade unidade) async {
    if (_apiService == null ||
        _isLinking ||
        _isCheckingVouchers ||
        _isUnlinking ||
        !mounted) return;

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    setState(() {
      _isLinking = true;
      _actionUnitId = unidade.id;
    });
    try {
      if (kDebugMode) {
        print(
            "[PharmacySearch] Chamando API para vincular UnitID ${unidade.id}");
      }
      final response = await _apiService!
          .post('/api/profile/me/units/${unidade.id}', body: jsonEncode({}));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String? newLinkedUnitsString = responseData['linkedUnits'];
        await _saveLinkedUnitsToPrefs(newLinkedUnitsString);
        await _loadLinkedUnitIds();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Vinculado a ${unidade.name} com sucesso.'),
              backgroundColor: Colors.green));
        }
      } else {
        String errorMsg = "Falha ao vincular (${response.statusCode})";
        try {
          errorMsg = jsonDecode(response.body)['message'] ?? errorMsg;
        } catch (_) {}
        _showErrorDialog("Erro ao Vincular", errorMsg);
      }
    } catch (e) {
      print("Exceção ao vincular: $e");
      if (mounted) {
        _showErrorDialog("Erro ao Vincular", "Falha de comunicação.");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLinking = false;
          if (_actionUnitId == unidade.id) _actionUnitId = null;
        });
      }
    }
  }

  void _showUnlinkConfirmationDialog(Unidade unidade,
      [bool warnAboutPoints = false]) {
    if ((_isCheckingVouchers || _isLinking || _isUnlinking) &&
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
                  child: Text(warningMessage, style: TextStyle(height: 1.4))),
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
            if (_actionUnitId == unidade.id) _actionUnitId = null;
            _isCheckingVouchers = false;
            _isUnlinking = false;
          });
        }
      }
    });
  }

  void _showUnlinkWithWarningDialog(Unidade unidade, int pendingCount,
      [bool alsoWarnAboutPoints = true]) {
    if ((_isCheckingVouchers || _isLinking || _isUnlinking) &&
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
            if (_actionUnitId == unidade.id) _actionUnitId = null;
            _isCheckingVouchers = false;
            _isUnlinking = false;
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

  // **** CORREÇÃO APLICADA AQUI ****
  void _showOptionsBottomSheet(BuildContext context, Unidade unidade) {
    final bool isLinked = _linkedUnitIds.contains(unidade.id);
    final bool isActionInProgress =
        (_isCheckingVouchers || _isLinking || _isUnlinking) &&
            _actionUnitId == unidade.id;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext bc) {
        // Envolve o conteúdo com SafeArea
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            child: Wrap(
              children: <Widget>[
                ListTile(
                    leading:
                        const Icon(Icons.info_outline, color: kPrimaryBlue),
                    title: Text('Detalhes: ${unidade.name}',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${unidade.address}, ${unidade.city}",
                        style: TextStyle(color: kMediumGrey))),
                const Divider(),
                ListTile(
                    leading: const Icon(Icons.shopping_bag_outlined,
                        color: kPrimaryBlue),
                    title: const Text('Ver Produtos desta Unidade'),
                    onTap: () {
                      Navigator.pop(bc);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ProductSearchScreen(
                                    specificUnitId: unidade.id,
                                    unitNameFromArgs: unidade.name,
                                  )));
                    }),
                ListTile(
                  leading: isActionInProgress
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: kPrimaryBlue))
                      : Icon(
                          isLinked
                              ? Icons.link_off_rounded
                              : Icons.add_link_rounded,
                          color: isLinked ? Colors.red.shade600 : kPrimaryBlue),
                  title: Text(isLinked
                      ? 'Desvincular desta Farmácia'
                      : 'Vincular a esta Farmácia'),
                  onTap: isActionInProgress
                      ? null
                      : () {
                          if (isLinked) {
                            _initiateUnlinkProcess(unidade);
                          } else {
                            _linkUnit(unidade);
                          }
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Buscar Farmácias',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: kPrimaryBlue,
          foregroundColor: kWhite),
      backgroundColor: kVeryLightGrey,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchFilters(),
            Expanded(
                child: RefreshIndicator(
              onRefresh: _initializeData,
              color: kPrimaryBlue,
              child: _buildContent(),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFilters() {
    return Container(
      color: kWhite,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: TextField(
                controller: _nameController,
                decoration: _buildInputDecoration(
                    'Nome da Farmácia', Icons.storefront_outlined),
                onChanged: _filterUnits,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                controller: _cityController,
                decoration: _buildInputDecoration(
                    'Cidade', Icons.location_city_outlined),
                onChanged: _filterUnits,
              )),
            ],
          ),
          if (_nameController.text.isNotEmpty ||
              _cityController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextButton.icon(
                icon:
                    Icon(Icons.clear_all_rounded, size: 20, color: kMediumGrey),
                label: Text("Limpar Filtros",
                    style: TextStyle(color: kMediumGrey, fontSize: 13)),
                onPressed: _clearFilters,
                style: TextButton.styleFrom(foregroundColor: kMediumGrey),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: kPrimaryBlue));
    }
    if (_errorMessage != null) {
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
                      Icon(Icons.error_outline,
                          color: Colors.red.shade400, size: 40),
                      const SizedBox(height: 15),
                      Text(_errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: kDarkGrey)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text("Tentar Novamente"),
                          onPressed: _initializeData,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: kDarkGrey,
                              foregroundColor: kWhite))
                    ]),
              ),
            ),
          ),
        );
      });
    }
    if (!_linkedUnitsLoaded) {
      return const Center(
          child: Text("Verificando seus vínculos...",
              style: TextStyle(color: kMediumGrey)));
    }
    if (_filteredUnidades.isEmpty) {
      return LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                    _nameController.text.isEmpty && _cityController.text.isEmpty
                        ? "Nenhuma farmácia encontrada para vincular.\nUse os filtros acima para pesquisar."
                        : "Nenhuma farmácia encontrada para os filtros aplicados.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16, color: kMediumGrey, height: 1.4)),
              ),
            ),
          ),
        );
      });
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 16.0),
      itemCount: _filteredUnidades.length,
      itemBuilder: (context, index) {
        final unidade = _filteredUnidades[index];
        final isLinked = _linkedUnitIds.contains(unidade.id);
        final bool isItemLoading =
            (_isCheckingVouchers || _isLinking || _isUnlinking) &&
                _actionUnitId == unidade.id;

        final ImageProvider? bgImage =
            (unidade.photoUrl != null && unidade.photoUrl!.isNotEmpty)
                ? NetworkImage(unidade.photoUrl!)
                : null;

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
            onTap: () => _showOptionsBottomSheet(context, unidade),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: kLightBlue.withOpacity(0.4),
                    backgroundImage: bgImage,
                    onBackgroundImageError: bgImage != null
                        ? (e, s) {
                            if (kDebugMode)
                              print("Erro Img Unidade ${unidade.id}: $e");
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
                          _buildInfoRow(
                              Icons.phone_outlined, displayPhone, kAccentBlue,
                              onTap: () {
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
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isItemLoading
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: kPrimaryBlue),
                            )
                          : Tooltip(
                              message: isLinked ? 'Opções' : 'Vincular',
                              child: IconButton(
                                icon: Icon(
                                  isLinked
                                      ? Icons.link_rounded
                                      : Icons.add_link_rounded,
                                  color: isLinked ? kSuccessGreen : kAccentBlue,
                                  size: 28,
                                ),
                                onPressed: () =>
                                    _showOptionsBottomSheet(context, unidade),
                              ),
                            ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
