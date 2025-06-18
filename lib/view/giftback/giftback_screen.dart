// lib/view/giftback/giftback_screen.dart (Corrigido)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Para kDebugMode

import '../../models/giftback.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';

class GiftbackScreen extends StatefulWidget {
  const GiftbackScreen({super.key});

  @override
  _GiftbackScreenState createState() => _GiftbackScreenState();
}

class _GiftbackScreenState extends State<GiftbackScreen> {
  Future<List<Giftback>>?
      _giftbacksFuture; // Tornar nullable e inicializar depois
  ApiService? _apiService;
  final _currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dateFormatter = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    // A inicialização agora pode ser feita aqui de forma mais segura
    _initializeAndFetchGiftbacks();
  }

  Future<void> _initializeAndFetchGiftbacks() async {
    // Garante que SharedPreferences seja inicializado antes de criar ApiService
    // e que setState só seja chamado se o widget estiver montado.
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      _apiService = ApiService(baseUrl: apiBaseUrl, sharedPreferences: prefs);
      setState(() {
        // Chame setState para atualizar _giftbacksFuture e reconstruir o widget
        _giftbacksFuture = _fetchGiftbacks();
      });
    }
  }

  Future<List<Giftback>> _fetchGiftbacks() async {
    if (_apiService == null) {
      // Tenta reinicializar se _apiService for nulo por algum motivo
      // Isso pode acontecer se _initializeAndFetchGiftbacks não completou ou foi chamado cedo demais.
      // Uma abordagem mais robusta seria garantir que _apiService esteja sempre pronto antes de chamar.
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        _apiService = ApiService(baseUrl: apiBaseUrl, sharedPreferences: prefs);
      } else {
        throw Exception(
            "ApiService não pôde ser inicializado (widget desmontado).");
      }
      if (_apiService == null) {
        // Checagem dupla
        throw Exception(
            "ApiService não inicializado após tentativa de reinicialização.");
      }
    }
    try {
      // O método getMyGiftbacks no ApiService já retorna Future<List<Giftback>>
      // ou lança uma exceção.
      return await _apiService!.getMyGiftbacks();
    } catch (e) {
      // O erro já foi logado no ApiService, aqui apenas relançamos para o FutureBuilder tratar.
      // Ou podemos formatar uma mensagem de erro mais amigável aqui se necessário.
      if (kDebugMode) {
        print("Erro capturado em _fetchGiftbacks (tela): $e");
      }
      throw Exception(
          "Falha ao carregar seus giftbacks. Por favor, tente novamente.");
    }
  }

  Future<void> _refreshGiftbacks() async {
    if (_apiService == null) {
      await _initializeAndFetchGiftbacks(); // Tenta reinicializar se for nulo
      // Não precisa de return aqui, pois _initializeAndFetchGiftbacks já chama setState com o novo future
      return;
    }
    // Se _apiService já existe, apenas busca novamente e atualiza o Future
    if (mounted) {
      setState(() {
        _giftbacksFuture = _fetchGiftbacks();
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDENTE':
        return kWarningOrange;
      case 'UTILIZADO':
        return kSuccessGreen;
      case 'EXPIRADO':
        return kErrorRed;
      default:
        return kMediumGrey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PENDENTE':
        return Icons.hourglass_top_rounded;
      case 'UTILIZADO':
        return Icons.check_circle_outline_rounded;
      case 'EXPIRADO':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Giftbacks',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryBlue,
        foregroundColor: kWhite,
        elevation: 1,
      ),
      body: FutureBuilder<List<Giftback>>(
        future: _giftbacksFuture,
        builder: (context, snapshot) {
          // Adicionada verificação para _giftbacksFuture nulo (estado inicial antes de initState completar)
          if (_giftbacksFuture == null || _apiService == null) {
            return const Center(
                child: CircularProgressIndicator(color: kPrimaryBlue));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: kPrimaryBlue));
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 50),
                    const SizedBox(height: 16),
                    Text(
                      // Exibe o erro do snapshot, que pode ser a exceção lançada por _fetchGiftbacks
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kDarkGrey, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar Novamente'),
                      onPressed: _refreshGiftbacks,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryBlue,
                          foregroundColor: kWhite),
                    )
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard_outlined,
                      size: 70, color: kMediumGrey),
                  const SizedBox(height: 20),
                  Text(
                    'Você não possui giftbacks no momento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: kMediumGrey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar'),
                    onPressed: _refreshGiftbacks,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryBlue, foregroundColor: kWhite),
                  )
                ],
              ),
            );
          }

          final giftbacks = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refreshGiftbacks,
            color: kPrimaryBlue,
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: giftbacks.length,
              itemBuilder: (context, index) {
                final giftback = giftbacks[index];
                final statusColor = _getStatusColor(giftback.status);
                final statusIcon = _getStatusIcon(giftback.status);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      side: BorderSide(
                          color: statusColor.withOpacity(0.5), width: 1)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                giftback.description,
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: kDarkGrey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon,
                                      color: statusColor, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    giftback.status.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.storefront_outlined,
                                color: kMediumGrey, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              giftback.unitName ?? 'Unidade não especificada',
                              style:
                                  TextStyle(fontSize: 13, color: kMediumGrey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                color: kMediumGrey, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Gerado em: ${_dateFormatter.format(giftback.createdAt)}',
                              style:
                                  TextStyle(fontSize: 13, color: kMediumGrey),
                            ),
                          ],
                        ),
                        if (giftback.expiryDate != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.event_busy_outlined,
                                  color: kErrorRed.withOpacity(0.8), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Expira em: ${_dateFormatter.format(giftback.expiryDate!)}',
                                style:
                                    TextStyle(fontSize: 13, color: kMediumGrey),
                              ),
                            ],
                          ),
                        ],
                        if (giftback.voucherCode != null &&
                            giftback.voucherCode!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.sell_outlined,
                                  color: kMediumGrey, size: 16),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Voucher: ${giftback.voucherCode}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: kMediumGrey,
                                      fontStyle: FontStyle.italic),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Divider(height: 24, thickness: 0.5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Valor: ',
                              style: TextStyle(fontSize: 15, color: kDarkGrey),
                            ),
                            Text(
                              _currencyFormatter.format(giftback.value),
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: kPrimaryBlue),
                            ),
                          ],
                        ),
                        if (giftback.status.toUpperCase() == 'PENDENTE' &&
                            (giftback.expiryDate == null ||
                                giftback.expiryDate!.isAfter(DateTime.now())))
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.qr_code_scanner_rounded,
                                    size: 18),
                                label: Text('Usar Giftback'),
                                onPressed: () {
                                  if (kDebugMode) {
                                    print(
                                        "Tentando usar Giftback ID: ${giftback.id}, Código: ${giftback.voucherCode}");
                                  }
                                  _showUseGiftbackDialog(giftback);
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: kAccentBlue,
                                    foregroundColor: kWhite,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8))),
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showUseGiftbackDialog(Giftback giftback) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Usar Giftback: ${giftback.description}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Valor: ${_currencyFormatter.format(giftback.value)}'),
              if (giftback.unitName != null)
                Text('Unidade: ${giftback.unitName}'),
              if (giftback.voucherCode != null &&
                  giftback.voucherCode!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SelectableText('Código: ${giftback.voucherCode}',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                      'Apresente esta tela na unidade para utilizar seu giftback.',
                      style: TextStyle(fontStyle: FontStyle.italic)),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Fechar'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        );
      },
    );
  }
}
