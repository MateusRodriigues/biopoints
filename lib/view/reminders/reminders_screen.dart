// lib/view/reminders/reminders_screen.dart (Com funcionalidade de Excluir)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../models/lembrete.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart'; // Importado
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  ApiService? _apiService;
  SharedPreferences? _prefs;
  List<Lembrete> _lembretes = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<int, bool> _isUpdatingStatus = {};
  Map<int, bool> _isDeleting = {}; // Para feedback de UI ao deletar

  Timer? _timer;
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _initializeAndFetchLembretes();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeAndFetchLembretes() async {
    if (!mounted) return;
    _timer?.cancel();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isUpdatingStatus = {};
      _isDeleting = {};
    });
    try {
      _prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _apiService = ApiService(baseUrl: apiBaseUrl, sharedPreferences: _prefs!);

      await _fetchLembretes();

      if (mounted && _errorMessage == null) {
        _startTimer();
      }
    } catch (e) {
      if (kDebugMode)
        print(
            "[RemindersScreen DEBUG] Erro ao inicializar RemindersScreen: $e");
      if (mounted)
        setState(() => _errorMessage = "Erro ao inicializar a tela.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLembretes() async {
    if (_apiService == null) {
      if (mounted) setState(() => _errorMessage = "Serviço API indisponível.");
      return;
    }
    if (!mounted) return;

    bool isInitialLoad = _lembretes.isEmpty && _errorMessage == null;
    if (!isInitialLoad && mounted && _errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    if (mounted && !_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final lembretesList = await _apiService!.getMyLembretes();
      if (!mounted) return;

      _lembretes = lembretesList;
      await _scheduleOrCancelNotificationsForFetchedReminders();

      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }

      if (kDebugMode) {
        print(
            "[RemindersScreen DEBUG] ${_lembretes.length} lembretes carregados.");
        print(
            "[RemindersScreen DEBUG] Verificando notificações pendentes APÓS agendamento/cancelamento...");
        await _notificationService.getPendingNotifications();
      }
    } catch (e) {
      if (kDebugMode)
        print("[RemindersScreen DEBUG] Erro ao buscar lembretes: $e");
      if (mounted) {
        setState(
            () => _errorMessage = e.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _scheduleOrCancelNotificationsForFetchedReminders() async {
    if (!mounted) return;

    if (kDebugMode) {
      print(
          "[RemindersScreen DEBUG] Processando ${_lembretes.length} lembretes para agendamento/cancelamento de notificações.");
    }

    for (var lembrete in _lembretes) {
      await _notificationService.cancelNotification(lembrete.id);
      // if (kDebugMode) print("[RemindersScreen DEBUG] Notificação ID ${lembrete.id} (se existia) foi cancelada antes de reavaliar.");

      // NOVO LOG ADICIONADO AQUI
      if (kDebugMode) {
        print(
            "[RemindersScreen DEBUG] Avaliando Lembrete ID: ${lembrete.id}, Status String Recebido: '${lembrete.status}', Getter isAtivo: ${lembrete.isAtivo}, EnviaPush: ${lembrete.enviaPush}");
      }
      // FIM DO NOVO LOG

      if (lembrete.isAtivo && lembrete.enviaPush) {
        DateTime scheduledTimeApi = lembrete.proximaOcorrencia;
        DateTime notificationTimeDeviceLocal = scheduledTimeApi.toLocal();

        // if (kDebugMode) {
        //     print("[RemindersScreen DEBUG] Para Lembrete ID: ${lembrete.id}");
        //     print("  > API proximaOcorrencia (raw): ${lembrete.proximaOcorrencia} (isUtc: ${lembrete.proximaOcorrencia.isUtc})");
        //     print("  > notificationTimeDeviceLocal (para agendar): $notificationTimeDeviceLocal");
        //     print("  > DateTime.now() (local do dispositivo): ${DateTime.now()}");
        // }

        if (notificationTimeDeviceLocal
            .isAfter(DateTime.now().subtract(const Duration(seconds: 30)))) {
          // if (kDebugMode) {
          //   print("[RemindersScreen DEBUG] AGENDANDO ID: ${lembrete.id} - Mensagem: ${lembrete.mensagem} - Para (Local do Disp.): $notificationTimeDeviceLocal");
          // }
          await _notificationService.scheduleZonedNotification(
            id: lembrete.id,
            title: 'Lembrete BioPoints: ${lembrete.nomeUnidade ?? "BioPoints"}',
            body: lembrete.mensagem,
            scheduledDateTime: notificationTimeDeviceLocal,
            payload: 'lembrete_id_${lembrete.id}',
          );
        } else {
          //  if (kDebugMode) {
          //   print("[RemindersScreen DEBUG] NÃO AGENDANDO ID: ${lembrete.id} - Hora local calculada ($notificationTimeDeviceLocal) já passou ou é muito próxima.");
          // }
        }
      } else {
        //  if (kDebugMode) {
        //     print("[RemindersScreen DEBUG] NÃO AGENDANDO ID: ${lembrete.id} porque (isAtivo: ${lembrete.isAtivo}, enviaPush: ${lembrete.enviaPush}) não são ambos verdadeiros.");
        //   }
      }
    }
  }

  Future<void> _toggleLembreteStatus(Lembrete lembrete) async {
    if (_apiService == null ||
        !mounted ||
        (_isUpdatingStatus[lembrete.id] ?? false)) return;

    String novoStatus = lembrete.isAtivo ? "0" : "1";

    setState(() {
      _isUpdatingStatus[lembrete.id] = true;
    });

    try {
      final response =
          await _apiService!.updateLembreteStatus(lembrete.id, novoStatus);
      if (!mounted) return;

      if (response.statusCode == 204 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Lembrete "${lembrete.mensagem}" ${novoStatus == "1" ? "reativado" : "desativado"} com sucesso.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        if (novoStatus == "0") {
          await _notificationService.cancelNotification(lembrete.id);
          if (kDebugMode) {
            print(
                "[RemindersScreen DEBUG] Lembrete ID ${lembrete.id} desativado (novoStatus=0), notificação cancelada.");
          }
        }
        await _fetchLembretes();
      } else {
        String errorMsg = "Falha ao atualizar status (${response.statusCode})";
        try {
          final responseBody = jsonDecode(response.body);
          errorMsg = responseBody['message'] ?? errorMsg;
        } catch (_) {}
        _showErrorDialog("Erro ao Atualizar", errorMsg);
      }
    } catch (e) {
      if (kDebugMode)
        print(
            "[RemindersScreen DEBUG] Erro ao atualizar status do lembrete: $e");
      if (mounted) {
        _showErrorDialog("Erro de Comunicação",
            "Não foi possível atualizar o status do lembrete.");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus[lembrete.id] = false;
        });
      }
    }
  }

  // ***** NOVA FUNÇÃO PARA EXCLUIR LEMBRETE *****
  Future<void> _deleteLembrete(Lembrete lembrete) async {
    if (_apiService == null || !mounted || (_isDeleting[lembrete.id] ?? false))
      return;

    // Confirmação do usuário
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text(
              'Tem certeza que deseja excluir o lembrete "${lembrete.mensagem}"? Esta ação o desativará permanentemente.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child:
                  Text('Excluir', style: TextStyle(color: Colors.red.shade700)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return; // Usuário cancelou

    setState(() {
      _isDeleting[lembrete.id] = true;
    });

    try {
      final response = await _apiService!.deleteLembrete(lembrete.id);
      if (!mounted) return;

      if (response.statusCode == 204 || response.statusCode == 200) {
        // 204 No Content é o esperado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Lembrete "${lembrete.mensagem}" excluído com sucesso.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Cancelar notificação e remover da lista local
        await _notificationService.cancelNotification(lembrete.id);
        setState(() {
          _lembretes.removeWhere((l) => l.id == lembrete.id);
          if (_lembretes.where((l) => l.isAtivo).isEmpty) {
            _timer
                ?.cancel(); // Para o timer se não houver mais lembretes ativos
          }
        });
      } else {
        String errorMsg = "Falha ao excluir lembrete (${response.statusCode})";
        try {
          final responseBody = jsonDecode(response.body);
          errorMsg = responseBody['message'] ?? errorMsg;
        } catch (_) {}
        _showErrorDialog("Erro ao Excluir", errorMsg);
      }
    } catch (e) {
      if (kDebugMode)
        print("[RemindersScreen DEBUG] Erro ao excluir lembrete: $e");
      if (mounted) {
        _showErrorDialog(
            "Erro de Comunicação", "Não foi possível excluir o lembrete.");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting[lembrete.id] = false;
        });
      }
    }
  }
  // ***** FIM DA NOVA FUNÇÃO *****

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

  void _startTimer() {
    _timer?.cancel();
    bool hasActiveFutureReminders = _lembretes.any((l) =>
        l.isAtivo && l.proximaOcorrencia.toLocal().isAfter(DateTime.now()));
    if (hasActiveFutureReminders) {
      _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (mounted) {
          setState(() {});
        } else {
          t.cancel();
        }
      });
    } else {
      if (kDebugMode)
        print(
            "[RemindersScreen DEBUG] Nenhum lembrete ativo futuro para iniciar o timer.");
    }
  }

  String _getFormattedRemainingTime(DateTime eventTimeDeviceLocal) {
    final now = DateTime.now();
    final difference = eventTimeDeviceLocal.difference(now);

    if (difference.isNegative) {
      return "Ocorrência Passada";
    }

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final days = difference.inDays;
    final hours = twoDigits(difference.inHours % 24);
    final minutes = twoDigits(difference.inMinutes.remainder(60));
    final seconds = twoDigits(difference.inSeconds.remainder(60));

    if (days > 0) {
      return "$days dia(s), $hours:$minutes:$seconds";
    }
    return "$hours:$minutes:$seconds";
  }

  bool _isExpiringSoon(DateTime eventTimeDeviceLocal) {
    final now = DateTime.now();
    final difference = eventTimeDeviceLocal.difference(now);
    return !difference.isNegative && difference < const Duration(hours: 12);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Meus Lembretes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kPrimaryBlue,
        foregroundColor: kWhite,
        elevation: 1,
        iconTheme: const IconThemeData(color: kWhite),
      ),
      backgroundColor: kVeryLightGrey,
      body: RefreshIndicator(
        onRefresh: _initializeAndFetchLembretes,
        color: kPrimaryBlue,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: kPrimaryBlue));
    }
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    final displayableLembretes = List<Lembrete>.from(_lembretes);
    displayableLembretes.sort((a, b) {
      bool aIsActiveFuture =
          a.isAtivo && a.proximaOcorrencia.toLocal().isAfter(DateTime.now());
      bool bIsActiveFuture =
          b.isAtivo && b.proximaOcorrencia.toLocal().isAfter(DateTime.now());
      if (aIsActiveFuture && !bIsActiveFuture) return -1;
      if (!aIsActiveFuture && bIsActiveFuture) return 1;

      int dateCompare = a.proximaOcorrencia.compareTo(b.proximaOcorrencia);
      if (dateCompare != 0) return dateCompare;
      return a.id.compareTo(b.id);
    });

    if (displayableLembretes.isEmpty) {
      return _buildEmptyListWidget();
    }
    return _buildLembreteList(displayableLembretes);
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.red.shade600, size: 50),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: kDarkGrey, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("Tentar Novamente"),
              onPressed: _initializeAndFetchLembretes,
              style: ElevatedButton.styleFrom(
                  backgroundColor: kDarkGrey, foregroundColor: kWhite),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.alarm_off_rounded,
                      color: kMediumGrey.withOpacity(0.7), size: 70),
                  const SizedBox(height: 20),
                  Text(
                    'Nenhum lembrete cadastrado para você.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, color: kMediumGrey),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Os vendedores podem adicionar lembretes para seus medicamentos aqui.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: kMediumGrey.withOpacity(0.8),
                          height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildLembreteList(List<Lembrete> lembretesToShow) {
    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: lembretesToShow.length,
      itemBuilder: (context, index) {
        final lembrete = lembretesToShow[index];
        final bool isAtivo = lembrete.isAtivo;
        final bool isUpdatingThis = _isUpdatingStatus[lembrete.id] ?? false;
        final bool isDeletingThis =
            _isDeleting[lembrete.id] ?? false; // Novo estado

        final DateTime proximaOcorrenciaLocal =
            lembrete.proximaOcorrencia.toLocal();
        String timeLeftDisplay;
        Color timeLeftColor = kDarkGrey;
        bool showAsExpiringSoon = false;

        if (!isAtivo) {
          timeLeftDisplay = "Desativado";
          timeLeftColor = kMediumGrey;
        } else {
          if (proximaOcorrenciaLocal.isBefore(DateTime.now())) {
            timeLeftDisplay = "Ocorrência Passada";
            timeLeftColor = kMediumGrey;
          } else {
            timeLeftDisplay =
                _getFormattedRemainingTime(proximaOcorrenciaLocal);
            showAsExpiringSoon = _isExpiringSoon(proximaOcorrenciaLocal);
            if (timeLeftDisplay.toLowerCase().contains("passada") ||
                timeLeftDisplay.toLowerCase().contains("expirado")) {
              timeLeftColor = Colors.orange.shade800;
            } else if (showAsExpiringSoon) {
              timeLeftColor = Colors.orange.shade800;
            }
          }
        }

        return Card(
          elevation: isAtivo ? 2.5 : 0.7,
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(
              color: isAtivo
                  ? kPrimaryBlue.withOpacity(0.4)
                  : Colors.grey.shade300,
              width: isAtivo ? 1.2 : 0.7,
            ),
          ),
          color: isAtivo ? kWhite : kLightGrey.withOpacity(0.6),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                16.0, 16.0, 8.0, 16.0), // Ajuste no padding direito
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isAtivo
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_rounded,
                      color: isAtivo ? kAccentBlue : kMediumGrey,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lembrete.mensagem,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isAtivo
                                  ? kDarkGrey
                                  : kMediumGrey.withOpacity(0.8),
                              decoration: isAtivo
                                  ? TextDecoration.none
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          if (lembrete.nomeUnidade != null &&
                              lembrete.nomeUnidade!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Origem: ${lembrete.nomeUnidade}",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isAtivo
                                      ? kMediumGrey
                                      : kMediumGrey.withOpacity(0.7)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Container para os botões de ação (Switch e Excluir)
                    SizedBox(
                      width: 100, // Largura para acomodar os dois ícones/ações
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (lembrete.enviaPush &&
                              !isDeletingThis) // Não mostra switch se estiver deletando
                            isUpdatingThis
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.0, color: kPrimaryBlue))
                                : Transform.scale(
                                    scale: 0.80,
                                    alignment: Alignment.center,
                                    child: Switch(
                                      value: isAtivo,
                                      onChanged: (bool value) {
                                        _toggleLembreteStatus(lembrete);
                                      },
                                      activeColor: kPrimaryBlue,
                                      inactiveThumbColor: Colors.grey.shade400,
                                      inactiveTrackColor: Colors.grey.shade300,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                          if (isDeletingThis)
                            const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.0, color: kErrorRed))
                          else if (!isUpdatingThis) // Só mostra excluir se não estiver atualizando status
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(Icons.delete_outline_rounded,
                                  color: Colors.red.shade600, size: 24),
                              tooltip: 'Excluir Lembrete',
                              onPressed: () => _deleteLembrete(lembrete),
                            ),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                    Icons.calendar_today_outlined,
                    "Próxima Ocorrência:",
                    lembrete.formattedProximaOcorrencia,
                    isAtivo),
                _buildDetailRow(Icons.repeat_rounded, "Frequência:",
                    lembrete.cicloDescricao, isAtivo),
                _buildDetailRow(Icons.timer_outlined, "Duração:",
                    lembrete.duracaoDescricao, isAtivo),
                const SizedBox(height: 6),
                if (isAtivo &&
                    proximaOcorrenciaLocal.isAfter(
                        DateTime.now().subtract(const Duration(minutes: 1))))
                  Row(
                    children: [
                      Icon(
                          (showAsExpiringSoon &&
                                  !timeLeftDisplay
                                      .toLowerCase()
                                      .contains("passada") &&
                                  !timeLeftDisplay
                                      .toLowerCase()
                                      .contains("expirado"))
                              ? Icons.warning_amber_rounded
                              : Icons.hourglass_empty_rounded,
                          size: 14,
                          color: timeLeftColor),
                      const SizedBox(width: 5),
                      Text(
                          (timeLeftDisplay.toLowerCase().contains("passada") ||
                                  timeLeftDisplay
                                      .toLowerCase()
                                      .contains("expirado"))
                              ? "Status do Tempo: "
                              : "Tempo Restante: ",
                          style: TextStyle(fontSize: 13, color: kMediumGrey)),
                      Text(timeLeftDisplay,
                          style: TextStyle(
                              fontSize: 13,
                              color: timeLeftColor,
                              fontWeight: (showAsExpiringSoon &&
                                      !timeLeftDisplay
                                          .toLowerCase()
                                          .contains("passada") &&
                                      !timeLeftDisplay
                                          .toLowerCase()
                                          .contains("expirado"))
                                  ? FontWeight.bold
                                  : FontWeight.w500)),
                      if (showAsExpiringSoon &&
                          !timeLeftDisplay.toLowerCase().contains("passada") &&
                          !timeLeftDisplay.toLowerCase().contains("expirado"))
                        Text(" (expirando)",
                            style: TextStyle(
                                fontSize: 12,
                                color: timeLeftColor,
                                fontStyle: FontStyle.italic))
                    ],
                  ),
                const SizedBox(height: 6),
                Text(
                  "Criado em: ${lembrete.formattedDataCriacao}",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, bool isAtivo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 15,
              color: isAtivo ? kMediumGrey : kMediumGrey.withOpacity(0.6)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontSize: 13,
                color: isAtivo ? kMediumGrey : kMediumGrey.withOpacity(0.8),
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 13,
                  color: isAtivo ? kDarkGrey : kMediumGrey.withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }
}
