// lib/view/login/reset_password_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para kDebugMode
import 'package:biopoints/services/api_service.dart';
import 'package:biopoints/utils/app_colors.dart';
import 'package:biopoints/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart'; // Para navegação de volta ao login

class ResetPasswordScreen extends StatefulWidget {
  final String token;
  final String email;

  const ResetPasswordScreen({
    super.key,
    required this.token,
    required this.email,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  ApiService? _apiService;

  @override
  void initState() {
    super.initState();
    _initializeApiService();
  }

  Future<void> _initializeApiService() async {
    // Garante que SharedPreferences seja inicializado antes de criar ApiService
    // e que setState só seja chamado se o widget estiver montado.
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _apiService = ApiService(baseUrl: apiBaseUrl, sharedPreferences: prefs);
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitResetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_apiService == null) {
      _showErrorDialog(
          "Erro de Serviço", "O serviço de API não está disponível.");
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      // ***** CORREÇÃO AQUI: Adicionado o quarto argumento *****
      final response = await _apiService!.resetPassword(
          widget.email,
          widget.token,
          _newPasswordController.text,
          _confirmPasswordController.text // Argumento adicionado
          );
      // ***** FIM DA CORREÇÃO *****

      if (!mounted) return;
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showSuccessDialog(
            "Senha Redefinida",
            responseData['message'] ??
                "Sua senha foi alterada com sucesso! Faça o login.");
      } else {
        _showErrorDialog(
            "Erro ao Redefinir",
            responseData['message'] ??
                "Não foi possível redefinir sua senha (${response.statusCode}). Verifique se o link não expirou ou se os dados estão corretos.");
      }
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) {
        print("[ResetPasswordScreen] Erro ao submeter: $e");
      }
      _showErrorDialog("Erro de Comunicação",
          "Falha ao conectar ao servidor: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
            child: const Text('Fazer Login',
                style: TextStyle(
                    color: kPrimaryBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Redefinir Senha',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryBlue,
        foregroundColor: kWhite,
        elevation: 1,
        iconTheme: const IconThemeData(color: kWhite),
      ),
      backgroundColor: kWhite, // Fundo branco para consistência
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Crie uma nova senha para sua conta associada ao e-mail:\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, color: kDarkGrey, height: 1.4),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Nova Senha*',
                      hintText: 'Mínimo 6 caracteres',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: kMediumGrey,
                            size: 20),
                        onPressed: () => setState(
                            () => _obscureNewPassword = !_obscureNewPassword),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    obscureText: _obscureNewPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira a nova senha.';
                      }
                      if (value.length < 6) {
                        return 'A senha deve ter no mínimo 6 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirmar Nova Senha*',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: kMediumGrey,
                            size: 20),
                        onPressed: () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    obscureText: _obscureConfirmPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, confirme a nova senha.';
                      }
                      if (value != _newPasswordController.text) {
                        return 'As senhas não coincidem.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 35),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitResetPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      foregroundColor: kWhite,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: kWhite, strokeWidth: 2.5))
                        : const Text('Redefinir Senha',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(kPrimaryBlue)),
              ),
            ),
        ],
      ),
    );
  }
}
