// lib/view/login/login_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:biopoints/view/home/home_screen.dart';
// import 'package:biopoints/view/login/reset_password_screen.dart'; // Não navegaremos mais para cá diretamente do app
import 'package:biopoints/view/user_registration/user_registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart'; // Para abrir links

import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController _emailForgotController = TextEditingController();

  bool _isLoading = false;
  bool _rememberMe = false;
  ApiService? _apiService;

  @override
  void initState() {
    super.initState();
    _initializeDependencies();
  }

  Future<void> _initializeDependencies() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _apiService = ApiService(baseUrl: apiBaseUrl, sharedPreferences: prefs);
    _loadRememberMePreference(prefs);
  }

  Future<void> _loadRememberMePreference(SharedPreferences prefs) async {
    if (!mounted) return;
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? false;
      if (_rememberMe) {
        usernameController.text = prefs.getString('saved_email') ?? '';
      }
    });
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    _emailForgotController.dispose();
    super.dispose();
  }

  Future<void> loginUsuario(BuildContext buildContext) async {
    if (_isLoading || _apiService == null) return;
    final currentContext = buildContext;

    setState(() {
      _isLoading = true;
    });
    String email = usernameController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog(currentContext, 'Erro de Login',
          'Por favor, preencha o email e a senha.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final String requestBody =
          jsonEncode({'Email': email, 'Senha': password});
      final http.Response response = await _apiService!
          .post('/api/auth/login', body: requestBody, includeToken: false);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final userData = responseData['user'];
        final String? token = responseData['token'] as String?;
        final int? userId = userData?['uId'] as int?;
        // ... (restante da lógica de login bem-sucedido) ...
        final String? userName = userData?['uNome'] as String?;
        final String? userEmail = userData?['uEmail'] as String?;
        final String? userAvatar = userData?['uAvatar'] as String?;
        final String? userUnitsString = userData?['uUnidade'] as String?;

        if (token != null &&
            token.isNotEmpty &&
            userId != null &&
            userName != null &&
            userEmail != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          await prefs.setInt('user_id', userId);
          await prefs.setString('user_name', userName);
          await prefs.setString('user_email', userEmail);
          if (userAvatar != null && userAvatar.isNotEmpty) {
            await prefs.setString('user_avatar', userAvatar);
          } else {
            await prefs.remove('user_avatar');
          }
          if (userUnitsString != null && userUnitsString.isNotEmpty) {
            await prefs.setString('user_linked_units', userUnitsString);
          } else {
            await prefs.remove('user_linked_units');
          }

          if (_rememberMe) {
            await prefs.setBool('remember_me', true);
            await prefs.setString('saved_email', email);
          } else {
            await prefs.remove('remember_me');
            await prefs.remove('saved_email');
          }

          if (!mounted) return;
          Navigator.pushReplacement(currentContext,
              MaterialPageRoute(builder: (context) => const HomePage()));
          return;
        } else {
          _showErrorDialog(currentContext, 'Erro de Login',
              'Login inválido: Dados essenciais não recebidos.');
        }
      } else {
        String serverMessage = 'Usuário ou senha incorretos.';
        if (response.statusCode == 401) {
          serverMessage = "Email ou senha inválidos ou usuário inativo.";
        }
        try {
          final errorData = jsonDecode(response.body);
          if (errorData?['message'] != null) {
            serverMessage = errorData['message'];
          }
        } catch (_) {}
        _showErrorDialog(currentContext, 'Erro de Login', serverMessage);
      }
    } on TimeoutException catch (_) {
      if (!mounted) return;
      _showErrorDialog(currentContext, 'Erro de Conexão',
          'Tempo esgotado ao conectar com o servidor.');
    } on http.ClientException catch (e) {
      if (!mounted) return;
      _showErrorDialog(currentContext, 'Erro de Conexão',
          'Não foi possível conectar ao servidor.');
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(currentContext, 'Erro Inesperado',
          'Ocorreu um erro inesperado durante o login.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final currentContext = context;

    if (_apiService == null) {
      _showErrorDialog(currentContext, "Erro de Serviço",
          "O serviço de API não está disponível. Tente novamente mais tarde.");
      return;
    }
    _emailForgotController.text = usernameController.text.trim();

    final String? emailForReset = await showDialog<String>(
      context: currentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Recuperar Senha'),
          content: TextField(
            controller: _emailForgotController,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Digite seu e-mail cadastrado',
              icon: Icon(Icons.email_outlined),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(null),
            ),
            ElevatedButton(
              child: const Text('Enviar'),
              onPressed: () {
                if (_emailForgotController.text.trim().isNotEmpty) {
                  Navigator.of(dialogContext)
                      .pop(_emailForgotController.text.trim());
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text('Por favor, insira um e-mail.'),
                        backgroundColor: Colors.orange),
                  );
                }
              },
            ),
          ],
        );
      },
    );

    if (emailForReset != null && emailForReset.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final response = await _apiService!.forgotPassword(emailForReset);
        if (!mounted) return;

        final responseData = jsonDecode(response.body);
        if (response.statusCode == 200) {
          _showInfoDialog(
            // Não precisa mais do tokenForDevelopment
            currentContext,
            "Verifique seu E-mail",
            responseData['message'] ??
                "Instruções de recuperação foram enviadas para o seu e-mail. Por favor, verifique sua caixa de entrada e spam.",
          );
        } else {
          _showErrorDialog(
              currentContext,
              "Erro ao Solicitar",
              responseData['message'] ??
                  "Não foi possível processar sua solicitação (${response.statusCode}).");
        }
      } catch (e) {
        if (!mounted) return;
        _showErrorDialog(currentContext, "Erro de Comunicação",
            "Falha ao conectar ao servidor: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(BuildContext ctx, String title, String content) {
    if (!mounted) return;
    showDialog(
      context: ctx,
      builder: (BuildContext dialogCtx) => AlertDialog(
        title: Text(title,
            style: TextStyle(
                color: Colors.red.shade700, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
            child: Text(content, style: const TextStyle(color: kDarkGrey))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Ok',
                style: TextStyle(
                    color: kPrimaryBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Diálogo de informação ajustado
  void _showInfoDialog(BuildContext ctx, String title, String content) {
    if (!mounted) return;
    showDialog(
      context: ctx,
      builder: (BuildContext dialogCtx) => AlertDialog(
        title: Text(title,
            style: TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(content, style: const TextStyle(color: kDarkGrey)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Ok',
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kLightBlue.withOpacity(0.5),
              kWhite,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const _LoginHeader(),
                      const SizedBox(height: 25),
                      const Text(
                        'Bem-vindo, por favor, se identifique aqui',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: kDarkGrey),
                      ),
                      const SizedBox(height: 40),
                      _LoginTextField(
                        controller: usernameController,
                        hintText: 'Seu Email',
                        obscureText: false,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.alternate_email,
                      ),
                      const SizedBox(height: 20),
                      _LoginTextField(
                        controller: passwordController,
                        hintText: 'Sua Senha',
                        obscureText: true,
                        prefixIcon: Icons.lock_outline,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _rememberMe = !_rememberMe;
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 20.0,
                                    width: 20.0,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          _rememberMe = value ?? false;
                                        });
                                      },
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      activeColor: kPrimaryBlue,
                                      checkColor: kWhite,
                                      side: BorderSide(color: kMediumGrey),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('Lembrar-me',
                                      style: TextStyle(
                                          fontSize: 13, color: kDarkGrey)),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed:
                                _isLoading ? null : _handleForgotPassword,
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: kPrimaryBlue,
                            ),
                            child: const Text('Esqueceu a senha?',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: kPrimaryBlue,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 35),
                      _LoginButton(
                          onTap:
                              _isLoading ? null : () => loginUsuario(context)),
                      const SizedBox(height: 50),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Não tem uma conta?',
                              style: TextStyle(color: kMediumGrey)),
                          const SizedBox(width: 5),
                          GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (newRouteContext) =>
                                                const UserRegistrationScreen()));
                                  },
                            child: const Text(
                              'Cadastre-se',
                              style: TextStyle(
                                  color: kPrimaryBlue,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                Container(
                  color: kWhite.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(kPrimaryBlue)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 50.0, bottom: 10.0),
      child: Image.asset(
        'assets/images/logo.png',
        height: 65,
        errorBuilder: (context, error, stackTrace) {
          print("Erro ao carregar logo: $error");
          return const Icon(Icons.eco_outlined, size: 65, color: kPrimaryBlue);
        },
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData prefixIcon;
  const _LoginTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.obscureText,
    this.keyboardType,
    required this.prefixIcon,
  });
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: kMediumGrey, fontSize: 15),
        prefixIcon: Icon(
          prefixIcon,
          color: kMediumGrey,
          size: 22,
        ),
        filled: true,
        fillColor: kWhite,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
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
          borderSide:
              BorderSide(color: kAccentBlue.withOpacity(0.7), width: 1.5),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _LoginButton({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: onTap != null ? kPrimaryBlue : Colors.grey.shade400,
          foregroundColor: kWhite,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: onTap != null ? 4 : 0,
          shadowColor: kPrimaryBlue.withOpacity(0.4),
        ),
        child: const Text(
          "Entrar",
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }
}
