// lib/view/voucher/voucher_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

import '../../models/voucher_display.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  ApiService? _apiService;
  SharedPreferences? _prefs;
  List<VoucherDisplay> _vouchers = [];
  bool _isLoading = true;
  String? _errorMessage;

  final _currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeAndFetchVouchers();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeAndFetchVouchers() async {
    if (!mounted) return;
    _timer?.cancel();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _apiService = ApiService(baseUrl: apiBaseUrl, sharedPreferences: _prefs!);
      await _fetchVouchers();

      if (mounted && _errorMessage == null) {
        _startTimer();
      }
    } catch (e) {
      print("Erro ao inicializar VoucherScreen: $e");
      if (mounted) setState(() => _errorMessage = "Erro ao inicializar.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchVouchers() async {
    if (_apiService == null) {
      if (mounted) setState(() => _errorMessage = "Serviço indisponível.");
      return;
    }
    if (!mounted) return;

    try {
      final response = await _apiService!.get('/api/vouchers/my');
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> decodedJson = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _vouchers = decodedJson
                .map((json) => VoucherDisplay.fromJson(json))
                .toList();
            _errorMessage = null;
          });
          if (kDebugMode && _vouchers.isNotEmpty) {
            final firstVoucher = _vouchers.firstWhere(
                (v) => v.status == '1' && v.dataValidade != null,
                orElse: () => _vouchers.first);
            if (firstVoucher.dataValidade != null) {
              final initialDifference =
                  firstVoucher.dataValidade!.difference(DateTime.now());
              print(
                  "[VoucherScreen Fetch] Primeira dataValidade lida: ${firstVoucher.dataValidade}, Diferença Inicial: ${initialDifference}, Horas: ${initialDifference.inHours}");
            }
          }
        }
      } else {
        String msg = "Erro ${response.statusCode}";
        try {
          msg = jsonDecode(response.body)['message'] ?? msg;
        } catch (_) {}
        if (mounted) setState(() => _errorMessage = msg);
      }
    } catch (e) {
      print("Erro ao buscar vouchers: $e");
      if (mounted)
        setState(
            () => _errorMessage = "Erro de comunicação ao buscar vouchers.");
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) {
        setState(() {});
      } else {
        t.cancel();
      }
    });
  }

  String _getFormattedRemainingTime(DateTime? expiryDate) {
    if (expiryDate == null) return "--:--:--";
    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    if (difference.isNegative) {
      return "Expirado";
    }

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(difference.inHours);
    final minutes = twoDigits(difference.inMinutes.remainder(60));
    final seconds = twoDigits(difference.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  bool _isExpiringSoon(DateTime? expiryDate) {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final difference = expiryDate.difference(now);
    return !difference.isNegative && difference < const Duration(hours: 12);
  }

  @override
  Widget build(BuildContext context) {
    // **** CORREÇÃO APLICADA AQUI ****
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Meus Vouchers",
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: kPrimaryBlue,
          foregroundColor: kWhite,
          elevation: 1,
          iconTheme: const IconThemeData(color: kWhite),
        ),
        backgroundColor: kLightGrey.withOpacity(0.7),
        body: RefreshIndicator(
          onRefresh: _initializeAndFetchVouchers,
          color: kPrimaryBlue,
          child: _buildBody(),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _isLoading ? null : _initializeAndFetchVouchers,
          tooltip: 'Atualizar Vouchers',
          backgroundColor: kPrimaryBlue,
          child: _isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child:
                      CircularProgressIndicator(color: kWhite, strokeWidth: 3))
              : const Icon(Icons.refresh, color: kWhite),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _vouchers.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: kPrimaryBlue));
    }
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }
    if (_vouchers.isEmpty) {
      return _buildEmptyListWidget();
    }
    return _buildVoucherList();
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
              onPressed: _initializeAndFetchVouchers,
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
                Icon(Icons.card_giftcard_outlined,
                    color: kMediumGrey, size: 60),
                const SizedBox(height: 16),
                Text(
                  "Você ainda não possui vouchers.",
                  style: TextStyle(fontSize: 17, color: kMediumGrey),
                  textAlign: TextAlign.center,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Resgate produtos para gerar vouchers!",
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

  Widget _buildVoucherList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: _vouchers.length,
      itemBuilder: (context, index) {
        final voucher = _vouchers[index];
        final bool isPending = voucher.status == '1';
        final String remainingTimeDisplay = isPending
            ? _getFormattedRemainingTime(voucher.dataValidade)
            : voucher.statusDescription;
        final bool expiringSoon = isPending &&
            _isExpiringSoon(voucher.dataValidade) &&
            remainingTimeDisplay != "Expirado";

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300, width: 0.5)),
          elevation: 1.5,
          shadowColor: Colors.grey.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            voucher.codigo ?? 'ERRO_CODIGO',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryBlue,
                                letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            voucher.nomeProduto ?? 'Produto Indisponível',
                            style: const TextStyle(
                                fontSize: 15,
                                color: kDarkGrey,
                                fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            voucher.nomeUnidade ?? 'Unidade Indisponível',
                            style: const TextStyle(
                                fontSize: 12, color: kMediumGrey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: voucher.statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        voucher.statusDescription.toUpperCase(),
                        style: TextStyle(
                            color: voucher.statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, thickness: 0.5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailItemInline(
                        Icons.paid_outlined,
                        "Valor",
                        voucher.valorProduto != null
                            ? _currencyFormatter.format(voucher.valorProduto!)
                            : 'N/A'),
                    _buildDetailItemInline(Icons.star_outline, "Custo",
                        "${voucher.pontosGastos} pts"),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                        isPending && remainingTimeDisplay != "Expirado"
                            ? (expiringSoon
                                ? Icons.warning_amber_rounded
                                : Icons.timer_outlined)
                            : Icons.event_available_outlined,
                        size: 14,
                        color: expiringSoon
                            ? Colors.orange.shade700
                            : kMediumGrey),
                    const SizedBox(width: 5),
                    Text(
                        isPending && remainingTimeDisplay != "Expirado"
                            ? "Expira em: "
                            : "Validade: ",
                        style:
                            const TextStyle(fontSize: 13, color: kMediumGrey)),
                    Text(
                        isPending && remainingTimeDisplay != "Expirado"
                            ? remainingTimeDisplay
                            : voucher.formattedValidityDate,
                        style: TextStyle(
                            fontSize: 13,
                            color: expiringSoon
                                ? Colors.orange.shade800
                                : kDarkGrey,
                            fontWeight: expiringSoon
                                ? FontWeight.bold
                                : FontWeight.w500)),
                    if (expiringSoon)
                      Text(" (expirando)",
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                              fontStyle: FontStyle.italic))
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItemInline(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: kMediumGrey),
        const SizedBox(width: 5),
        Text("$label: ",
            style: const TextStyle(fontSize: 13, color: kMediumGrey)),
        Text(value,
            style: const TextStyle(
                fontSize: 13, color: kDarkGrey, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
