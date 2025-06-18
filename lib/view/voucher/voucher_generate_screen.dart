import 'dart:math';
import 'package:flutter/material.dart';

class GenerateVoucherScreen extends StatefulWidget {
  final String clientName;
  final String productName;
  final String productDescription; // Resumo do produto
  final String pharmacyName;
  final double productValue;
  final int pointsToConsume;

  const GenerateVoucherScreen({
    super.key,
    required this.clientName,
    required this.productName,
    required this.productDescription,
    required this.pharmacyName,
    required this.productValue,
    required this.pointsToConsume,
  });

  @override
  State<GenerateVoucherScreen> createState() => _GenerateVoucherScreenState();
}

class _GenerateVoucherScreenState extends State<GenerateVoucherScreen> {
  late DateTime expirationDate;
  late String formattedExpiration;
  String? voucherCode;

  @override
  void initState() {
    super.initState();
    // Define a expiração para 24 horas a partir do momento de geração
    expirationDate = DateTime.now().add(const Duration(hours: 24));
    formattedExpiration = _formatDateTime(expirationDate);
  }

  String _formatDateTime(DateTime dt) {
    String day = dt.day.toString().padLeft(2, '0');
    String month = dt.month.toString().padLeft(2, '0');
    String year = dt.year.toString();
    String hour = dt.hour.toString().padLeft(2, '0');
    String minute = dt.minute.toString().padLeft(2, '0');
    return "$day/$month/$year às $hour:$minute";
  }

  // Gera um código voucher aleatório de 8 caracteres
  String _generateVoucherCode() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  void _confirmVoucher() {
    setState(() {
      voucherCode = _generateVoucherCode();
    });
    // Exibe o código gerado em um AlertDialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Voucher Gerado"),
        content: Text("Seu código de voucher é: $voucherCode"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0A3D62);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF75E6DA), Color(0xFF17203A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title:
            const Text("Gerar Voucher", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informações do cliente
              _buildInfoRow("Cliente", widget.clientName),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow("Produto", widget.productName),
                      const Divider(),
                      _buildInfoRow("Resumo", widget.productDescription),
                      const Divider(),
                      _buildInfoRow("Farmácia", widget.pharmacyName),
                      const Divider(),
                      _buildInfoRow("Valor",
                          "R\$${widget.productValue.toStringAsFixed(2)}"),
                      const Divider(),
                      _buildInfoRow(
                          "Pontos a consumir", "${widget.pointsToConsume} pts"),
                      const Divider(),
                      _buildInfoRow("Expiração", formattedExpiration),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmVoucher,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Confirmar Voucher",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
