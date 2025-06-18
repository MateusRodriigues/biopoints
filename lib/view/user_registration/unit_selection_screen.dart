// lib/view/user_registration/unit_selection_screen.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http; // Para ClientException
import 'package:flutter/foundation.dart';

// Imports locais (verifique os caminhos!)
import '../../models/unidade.dart'; // Precisa do modelo Unidade
import '../../services/api_service.dart'; // Usa o ApiService para buscar unidades
import '../../utils/app_colors.dart';

class UnitSelectionScreen extends StatefulWidget {
  final ApiService apiService; // Recebe o ApiService já inicializado
  final List<int> initialSelectedIds; // Recebe os IDs já selecionados

  const UnitSelectionScreen({
    super.key,
    required this.apiService,
    required this.initialSelectedIds,
  });

  @override
  State<UnitSelectionScreen> createState() => _UnitSelectionScreenState();
}

class _UnitSelectionScreenState extends State<UnitSelectionScreen> {
  List<Unidade> _allUnits = []; // Todas as unidades vindas da API
  List<Unidade> _filteredUnits = []; // Unidades filtradas pela busca
  Set<int> _selectedIds =
      {}; // Conjunto para guardar IDs selecionados (evita duplicatas)
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Inicializa os IDs selecionados com os que vieram da tela anterior
    _selectedIds = Set<int>.from(widget.initialSelectedIds);
    _fetchUnits(); // Busca as unidades
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Busca unidades da API usando o ApiService recebido
  Future<void> _fetchUnits() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.apiService.get('/api/farmacias');
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> decodedJson = jsonDecode(response.body);
        setState(() {
          _allUnits =
              decodedJson.map((json) => Unidade.fromJson(json)).toList();
          _filteredUnits = _allUnits; // Inicialmente mostra todas
          _isLoading = false;
        });
      } else {
        String serverMessage =
            'Erro ao buscar unidades (${response.statusCode}).';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData?['message'] != null) {
            serverMessage = errorData['message'];
          }
        } catch (_) {}
        setState(() {
          _errorMessage = serverMessage;
          _isLoading = false;
        });
      }
    } on TimeoutException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Tempo esgotado.';
        _isLoading = false;
      });
      print(e);
    } on http.ClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erro de conexão.';
        _isLoading = false;
      });
      print(e);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erro inesperado.';
        _isLoading = false;
      });
      print(e);
    }
  }

  // Filtra a lista de unidades baseado no texto de busca
  void _filterUnits(String query) {
    final lowerCaseQuery = query.trim().toLowerCase();
    setState(() {
      _filteredUnits = _allUnits.where((unit) {
        return unit.name.toLowerCase().contains(lowerCaseQuery) ||
            unit.city.toLowerCase().contains(lowerCaseQuery) ||
            unit.address.toLowerCase().contains(lowerCaseQuery);
      }).toList();
    });
  }

  // Atualiza o conjunto de IDs selecionados quando um checkbox é marcado/desmarcado
  void _onUnitSelected(bool? isSelected, int unitId) {
    if (isSelected == null) return;
    setState(() {
      if (isSelected) {
        _selectedIds.add(unitId); // Adiciona ao conjunto
      } else {
        _selectedIds.remove(unitId); // Remove do conjunto
      }
    });
    if (kDebugMode) print("IDs Selecionados: $_selectedIds");
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: const Text('Selecionar Unidades',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryBlue,
        foregroundColor: kWhite,
        elevation: 1,
        iconTheme: const IconThemeData(color: kWhite),
        actions: [
          // Botão para confirmar seleção e retornar para tela anterior
          TextButton(
            onPressed: () {
              // Retorna a lista de IDs selecionados para a tela de Registro
              Navigator.pop(context, _selectedIds.toList());
            },
            child: Text('Confirmar (${_selectedIds.length})', // Mostra contagem
                style: const TextStyle(
                    color: kWhite, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Column(
        children: [
          // --- Campo de Busca ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterUnits, // Filtra ao digitar
              decoration: InputDecoration(
                hintText: 'Buscar por nome, cidade ou endereço...',
                hintStyle: const TextStyle(color: kMediumGrey, fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search, color: kMediumGrey, size: 22),
                filled: true,
                fillColor: kLightGrey.withOpacity(0.7), // Fundo levemente cinza
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 12.0, horizontal: 15.0),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none), // Borda arredondada sem linha
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: kMediumGrey, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _filterUnits(''); // Limpa filtro
                        },
                      )
                    : null,
              ),
            ),
          ),
          // --- Divisor ---
          const Divider(height: 1, thickness: 1),

          // --- Conteúdo (Loading, Erro ou Lista) ---
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: kPrimaryBlue))
                : _errorMessage != null
                    ? _buildErrorWidget() // Mostra erro
                    : _buildUnitList(), // Mostra lista de unidades
          ),
        ],
      ),
    );
  }

  // Constrói widget de erro para esta tela
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
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("Tentar Novamente"),
              onPressed: _fetchUnits,
              style: TextButton.styleFrom(foregroundColor: kPrimaryBlue),
            )
          ],
        ),
      ),
    );
  }

  // Constrói a lista de unidades com checkboxes
  Widget _buildUnitList() {
    if (_filteredUnits.isEmpty) {
      return const Center(
          child: Text("Nenhuma unidade encontrada.",
              style: TextStyle(color: kMediumGrey, fontSize: 16)));
    }
    return ListView.builder(
      itemCount: _filteredUnits.length,
      itemBuilder: (context, index) {
        final unidade = _filteredUnits[index];
        final bool isSelected = _selectedIds
            .contains(unidade.id); // Verifica se ID está no conjunto

        return CheckboxListTile(
          title: Text(unidade.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: kDarkGrey)),
          subtitle: Text("${unidade.city} - ${unidade.address}",
              style: const TextStyle(color: kMediumGrey, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          value: isSelected,
          onChanged: (bool? value) {
            _onUnitSelected(
                value, unidade.id); // Chama a função de seleção/desseleção
          },
          activeColor: kPrimaryBlue, // Cor do checkbox marcado
          controlAffinity:
              ListTileControlAffinity.leading, // Checkbox na esquerda
          dense: true,
        );
      },
    );
  }
} // Fim _UnitSelectionScreenState
