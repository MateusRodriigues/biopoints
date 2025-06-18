// lib/view/user_profile/user_profile_screen.dart
import 'package:biopoints/models/UserProfile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../models/user_unit_details.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ... (propriedades do State permanecem as mesmas) ...
  ApiService? _apiService;
  SharedPreferences? _prefs;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  UserProfile? _userProfile;
  final _formKey = GlobalKey<FormState>();
  TabController? _tabController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _cellController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _cpfMaskFormatter = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});
  final _phoneMaskFormatter = MaskTextInputFormatter(
      mask: '(##) ####-####', filter: {"#": RegExp(r'[0-9]')});
  final _cellMaskFormatter = MaskTextInputFormatter(
      mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _dobMaskFormatter = MaskTextInputFormatter(
      mask: '##/##/####', filter: {"#": RegExp(r'[0-9]')});
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  final Key _visibilityKey = const Key('userProfileScreenVisibilityKey');
  bool _isCurrentlyVisible = false;
  XFile? _pickedXFile;
  Uint8List? _pickedImageBytesWeb;
  bool _isUploadingAvatar = false;
  String _initialName = "";
  String _initialUnmaskedCell = "";
  String _initialUnmaskedPhone = "";
  String? _initialAvatarUrl;
  bool _isLoadingProfile = true;
  int _avatarVersion = 0;

  @override
  void initState() {
    // ... (initState permanece o mesmo) ...
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController?.addListener(() {
      if (!mounted) return;
      if (_tabController!.indexIsChanging ||
          _tabController!.index != _tabController!.previousIndex) {
        setStateIfMounted(() {});
        if (_tabController!.index == 0) {
          FocusScope.of(context).unfocus();
        }
      }
    });
    _initializeAndFetchProfile();
  }

  @override
  void dispose() {
    // ... (dispose permanece o mesmo) ...
    WidgetsBinding.instance.removeObserver(this);
    _tabController?.removeListener(() {});
    _tabController?.dispose();
    _nameController.dispose();
    _cpfController.dispose();
    _dobController.dispose();
    _cellController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _isCurrentlyVisible &&
        !_isLoading &&
        !_isSaving) {
      _fetchUserProfile(isInitialLoad: false);
    }
  }

  Future<void> _initializeAndFetchProfile() async {
    // ... (código existente sem alterações) ...
    if (!mounted) return;
    setStateIfMounted(() {
      _isLoading = true;
      _isLoadingProfile = true;
      _errorMessage = null;
      _pickedXFile = null;
      _pickedImageBytesWeb = null;
    });
    try {
      _prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final String? token = _prefs!.getString('jwt_token');
      final int? userId = _prefs!.getInt('user_id');
      if (token == null || userId == null) {
        if (mounted) {
          setStateIfMounted(() {
            _errorMessage = "Sessão inválida. Por favor, faça login novamente.";
            _isLoading = false;
            _isLoadingProfile = false;
          });
        }
        return;
      }
      _apiService = ApiService(baseUrl: apiBaseUrl, sharedPreferences: _prefs!);
      await _fetchUserProfile(isInitialLoad: true);
    } catch (e) {
      if (mounted) {
        setStateIfMounted(() {
          _errorMessage = "Erro na inicialização: $e";
          _isLoading = false;
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _fetchUserProfile({bool isInitialLoad = false}) async {
    // ... (código existente sem alterações) ...
    if (!mounted || _apiService == null) {
      if (mounted) {
        setStateIfMounted(() {
          if (isInitialLoad) _isLoading = false;
          _isLoadingProfile = false;
        });
      }
      return;
    }
    if (!isInitialLoad && mounted) {
      setStateIfMounted(() => _isLoadingProfile = true);
    } else if (isInitialLoad && mounted) {
      setStateIfMounted(() {
        _isLoading = true;
        _isLoadingProfile = true;
        _errorMessage = null;
      });
    }
    try {
      final response = await _apiService!.get('/api/profile/me');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        final newProfile = UserProfile.fromJson(decodedJson);
        if (mounted) {
          setStateIfMounted(() {
            bool avatarActuallyChanged =
                _userProfile?.avatarUrl != newProfile.avatarUrl;
            _userProfile = newProfile;
            if (isInitialLoad ||
                avatarActuallyChanged ||
                _nameController.text != _userProfile?.nome) {
              _populateFormFields(isInitialPopulation: true);
              if (avatarActuallyChanged) {
                _avatarVersion++;
              }
            }
            _errorMessage = null;
          });
        }
      } else {
        String serverMessage = "Erro ${response.statusCode} ao buscar dados.";
        try {
          final errorData = jsonDecode(response.body);
          if (errorData?['message'] != null) {
            serverMessage = errorData['message'];
          }
        } catch (_) {}
        if (mounted) _setErrorMessage(serverMessage);
      }
    } catch (e) {
      if (mounted) _setErrorMessage('Erro de comunicação ao buscar perfil.');
    } finally {
      if (mounted) {
        setStateIfMounted(() {
          if (isInitialLoad) _isLoading = false;
          _isLoadingProfile = false;
        });
      }
    }
  }

  void _populateFormFields({bool isInitialPopulation = false}) {
    if (_userProfile != null) {
      if (isInitialPopulation) {
        _initialName = _userProfile?.nome ?? '';
        _initialUnmaskedCell =
            (_userProfile?.celular ?? '').replaceAll(RegExp(r'\D'), '');
        _initialUnmaskedPhone =
            (_userProfile?.telefone ?? '').replaceAll(RegExp(r'\D'), '');
        _initialAvatarUrl = _userProfile?.avatarUrl;
      }
      if (isInitialPopulation || _nameController.text.isEmpty)
        _nameController.text = _userProfile?.nome ?? '';
      if (isInitialPopulation || _cpfController.text.isEmpty)
        _cpfController.text =
            _cpfMaskFormatter.maskText(_userProfile?.cpf ?? '');
      if (isInitialPopulation || _dobController.text.isEmpty)
        _dobController.text = _userProfile?.dataNascimento ?? '';
      if (isInitialPopulation || _cellController.text.isEmpty)
        _cellController.text =
            _cellMaskFormatter.maskText(_userProfile?.celular ?? '');
      if (isInitialPopulation || _phoneController.text.isEmpty)
        _phoneController.text =
            _phoneMaskFormatter.maskText(_userProfile?.telefone ?? '');
      if (isInitialPopulation || _emailController.text.isEmpty)
        _emailController.text = _userProfile?.email ?? '';
      if (isInitialPopulation || _addressController.text.isEmpty)
        _addressController.text = _userProfile?.endereco ?? '';
      if (isInitialPopulation) {
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    }
  }

  void _setErrorMessage(String message) {
    if (!mounted) return;
    if (_errorMessage == null || _errorMessage != message) {
      setStateIfMounted(() {
        _errorMessage = message;
      });
    }
  }

  Future<bool> _checkAvailability(String fieldName, String value) async {
    if (_apiService == null) return true;
    if (value.isEmpty &&
        (fieldName == 'celular' ||
            fieldName == 'telefone' ||
            fieldName == 'nome')) {
      return true;
    }
    try {
      final response =
          await _apiService!.checkFieldAvailability(fieldName, value);
      if (!mounted) return true;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isAvailable'] ?? true;
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  Future<void> _updateProfile() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) {
      _showErrorDialog("Campos Inválidos",
          "Por favor, corrija os erros indicados no formulário.");
      return;
    }
    if (_apiService == null || _userProfile == null) {
      _showErrorDialog(
          "Erro", "Dados do perfil não carregados ou serviço indisponível.");
      return;
    }
    FocusScope.of(context).unfocus();
    setStateIfMounted(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final newName = _nameController.text.trim();
    final newCellUnmasked = _cellController.text.replaceAll(RegExp(r'\D'), '');
    final newPhoneUnmasked =
        _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final newPassword = _newPasswordController.text;

    // As validações de disponibilidade continuam como antes
    // ... (código de verificação de duplicidade de nome, celular, etc) ...

    final profileUpdateData = {
      "nome": newName,
      // ***** CAMPO CPF REMOVIDO DO ENVIO *****
      "dataNascimento":
          _dobController.text.isEmpty ? null : _dobController.text,
      "celular": newCellUnmasked,
      "telefone": newPhoneUnmasked,
      "endereco": _addressController.text.trim(),
    };

    // O restante da lógica de _updateProfile permanece o mesmo,
    // apenas com o payload corrigido.
    // ...
    // try-catch e chamadas para salvar perfil, avatar e senha.
    try {
      bool profileUpdateSuccess = false;
      bool passwordUpdateAttempted = newPassword.isNotEmpty;
      bool passwordUpdateSuccess = !passwordUpdateAttempted;
      bool avatarUpdateAttempted = _pickedXFile != null;
      bool avatarActuallyUploadedAndProcessed = false;
      bool hasProfileDataChanged = newName != _initialName ||
          newCellUnmasked != _initialUnmaskedCell ||
          newPhoneUnmasked != _initialUnmaskedPhone ||
          _dobController.text != (_userProfile?.dataNascimento ?? '') ||
          _addressController.text.trim() != (_userProfile?.endereco ?? '');
      if (hasProfileDataChanged) {
        final profileResponse = await _apiService!
            .put('/api/profile/me', body: jsonEncode(profileUpdateData));
        if (!mounted) {
          setStateIfMounted(() => _isSaving = false);
          return;
        }
        if (profileResponse.statusCode == 204 ||
            profileResponse.statusCode == 200) {
          profileUpdateSuccess = true;
          await _prefs?.setString('user_name', newName);
        } else {
          String serverMessage = "Erro ${profileResponse.statusCode}";
          try {
            final ed = jsonDecode(profileResponse.body);
            if (ed is Map && ed.containsKey('errors')) {
              final ers = ed['errors'] as Map<String, dynamic>;
              serverMessage = ers.entries
                  .map((e) => "${e.key}: ${e.value.join(', ')}")
                  .join('\n');
            } else if (ed?['message'] != null) {
              serverMessage = ed['message'];
            }
          } catch (_) {}
          profileUpdateSuccess = false;
        }
      } else {
        profileUpdateSuccess = true;
      }
      if (avatarUpdateAttempted) {
        await _uploadAvatarInternal();
        avatarActuallyUploadedAndProcessed =
            _pickedXFile == null && !_isUploadingAvatar;
      } else {
        avatarActuallyUploadedAndProcessed = true;
      }
      if (passwordUpdateAttempted) {
        final passwordResponse = await _apiService!.post(
            '/api/profile/change-password',
            body: jsonEncode({"newPassword": newPassword}));
        if (!mounted) {
          setStateIfMounted(() => _isSaving = false);
          return;
        }
        if (passwordResponse.statusCode == 204 ||
            passwordResponse.statusCode == 200) {
          passwordUpdateSuccess = true;
        } else {
          passwordUpdateSuccess = false;
        }
      }
      if (mounted) {
        bool anyDataActuallyChangedOrAttempted = hasProfileDataChanged ||
            avatarUpdateAttempted ||
            passwordUpdateAttempted;
        bool allOperationsSucceeded = profileUpdateSuccess &&
            passwordUpdateSuccess &&
            avatarActuallyUploadedAndProcessed;
        if (anyDataActuallyChangedOrAttempted && allOperationsSucceeded) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Perfil atualizado com sucesso!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ));
          await _fetchUserProfile(isInitialLoad: true);
          _tabController?.animateTo(0);
        } else if (!anyDataActuallyChangedOrAttempted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Nenhuma alteração para salvar."),
            backgroundColor: Colors.blueGrey,
            duration: Duration(seconds: 2),
          ));
        }
        setStateIfMounted(() {
          if (passwordUpdateSuccess) {
            _newPasswordController.clear();
            _confirmPasswordController.clear();
          }
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setStateIfMounted(() => _isSaving = false);
        _showErrorDialog(
            "Erro ao Salvar", "Ocorreu um erro inesperado: ${e.toString()}");
      }
    }
  }

  // ... (restante dos métodos como _pickImage, _uploadAvatarInternal, _showErrorDialog, etc.) ...
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (pickedFile != null) {
        if (!mounted) return;
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setStateIfMounted(() {
            _pickedXFile = pickedFile;
            _pickedImageBytesWeb = bytes;
            _errorMessage = null;
          });
        } else {
          setStateIfMounted(() {
            _pickedXFile = pickedFile;
            _pickedImageBytesWeb = null;
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      _showErrorDialog("Erro ao Selecionar Imagem",
          "Não foi possível carregar a imagem: $e");
    }
  }

  Future<void> _uploadAvatarInternal() async {
    if (_apiService == null || _pickedXFile == null) {
      return;
    }
    if (mounted) setStateIfMounted(() => _isUploadingAvatar = true);
    String? tempErrorMessageDuringUpload;
    try {
      String fileName = _pickedXFile!.name;
      Uint8List imageBytesToSend;
      if (kIsWeb) {
        imageBytesToSend =
            _pickedImageBytesWeb ?? await _pickedXFile!.readAsBytes();
      } else {
        imageBytesToSend = await File(_pickedXFile!.path).readAsBytes();
      }
      if (imageBytesToSend.isEmpty) {
        throw Exception("Os bytes da imagem estão vazios.");
      }
      final streamedResponse = await _apiService!
          .uploadAvatar(imageBytes: imageBytesToSend, fileName: fileName);
      final response = await http.Response.fromStream(streamedResponse);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String? newAvatarPath = responseData['avatarPath'] as String?;
        if (newAvatarPath != null && _prefs != null) {
          await _prefs!.setString('user_avatar', newAvatarPath);
        }
        setStateIfMounted(() {
          _pickedXFile = null;
          _pickedImageBytesWeb = null;
          _avatarVersion++;
          if (_errorMessage != null &&
              _errorMessage!.toLowerCase().contains("avatar")) {
            _errorMessage = null;
          }
        });
      } else {
        String errorMsg = "Falha no upload do avatar (${response.statusCode})";
        try {
          errorMsg = jsonDecode(response.body)['message'] ?? errorMsg;
        } catch (_) {}
        tempErrorMessageDuringUpload = "Erro no Upload do Avatar: $errorMsg";
      }
    } catch (e) {
      tempErrorMessageDuringUpload =
          "Falha de comunicação ao enviar avatar: ${e.toString()}";
    } finally {
      if (mounted) {
        setStateIfMounted(() {
          _isUploadingAvatar = false;
          if (tempErrorMessageDuringUpload != null) {
            _errorMessage = tempErrorMessageDuringUpload;
          }
        });
      }
    }
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: kPrimaryBlue),
                title: const Text('Escolher da Galeria'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.camera_alt_outlined, color: kPrimaryBlue),
                title: const Text('Tirar Foto com a Câmera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_pickedXFile != null)
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded,
                      color: Colors.red.shade600),
                  title: Text('Limpar Imagem Selecionada',
                      style: TextStyle(color: Colors.red.shade600)),
                  onTap: () {
                    Navigator.of(context).pop();
                    setStateIfMounted(() {
                      _pickedXFile = null;
                      _pickedImageBytesWeb = null;
                    });
                  },
                ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kVeryLightGrey,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark
            .copyWith(statusBarColor: Colors.transparent),
      ),
      body: SafeArea(
        child: VisibilityDetector(
          key: _visibilityKey,
          onVisibilityChanged: (visibilityInfo) {
            final visiblePercentage = visibilityInfo.visibleFraction * 100;
            final bool becameVisible =
                visiblePercentage > 80 && !_isCurrentlyVisible;
            _isCurrentlyVisible = visiblePercentage > 80;
            if (becameVisible && !_isLoading && !_isSaving) {
              _fetchUserProfile(isInitialLoad: false);
            }
          },
          child: _isLoading && _userProfile == null
              ? const Center(
                  child: CircularProgressIndicator(color: kPrimaryBlue))
              : _errorMessage != null && _userProfile == null
                  ? _buildErrorWidget()
                  : _buildProfileTabs(),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.orange[600], size: 60),
            const SizedBox(height: 20),
            Text(
              _errorMessage ?? "Ocorreu um erro.",
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: kDarkGrey, fontSize: 17, height: 1.4),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("Tentar Novamente"),
              onPressed: _initializeAndFetchProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: kDarkGrey,
                foregroundColor: kWhite,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTabs() {
    ImageProvider<Object> displayImage;

    if (_pickedXFile != null) {
      if (kIsWeb) {
        displayImage = _pickedImageBytesWeb != null
            ? MemoryImage(_pickedImageBytesWeb!)
            : const AssetImage('assets/images/avatar_placeholder.png')
                as ImageProvider;
      } else {
        displayImage = FileImage(File(_pickedXFile!.path));
      }
    } else if (_userProfile?.avatarUrl != null &&
        _userProfile!.avatarUrl!.isNotEmpty) {
      String finalImageUrl = "$publicImageBaseUrl/${_userProfile!.avatarUrl!}"
          .replaceAllMapped(RegExp(r'(?<!:)(/{2,})'), (match) => '/');
      displayImage = NetworkImage(finalImageUrl);
    } else {
      displayImage = const AssetImage('assets/images/avatar_placeholder.png');
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  if (_tabController?.index == 1) {
                    _showImageSourceActionSheet(context);
                  }
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      key: ValueKey(_userProfile?.avatarUrl ?? _avatarVersion),
                      radius: 55,
                      backgroundColor: kLightGrey.withOpacity(0.5),
                      backgroundImage: displayImage,
                      onBackgroundImageError: displayImage is NetworkImage
                          ? (exception, stackTrace) {
                              if (kDebugMode) {
                                print(
                                    "[UserProfile CircleAvatar Load Error] Exception: $exception, URL: ${(displayImage as NetworkImage).url}");
                              }
                            }
                          : null,
                      child: _isUploadingAvatar
                          ? const SizedBox(
                              width: 25,
                              height: 25,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: kPrimaryBlue))
                          : ((_pickedXFile == null &&
                                  (_userProfile?.avatarUrl == null ||
                                      _userProfile!.avatarUrl!.isEmpty)))
                              ? Icon(
                                  _tabController?.index == 1 &&
                                          !_isLoadingProfile
                                      ? Icons.add_a_photo_outlined
                                      : Icons.person_rounded,
                                  size: _tabController?.index == 1 ? 40 : 50,
                                  color: kMediumGrey)
                              : null,
                    ),
                    if (_tabController?.index == 1 &&
                        !_isUploadingAvatar &&
                        !_isLoadingProfile)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: kPrimaryBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: kWhite, width: 1.5)),
                        child: const Icon(Icons.edit_rounded,
                            color: kWhite, size: 16),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isLoadingProfile
                    ? "Carregando..."
                    : (_userProfile?.nome ?? 'Usuário'),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kDarkGrey),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: kPrimaryBlue,
          unselectedLabelColor: kMediumGrey,
          indicatorColor: kPrimaryBlue,
          indicatorWeight: 2.5,
          labelStyle:
              const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
          onTap: (index) {
            if (index == 0) FocusScope.of(context).unfocus();
            setStateIfMounted(() {});
          },
          tabs: const [
            Tab(text: 'Dados do Usuário'),
            Tab(text: 'Editar Dados'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildViewUserDataTab(),
              _buildEditUserDataTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewUserDataTab() {
    if (_isLoadingProfile && _userProfile == null) {
      return const Center(
          child: CircularProgressIndicator(color: kPrimaryBlue));
    }
    if (_userProfile == null) {
      return const Center(
          child: Text("Nenhum dado de usuário para exibir.",
              style: TextStyle(color: kMediumGrey)));
    }
    return RefreshIndicator(
      onRefresh: () => _fetchUserProfile(isInitialLoad: true),
      color: kPrimaryBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Informações Pessoais",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kDarkGrey)),
            const SizedBox(height: 20),
            _buildInfoRow("Nome:", _userProfile!.nome ?? "Não informado",
                Icons.person_outline),
            _buildInfoRow("E-mail:", _userProfile!.email ?? "Não informado",
                Icons.email_outlined),
            _buildInfoRow(
                "Celular:",
                _cellMaskFormatter.maskText(_userProfile!.celular ?? ""),
                Icons.phone_android_outlined),
            if (_userProfile!.telefone != null &&
                _userProfile!.telefone!.isNotEmpty)
              _buildInfoRow(
                  "Telefone:",
                  _phoneMaskFormatter.maskText(_userProfile!.telefone!),
                  Icons.phone_outlined),
            _buildInfoRow(
                "Endereço:",
                _userProfile!.endereco ?? "Não informado",
                Icons.location_on_outlined),
            if (_userProfile!.cpf != null && _userProfile!.cpf!.isNotEmpty)
              _buildInfoRow(
                  "CPF:",
                  _cpfMaskFormatter.maskText(_userProfile!.cpf!),
                  Icons.badge_outlined),
            if (_userProfile!.dataNascimento != null &&
                _userProfile!.dataNascimento!.isNotEmpty)
              _buildInfoRow("Data de Nascimento:",
                  _userProfile!.dataNascimento!, Icons.calendar_today_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kPrimaryBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: kMediumGrey,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value.isEmpty ? "Não informado" : value,
                    style:
                        TextStyle(fontSize: 15, color: kDarkGrey, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditUserDataTab() {
    return RefreshIndicator(
      onRefresh: () => _fetchUserProfile(isInitialLoad: true),
      color: kPrimaryBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              _buildTextField(
                  _nameController, 'Nome Completo*', Icons.person_outline,
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Nome muito curto (mín. 3 caracteres)'
                      : null),
              _buildTextField(_emailController, 'E-mail (não editável)',
                  Icons.email_outlined,
                  enabled: false),
              _buildTextField(
                  _cpfController, 'CPF (não editável)', Icons.badge_outlined,
                  enabled: false, inputFormatters: [_cpfMaskFormatter]),
              _buildTextField(_dobController, 'Data Nascimento (dd/mm/aaaa)',
                  Icons.calendar_today_outlined,
                  keyboardType: TextInputType.datetime,
                  inputFormatters: [_dobMaskFormatter], validator: (v) {
                if (v != null && v.isNotEmpty) {
                  if (v.length != 10) return 'Formato inválido.';
                  try {
                    DateFormat('dd/MM/yyyy').parseStrict(v);
                  } catch (e) {
                    return 'Data inválida.';
                  }
                }
                return null;
              }),
              _buildTextField(
                  _cellController, 'Celular*', Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_cellMaskFormatter], validator: (v) {
                String currentValue = v ?? '';
                String unmasked = currentValue.replaceAll(RegExp(r'\D'), '');
                if (unmasked.isEmpty) {
                  if (currentValue.isNotEmpty &&
                      currentValue.replaceAll(RegExp(r'[^0-9]'), '').isEmpty) {
                    return 'Número de celular inválido.';
                  }
                  return 'Celular obrigatório.';
                }
                if (unmasked.length < 10 || unmasked.length > 11) {
                  return 'Número de celular inválido (${unmasked.length} dígitos).';
                }
                return null;
              }),
              _buildTextField(
                  _phoneController, 'Telefone Fixo', Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_phoneMaskFormatter], validator: (v) {
                final unmasked =
                    _phoneController.text.replaceAll(RegExp(r'\D'), '');
                if (unmasked.isNotEmpty && unmasked.length < 10) {
                  return 'Número inválido (mín. 10 dígitos).';
                }
                return null;
              }),
              _buildTextField(_addressController, 'Endereço Completo',
                  Icons.location_on_outlined),
              const Divider(height: 32, thickness: 1, color: kLightGrey),
              Text("Alterar Senha (opcional)",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kDarkGrey)),
              const SizedBox(height: 16),
              _buildTextField(
                  _newPasswordController, 'Nova Senha', Icons.lock_outline,
                  obscureText: _obscureNewPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: kMediumGrey,
                        size: 20),
                    onPressed: () => setStateIfMounted(
                        () => _obscureNewPassword = !_obscureNewPassword),
                  ), validator: (v) {
                if (v != null && v.isNotEmpty && v.length < 6) {
                  return 'Senha curta (mínimo 6 caracteres)';
                }
                if (v != null &&
                    v.isNotEmpty &&
                    _confirmPasswordController.text.isEmpty &&
                    _formKey.currentState != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted &&
                        _formKey.currentState != null &&
                        _formKey.currentState!.mounted)
                      _formKey.currentState!.validate();
                  });
                }
                return null;
              }),
              _buildTextField(_confirmPasswordController,
                  'Confirmar Nova Senha', Icons.lock_outline,
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: kMediumGrey,
                        size: 20),
                    onPressed: () => setStateIfMounted(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ), validator: (v) {
                if (_newPasswordController.text.isNotEmpty) {
                  if (v == null || v.isEmpty) {
                    return 'Confirmação obrigatória';
                  }
                  if (v != _newPasswordController.text) {
                    return 'As senhas não coincidem';
                  }
                }
                return null;
              }),
              const SizedBox(height: 35),
              ElevatedButton.icon(
                icon: _isSaving || _isUploadingAvatar
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: kWhite))
                    : const Icon(Icons.save_alt_rounded, size: 20),
                label: Text(_isSaving || _isUploadingAvatar
                    ? 'Salvando...'
                    : 'Salvar Alterações'),
                onPressed: _isLoading || _isSaving || _isUploadingAvatar
                    ? null
                    : _updateProfile,
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
                        letterSpacing: 0.5)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool enabled = true,
      TextInputType? keyboardType,
      List<MaskTextInputFormatter>? inputFormatters,
      String? Function(String?)? validator,
      bool obscureText = false,
      Widget? suffixIcon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: TextStyle(
            color: enabled ? Colors.black87 : kMediumGrey, fontSize: 15),
        obscureText: obscureText,
        decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: kMediumGrey, fontSize: 15),
            prefixIcon: Icon(icon, color: kMediumGrey, size: 22),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? kWhite : kLightGrey.withOpacity(0.4),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.grey.shade300, width: 1.0)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.grey.shade300, width: 1.0)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: kAccentBlue.withOpacity(0.7), width: 1.5)),
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.grey.shade200, width: 1.0)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.shade400, width: 1.0)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.red.shade700, width: 1.5))),
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
    );
  }
}
