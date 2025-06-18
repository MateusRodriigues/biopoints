// lib/view/home/home_screen.dart
import 'package:biopoints/services/api_service.dart';
import 'package:biopoints/utils/app_colors.dart';
import 'package:biopoints/utils/constants.dart';
import 'package:biopoints/view/home/navbar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../favorites/favorites_screen.dart';
import '../user_profile/user_profile_screen.dart';
import '../pharmacy/my_units_screen.dart';
import '../product/product_search_screen.dart';
import '../voucher/voucher_screen.dart';
import '../campaigns/campanhas_screen.dart';

class HomePage extends StatefulWidget {
  final int initialPageIndex;
  const HomePage({super.key, this.initialPageIndex = 0});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex;

  static const List<Widget> _mainPages = <Widget>[
    HomeScreenContent(),
    FavoritesScreen(),
    UserProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialPageIndex;
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  AppBar _buildAppBar(BuildContext context) {
    if (_selectedIndex == 2) {
      return AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark
            .copyWith(statusBarColor: Colors.transparent),
      );
    }

    String titleText;
    switch (_selectedIndex) {
      case 0:
        titleText = 'BioPoints';
        break;
      case 1:
        titleText = 'Favoritos';
        break;
      default:
        titleText = 'BioPoints';
    }

    return AppBar(
      backgroundColor: kPrimaryBlue,
      foregroundColor: kWhite,
      elevation: 2,
      title: Text(
        titleText,
        style:
            TextStyle(fontWeight: FontWeight.bold, color: kWhite, fontSize: 20),
      ),
      centerTitle: true,
      iconTheme: const IconThemeData(color: kWhite),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _selectedIndex == 2
          ? SystemUiOverlayStyle.dark
              .copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.light.copyWith(statusBarColor: kPrimaryBlue),
      child: Scaffold(
        drawer: const NavBar(),
        appBar: _buildAppBar(context),
        body: IndexedStack(
          index: _selectedIndex,
          children: _mainPages,
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: kWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
              child: GNav(
                rippleColor: kPrimaryBlue.withOpacity(0.1),
                hoverColor: kPrimaryBlue.withOpacity(0.05),
                activeColor: kPrimaryBlue,
                tabBackgroundColor: kLightBlue.withOpacity(0.6),
                color: kMediumGrey,
                gap: 8,
                iconSize: 24,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                duration: const Duration(milliseconds: 400),
                tabs: const [
                  GButton(
                    icon: Icons.home_outlined,
                    text: 'Início',
                  ),
                  GButton(
                    icon: Icons.favorite_border,
                    text: 'Favoritos',
                  ),
                  GButton(
                    icon: Icons.person_outline,
                    text: 'Perfil',
                  ),
                ],
                selectedIndex: _selectedIndex,
                onTabChange: _onBottomNavTapped,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  ApiService? _apiService;
  double? _totalGiftbackValue;
  bool _isLoadingGiftback = true;
  String? _userName;
  final _currencyFormatter =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _initializeAndFetchData();
  }

  Future<void> _initializeAndFetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingGiftback = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _apiService = ApiService(baseUrl: apiBaseUrl, sharedPreferences: prefs);
      _userName = prefs.getString('user_name');

      final total = await _apiService!.getTotalGiftbackValue();
      if (mounted) {
        setState(() {
          _totalGiftbackValue = total;
        });
      }
    } catch (e) {
      print("Erro ao buscar total de giftback: $e");
      if (mounted) {
        setState(() {
          _totalGiftbackValue = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGiftback = false;
        });
      }
    }
  }

  Widget _buildDashboardItem(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 36, color: kPrimaryBlue),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: kDarkGrey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftbackSection() {
    if (_isLoadingGiftback) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: kAccentBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5))),
      );
    }

    if (_totalGiftbackValue == null || _totalGiftbackValue! <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
          color: kSuccessGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kSuccessGreen.withOpacity(0.3))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.savings_outlined, color: kSuccessGreen, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Você possui",
                style: TextStyle(
                  fontSize: 14,
                  // CORREÇÃO: Usando uma cor válida da paleta
                  color: kDarkGrey,
                ),
              ),
              Text(
                _currencyFormatter.format(_totalGiftbackValue),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  // CORREÇÃO: Usando uma cor válida da paleta
                  color: kDarkGrey,
                ),
              ),
              Text(
                "em GIFTBACK para usar!",
                style: TextStyle(
                  fontSize: 14,
                  // CORREÇÃO: Usando uma cor válida da paleta
                  color: kDarkGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _initializeAndFetchData,
      color: kPrimaryBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            Text(
              'Bem-vindo(a), ${_userName ?? 'Cliente'}!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: kDarkGrey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sua plataforma de fidelidade e saúde.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: kMediumGrey, height: 1.4),
            ),
            const SizedBox(height: 24),
            _buildGiftbackSection(),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: <Widget>[
                _buildDashboardItem(
                    context, Icons.storefront_outlined, 'Minhas Farmácias', () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const MyUnitsScreen()));
                }),
                _buildDashboardItem(
                    context, Icons.shopping_bag_outlined, 'Produtos', () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProductSearchScreen()));
                }),
                _buildDashboardItem(
                    context, Icons.card_giftcard_outlined, 'Meus Vouchers', () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const VouchersScreen()));
                }),
                _buildDashboardItem(
                    context, Icons.campaign_outlined, 'Campanhas', () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CampanhasScreen()));
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
