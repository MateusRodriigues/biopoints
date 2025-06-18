// lib/view/home/navbar_screen.dart
import 'package:biopoints/utils/app_colors.dart';
// import 'package:biopoints/utils/constants.dart'; // publicImageBaseUrl não é mais usado aqui diretamente se o header for simples
import 'package:biopoints/view/home/home_screen.dart'; // Para navegação de Perfil/Favoritos
import 'package:biopoints/view/login/login_screen.dart';
import 'package:biopoints/view/giftback/giftback_screen.dart';
import 'package:biopoints/view/history/transaction_history_screen.dart';
import 'package:biopoints/view/reminders/reminders_screen.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
// import 'dart:math'; // Removido se não usar paisagens aleatórias dos assets

class NavBar extends StatefulWidget {
  const NavBar({super.key});
  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  SharedPreferences? _prefs;
  // String? _selectedLandscapeImage; // Removido se não usar paisagens

  // final List<String> _landscapeImages = [
  //   'assets/images/landscapes/paisagem1.jpg',
  //   'assets/images/landscapes/paisagem2.jpg',
  //   'assets/images/landscapes/paisagem3.jpg',
  // ];

  @override
  void initState() {
    super.initState();
    // _selectRandomLandscape(); // Removido ou ajustado se a lógica de imagem mudar
  }

  // void _selectRandomLandscape() {
  //   if (_landscapeImages.isNotEmpty) {
  //     final random = Random();
  //     _selectedLandscapeImage = _landscapeImages[random.nextInt(_landscapeImages.length)];
  //   }
  // }

  Future<void> _logout() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.clear();

      if (kDebugMode) {
        print(
            "[NavBar Logout] Todos os dados da sessão e preferências foram removidos.");
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (kDebugMode) print("Erro durante o logout: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao sair: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _navigateTo(BuildContext navContext, Widget screen) {
    Navigator.pop(navContext);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        Navigator.push(
            navContext, MaterialPageRoute(builder: (context) => screen));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const itemTextStyle = TextStyle(fontSize: 15, color: kDarkGrey);
    const itemIconColor = kPrimaryBlue;

    // Widget drawerHeaderContent;
    // if (_selectedLandscapeImage != null) {
    //   drawerHeaderContent = Image.asset(
    //     _selectedLandscapeImage!,
    //     fit: BoxFit.cover,
    //     errorBuilder: (context, error, stackTrace) {
    //       return Container(color: kLightBlue.withOpacity(0.6));
    //     },
    //   );
    // } else {
    //   drawerHeaderContent = Container(color: kLightBlue.withOpacity(0.6));
    // }

    return Drawer(
      child: Container(
        color: kWhite,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
                padding: EdgeInsets.zero,
                margin: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: kLightBlue.withOpacity(0.8),
                ),
                child: Stack(
                  children: [
                    // Se você tiver uma imagem de paisagem padrão para colocar aqui
                    // Positioned.fill(
                    //   child: Image.asset(
                    //     'assets/images/default_landscape.jpg', // CRIE ESTE ASSET
                    //     fit: BoxFit.cover,
                    //   ),
                    // ),
                    Positioned(
                        bottom: 12.0,
                        left: 16.0,
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/logo_branca.png',
                              height: 30,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.eco,
                                      color: kPrimaryBlue.withOpacity(0.7),
                                      size: 30),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "BioPoints",
                              style: TextStyle(
                                  color: kPrimaryBlue.withOpacity(0.9),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                        blurRadius: 1.0,
                                        color: Colors.white.withOpacity(0.5),
                                        offset: Offset(0, 1))
                                  ]),
                            ),
                          ],
                        )),
                  ],
                )),
            // Opção "Home" REMOVIDA
            // const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16), // Divisor opcional

            // Grupos "Farmácias" e "Produtos" REMOVIDOS
            // Opções "Meus Vouchers" e "Campanhas de Parceiros" REMOVIDAS

            _buildListTile(Icons.redeem_outlined, 'Meus Giftbacks',
                itemIconColor, itemTextStyle, () {
              _navigateTo(context, const GiftbackScreen());
            }),
            _buildListTile(Icons.history_edu_outlined, 'Extrato de Pontos',
                itemIconColor, itemTextStyle, () {
              _navigateTo(context, const TransactionHistoryScreen());
            }),
            _buildListTile(
                Icons.alarm_outlined, 'Lembretes', itemIconColor, itemTextStyle,
                () {
              _navigateTo(context, const RemindersScreen());
            }),
            const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
            _buildListTile(Icons.account_circle_outlined, 'Meu Perfil',
                itemIconColor, itemTextStyle, () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) => const HomePage(
                          initialPageIndex: 2)), // Leva para a aba de Perfil
                  (route) => false);
            }),
            _buildListTile(Icons.exit_to_app_outlined, 'Sair', itemIconColor,
                itemTextStyle, _logout),
          ],
        ),
      ),
    );
  }

  // _buildExpansionTile não é mais necessário se os grupos foram removidos
  // ExpansionTile _buildExpansionTile( ... ) { ... }

  ListTile _buildListTile(IconData icon, String title, Color iconColor,
      TextStyle textStyle, VoidCallback onTap) {
    return ListTile(
        leading: Icon(icon, color: iconColor, size: 24),
        title: Text(title, style: textStyle),
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 28.0),
        visualDensity: VisualDensity.compact);
  }
}
