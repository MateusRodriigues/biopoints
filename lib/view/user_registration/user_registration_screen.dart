// lib/view/user_registration/user_registration_screen.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import 'unit_selection_screen.dart';
import '../../models/unidade.dart';

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  ApiService? _apiService;
  SharedPreferences? _prefs;

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cellController = TextEditingController();
  final _cpfController = TextEditingController();

  // Formatadores
  final _cellMaskFormatter = MaskTextInputFormatter(
      mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _cpfMaskFormatter = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  List<int> _selectedUnitIds = [];
  String _selectedUnitsDisplay = 'Selecione ao menos uma unidade*';
  List<Unidade> _allUnits = [];
  bool _unitSelectionError = false;

  @override
  void initState() {
    super.initState();
    _initializeApiHelperAndUnits();
  }

  Future<void> _initializeApiHelperAndUnits() async {
    if (!mounted) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _apiService = ApiService(baseUrl: apiBaseUrl, sharedPreferences: _prefs!);
      await _fetchAllUnits();
    } catch (e) {
      if (kDebugMode) {
        print("Erro ao inicializar SharedPreferences/ApiService: $e");
      }
      if (mounted) {
        _showErrorDialog(
            "Erro de Inicialização", "Não foi possível preparar a tela: $e");
      }
    }
  }

  Future<void> _fetchAllUnits() async {
    if (_apiService == null) {
      if (kDebugMode) print("Erro: ApiService nulo em _fetchAllUnits");
      return;
    }
    try {
      final response = await _apiService!.get('/api/farmacias');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> decodedJson = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _allUnits =
                decodedJson.map((json) => Unidade.fromJson(json)).toList();
          });
        }
        if (kDebugMode) print("Unidades carregadas: ${_allUnits.length}");
      } else {
        if (kDebugMode) {
          print("Erro ao buscar unidades: ${response.statusCode}");
        }
      }
    } catch (e) {
      if (kDebugMode) print("Exceção ao buscar unidades: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cellController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _navigateToUnitSelection() async {
    if (!mounted || _apiService == null || _prefs == null) {
      _showErrorDialog("Erro", "Componentes essenciais não inicializados.");
      return;
    }
    if (!mounted) return;
    final List<int>? result = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(
        builder: (context) => UnitSelectionScreen(
          apiService: _apiService!,
          initialSelectedIds: _selectedUnitIds,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedUnitIds = result;
        _unitSelectionError = _selectedUnitIds.isEmpty;
        if (_selectedUnitIds.isEmpty) {
          _selectedUnitsDisplay = 'Selecione ao menos uma unidade*';
        } else {
          _selectedUnitsDisplay = _allUnits
              .where((unit) => _selectedUnitIds.contains(unit.id))
              .map((unit) => unit.name)
              .take(3)
              .join(', ');
          if (_selectedUnitIds.length > 3) {
            _selectedUnitsDisplay += ', ... (${_selectedUnitIds.length})';
          }
          if (_selectedUnitsDisplay.isEmpty && _selectedUnitIds.isNotEmpty) {
            _selectedUnitsDisplay =
                '${_selectedUnitIds.length} unidade(s) selecionada(s)';
          }
        }
      });
      if (kDebugMode) print("Unidades Selecionadas: $_selectedUnitIds");
    }
  }

  Future<void> _registerUser() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    setState(() {
      _unitSelectionError = _selectedUnitIds.isEmpty;
    });

    if (!isFormValid || _unitSelectionError) {
      _showErrorDialog("Campos Inválidos",
          "Por favor, corrija os erros indicados no formulário e selecione ao menos uma farmácia.");
      return;
    }

    if (_apiService == null) {
      _showErrorDialog("Erro", "Serviço não inicializado.");
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final nome = _nameController.text.trim();
      final celular = _cellMaskFormatter.getUnmaskedText();
      final email = _emailController.text.trim();
      final cpf = _cpfMaskFormatter.getUnmaskedText();

      String? fieldError;

      // Verifica Nome
      if (kDebugMode) print("Verificando disponibilidade do Nome: $nome");
      final nameCheckResponse =
          await _apiService!.checkFieldAvailability('nome', nome);
      if (!mounted) {
        setState(() => _isLoading = false);
        return;
      }
      if (nameCheckResponse.statusCode == 200) {
        if ((jsonDecode(nameCheckResponse.body)['isAvailable'] ?? true) ==
            false) {
          fieldError =
              "O nome '$nome' já está em uso. Por favor, escolha outro.";
        }
      } else {
        fieldError =
            "Não foi possível verificar a disponibilidade do nome. Tente novamente.";
      }
      if (fieldError != null) {
        _showErrorDialog("Nome Indisponível", fieldError);
        setState(() => _isLoading = false);
        return;
      }
      fieldError = null; // Limpa o erro para a próxima verificação

      // Verifica Celular
      if (kDebugMode) print("Verificando disponibilidade do Celular: $celular");
      final cellCheckResponse =
          await _apiService!.checkFieldAvailability('celular', celular);
      if (!mounted) {
        setState(() => _isLoading = false);
        return;
      }
      if (cellCheckResponse.statusCode == 200) {
        if ((jsonDecode(cellCheckResponse.body)['isAvailable'] ?? true) ==
            false) {
          fieldError =
              "O celular '${_cellController.text}' já está cadastrado.";
        }
      } else {
        fieldError =
            "Não foi possível verificar a disponibilidade do celular. Tente novamente.";
      }
      if (fieldError != null) {
        _showErrorDialog("Celular Indisponível", fieldError);
        setState(() => _isLoading = false);
        return;
      }
      fieldError = null; // Limpa o erro para a próxima verificação

      // VERIFICA CPF (Agora obrigatório)
      if (kDebugMode) print("Verificando disponibilidade do CPF: $cpf");
      final cpfCheckResponse =
          await _apiService!.checkFieldAvailability('cpf', cpf);
      if (!mounted) {
        setState(() => _isLoading = false);
        return;
      }
      if (cpfCheckResponse.statusCode == 200) {
        if ((jsonDecode(cpfCheckResponse.body)['isAvailable'] ?? true) ==
            false) {
          fieldError = "O CPF '${_cpfController.text}' já está cadastrado.";
        }
      } else {
        fieldError =
            "Não foi possível verificar a disponibilidade do CPF. Tente novamente.";
      }
      if (fieldError != null) {
        _showErrorDialog("CPF Indisponível", fieldError);
        setState(() => _isLoading = false);
        return;
      }
      // --- FIM DA VERIFICAÇÃO ---

      final registrationData = {
        "nome": nome,
        "email": email,
        "senha": _passwordController.text,
        "confirmacaoSenha": _confirmPasswordController.text,
        "selectedUnitIds": _selectedUnitIds,
        "celular": celular,
        "cpf": cpf, // Envia CPF (agora obrigatório no DTO)
      };

      if (kDebugMode) {
        print("[Register] Payload Final: ${jsonEncode(registrationData)}");
      }

      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/api/auth/register'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(registrationData),
          )
          .timeout(const Duration(seconds: 25));

      if (kDebugMode) {
        print("[Register] Response Status: ${response.statusCode}");
        print("[Register] Response Body: ${response.body}");
      }
      if (!mounted) return;

      if (response.statusCode == 201) {
        _showSuccessDialog("Cadastro Realizado!",
            "Usuário criado com sucesso. Você pode fazer o login.");
      } else {
        String errorMessage = "Não foi possível realizar o cadastro.";
        try {
          final errorData = jsonDecode(response.body);
          if (errorData?['message'] != null) {
            errorMessage = errorData['message'];
          } else if (errorData is Map && errorData.containsKey('errors')) {
            final errors = errorData['errors'] as Map<String, dynamic>;
            if (errors.isNotEmpty) {
              final firstErrorField = errors.values.first;
              if (firstErrorField is List && firstErrorField.isNotEmpty) {
                errorMessage = firstErrorField.first;
              }
            }
          }
        } catch (_) {
          if (kDebugMode) {
            print("Não foi possível decodificar erro JSON do registro.");
          }
        }
        _showErrorDialog("Erro no Cadastro", errorMessage);
      }
    } on TimeoutException {
      if (!mounted) return;
      _showErrorDialog("Erro de Rede", "Tempo esgotado durante a operação.");
    } on http.ClientException catch (e) {
      if (!mounted) return;
      _showErrorDialog("Erro de Rede", "Erro de conexão: $e");
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog("Erro Inesperado", "Ocorreu um erro: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                color: Colors.green[800], fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
            child: Text(content, style: const TextStyle(color: kDarkGrey))),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
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
      backgroundColor: kWhite,
      appBar: AppBar(
        title: const Text('Criar Conta Cliente',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryBlue,
        foregroundColor: kWhite,
        elevation: 1,
        iconTheme: const IconThemeData(color: kWhite),
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      "Preencha seus dados abaixo (* obrigatório):",
                      style: TextStyle(
                          fontSize: 16,
                          color: kDarkGrey,
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _nameController,
                      decoration: _buildInputDecoration(
                          'Nome Completo*', Icons.person_outline),
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Nome muito curto (mínimo 3)'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      // CAMPO CPF ATUALIZADO
                      controller: _cpfController,
                      decoration: _buildInputDecoration(
                          'CPF*',
                          Icons
                              .badge_outlined), // Label alterado para indicar obrigatoriedade
                      keyboardType: TextInputType.number,
                      inputFormatters: [_cpfMaskFormatter],
                      validator: (v) {
                        final unmasked = _cpfMaskFormatter.getUnmaskedText();
                        if (unmasked.isEmpty) {
                          // Validação para campo vazio
                          return 'CPF obrigatório.';
                        }
                        if (unmasked.length != 11) {
                          return 'CPF inválido (11 dígitos).';
                        }
                        // Validação de algoritmo de CPF pode ser adicionada aqui se necessário
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: _buildInputDecoration(
                          'E-mail*', Icons.email_outlined),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'E-mail obrigatório.';
                        final regex =
                            RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!regex.hasMatch(v.trim()))
                          return 'E-mail inválido.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cellController,
                      decoration: _buildInputDecoration(
                          'Celular*', Icons.phone_android_outlined),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_cellMaskFormatter],
                      validator: (v) {
                        final unmasked = _cellMaskFormatter.getUnmaskedText();
                        if (unmasked.isEmpty) {
                          return 'Celular obrigatório.';
                        }
                        if (unmasked.length < 10 || unmasked.length > 11) {
                          return 'Número de celular inválido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration:
                          _buildInputDecoration('Senha*', Icons.lock_outline)
                              .copyWith(
                                  suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: kMediumGrey,
                          size: 20,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      )),
                      obscureText: _obscurePassword,
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Senha curta (mínimo 6)'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: _buildInputDecoration(
                              'Confirmar Senha*', Icons.lock_outline)
                          .copyWith(
                              suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: kMediumGrey,
                          size: 20,
                        ),
                        onPressed: () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword),
                      )),
                      obscureText: _obscureConfirmPassword,
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Confirmação obrigatória.';
                        if (v != _passwordController.text)
                          return 'As senhas não coincidem.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Text("Vincular Farmácia(s)*:",
                        style: TextStyle(
                            color: kDarkGrey,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _navigateToUnitSelection,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 14.0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: _unitSelectionError
                                    ? Colors.red.shade700
                                    : Colors.grey.shade300,
                                width: _unitSelectionError ? 1.5 : 1.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: _unitSelectionError
                                    ? Colors.red.shade700
                                    : Colors.grey.shade300,
                                width: _unitSelectionError ? 1.5 : 1.0),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.red.shade400, width: 1.0),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.red.shade700, width: 1.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedUnitsDisplay,
                                style: TextStyle(
                                    color: _unitSelectionError
                                        ? Colors.red.shade700
                                        : (_selectedUnitIds.isEmpty
                                            ? kMediumGrey
                                            : kDarkGrey),
                                    fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_drop_down,
                                size: 24,
                                color: _unitSelectionError
                                    ? Colors.red.shade700
                                    : kMediumGrey),
                          ],
                        ),
                      ),
                    ),
                    if (_unitSelectionError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                        child: Text('Selecione ao menos uma unidade.',
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 12)),
                      ),
                    const SizedBox(height: 35),
                    ElevatedButton.icon(
                      icon:
                          const Icon(Icons.person_add_alt_1_outlined, size: 20),
                      label: const Text('Criar Conta'),
                      onPressed: _isLoading ? null : _registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryBlue,
                        foregroundColor: kWhite,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                        shadowColor: kPrimaryBlue.withOpacity(0.4),
                        textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
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

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: kMediumGrey, fontSize: 15),
      prefixIcon: Icon(icon, color: kMediumGrey, size: 22),
      filled: true,
      fillColor: kWhite,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
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
        borderSide: BorderSide(color: kAccentBlue.withOpacity(0.7), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
      ),
    );
  }
}
