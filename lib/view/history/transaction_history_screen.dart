// lib/view/history/transaction_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_history_item.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Para kDebugMode

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  Future<List<TransactionHistoryItem>>? _historyFuture;
  ApiService? _apiService;
  final _currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _initializeApiServiceAndFetchHistory();
  }

  Future<void> _initializeApiServiceAndFetchHistory() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _apiService = ApiService(baseUrl: apiBaseUrl, sharedPreferences: prefs);
      setState(() {
        _historyFuture = _apiService!.getTransactionHistory();
      });
    } catch (e) {
      if (kDebugMode) {
        print("Erro ao inicializar ApiService em TransactionHistoryScreen: $e");
      }
      if (mounted) {
        setState(() {
          _historyFuture = Future.error(
              "Erro ao configurar o serviço. Tente novamente mais tarde.");
        });
      }
    }
  }

  Future<void> _refreshHistory() async {
    if (_apiService == null) {
      await _initializeApiServiceAndFetchHistory();
      return;
    }
    if (mounted) {
      setState(() {
        _historyFuture = _apiService!.getTransactionHistory();
      });
    }
  }

  // Helper para determinar o ícone, cor do ícone e cor de fundo para cada tipo
  Map<String, dynamic> _getTransactionVisuals(TransactionHistoryItem item) {
    IconData iconData;
    Color iconColor;
    Color backgroundColor;
    String title;

    switch (item.type) {
      case "PONTOS GANHOS (COMPRA DIRETA)":
        iconData = Icons.add_shopping_cart_rounded;
        iconColor = Colors.green.shade800;
        backgroundColor = kLightGreen.withOpacity(0.8);
        title = "Pontos Ganhos";
        break;
      case "PONTOS GANHOS (COMPRA C/ VOUCHER)":
        iconData = Icons.receipt_long_rounded;
        iconColor = Colors.green.shade700;
        backgroundColor = kLightGreen.withOpacity(0.7);
        title = "Pontos Ganhos (Compra c/ Voucher)";
        break;
      case "RESGATE DE VOUCHER":
        iconData = Icons.card_giftcard_rounded;
        iconColor = Colors.red.shade700;
        backgroundColor = kLightRed.withOpacity(0.7);
        title = "Resgate de Voucher";
        break;
      case "VOUCHER_UTILIZADO":
        iconData = Icons.check_circle_outline_rounded;
        iconColor = kPrimaryBlue;
        backgroundColor = kLightBlue.withOpacity(0.7);
        title = "Voucher Utilizado";
        break;
      case "PONTOS PERDIDOS (DESVÍNCULO)":
        iconData = Icons.link_off_rounded;
        iconColor = Colors.brown.shade700;
        backgroundColor = Colors.brown.shade100.withOpacity(0.8);
        title = "Pontos Perdidos";
        break;
      case "PONTOS EXPIRADOS":
        iconData = Icons.hourglass_disabled_outlined;
        iconColor = Colors.orange.shade800;
        backgroundColor = Colors.orange.shade100.withOpacity(0.8);
        title = "Pontos Expirados";
        break;
      default:
        iconData = Icons.info_outline_rounded;
        iconColor = kMediumGrey;
        backgroundColor = kLightGrey.withOpacity(0.8);
        title = item.type; // Fallback
    }

    return {
      'icon': iconData,
      'iconColor': iconColor,
      'backgroundColor': backgroundColor,
      'title': title,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extrato de Pontos',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryBlue,
        foregroundColor: kWhite,
        elevation: 1,
        iconTheme: const IconThemeData(color: kWhite),
      ),
      body: FutureBuilder<List<TransactionHistoryItem>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (_apiService == null || _historyFuture == null) {
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
                      'Erro ao carregar o extrato: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kDarkGrey, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar Novamente'),
                      onPressed: _refreshHistory,
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
                  Icon(Icons.history_toggle_off_outlined,
                      size: 70, color: kMediumGrey),
                  const SizedBox(height: 20),
                  const Text(
                    'Nenhuma transação encontrada.',
                    style: TextStyle(fontSize: 18, color: kMediumGrey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar'),
                    onPressed: _refreshHistory,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryBlue, foregroundColor: kWhite),
                  )
                ],
              ),
            );
          }

          final historyItems = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refreshHistory,
            color: kPrimaryBlue,
            child: ListView.separated(
              padding: const EdgeInsets.all(12.0),
              itemCount: historyItems.length,
              itemBuilder: (context, index) {
                final item = historyItems[index];
                final visuals = _getTransactionVisuals(item);
                final pointsColor = item.points == 0 &&
                        item.type != "VOUCHER_UTILIZADO"
                    ? kMediumGrey // Cor neutra para 0 pontos se não for voucher utilizado
                    : (item.points > 0
                        ? Colors.green.shade700
                        : (item.type == "PONTOS EXPIRADOS"
                            ? Colors.orange.shade800
                            : item.type == "PONTOS PERDIDOS (DESVÍNCULO)"
                                ? Colors.brown.shade700
                                : Colors.red.shade700));

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 7.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side:
                          BorderSide(color: Colors.grey.shade200, width: 0.7)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: visuals['backgroundColor'],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(visuals['icon'],
                              color: visuals['iconColor'], size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                visuals['title'],
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: kDarkGrey),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.formattedDate,
                                style:
                                    TextStyle(fontSize: 12, color: kMediumGrey),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.description,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    color: kDarkGrey,
                                    height: 1.3),
                              ),
                              if (item.unitName != null &&
                                  item.unitName!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(Icons.storefront_outlined,
                                        size: 13, color: kMediumGrey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        item.unitName!,
                                        style: TextStyle(
                                            fontSize: 12, color: kMediumGrey),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (item.productName != null &&
                                  item.productName!.isNotEmpty &&
                                  item.isVoucherRelated) ...[
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shopping_bag_outlined,
                                        size: 13, color: kMediumGrey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        "Item: ${item.productName!}",
                                        style: TextStyle(
                                            fontSize: 12, color: kMediumGrey),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (item.voucherCode != null &&
                                  item.voucherCode!.isNotEmpty &&
                                  (item.type ==
                                          "PONTOS GANHOS (COMPRA C/ VOUCHER)" ||
                                      item.type == "RESGATE DE VOUCHER" ||
                                      item.type == "VOUCHER_UTILIZADO")) ...[
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(Icons.sell_outlined,
                                        size: 13, color: kMediumGrey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        "Voucher: ${item.voucherCode!}",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: kMediumGrey,
                                            fontStyle: FontStyle.italic),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            if (item.pointsDisplay
                                .isNotEmpty) // Só mostra se tiver algo para mostrar
                              Text(
                                item.pointsDisplay,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: pointsColor),
                              ),
                            if (item.value != null && item.value! > 0) ...[
                              const SizedBox(height: 6),
                              Text(
                                _currencyFormatter.format(item.value),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: kDarkGrey,
                                    fontWeight: FontWeight.w500),
                              ),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 0),
            ),
          );
        },
      ),
    );
  }
}
