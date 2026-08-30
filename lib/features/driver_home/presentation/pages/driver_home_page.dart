import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/core/constants/api_constants.dart';
import '../../application/driver_home_provider.dart';
import '../tabs/driver_profile_tab.dart';
import '../tabs/driver_route_tab.dart';
import '../tabs/driver_financial_tab.dart';
import '../tabs/driver_messages_tab.dart';
import '../tabs/driver_opportunities_tab.dart';
import '../../../../features/auth/application/auth_state_provider.dart';
import '../../../../app/theme/app_colors.dart';

class DriverHomePage extends ConsumerStatefulWidget {
  const DriverHomePage({super.key});

  @override
  ConsumerState<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends ConsumerState<DriverHomePage> {
  int _currentTab = 1; // Start on Rota tab

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkProfileComplete());
  }

  Future<void> _checkProfileComplete() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = Dio();
      final response = await dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.driversProfile}',
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        ),
      );
      if (response.data is Map && response.data['success'] == true) {
        final driver = response.data['data'] ?? response.data;
        final cnhUrl  = driver['cnh_url']  as String? ?? '';
        final crlvUrl = driver['crlv_url'] as String? ?? '';
        final whatsapp = driver['whatsapp'] as String? ?? '';
        final municipio = driver['pref_municipio_id'];

        final incompleto = cnhUrl.isEmpty || crlvUrl.isEmpty
            || whatsapp.isEmpty || municipio == null;

        if (incompleto && mounted) _showCompleteProfileNotice();
      }
    } catch (_) {
      // Silently ignore — não bloqueia o app
    }
  }

  void _showCompleteProfileNotice() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('👋 Bem-vindo ao Rota Escolar!'),
        content: const Text(
          'Seu cadastro ainda está incompleto.\n\n'
          'Para aparecer na busca dos responsáveis, preencha pelo menos:\n'
          '• Localização e bairros que atende\n'
          '• WhatsApp\n'
          '• CNH e CRLV\n\n'
          'Leva poucos minutos e você já fica visível na plataforma!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _currentTab = 0);
            },
            child: const Text('Completar agora'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    ref.read(authNotifierProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverHomeProvider);
    final talkCount = driverState.talkRequestCount;
    final user = ref.watch(authNotifierProvider).user;

    const tabs = [
      DriverProfileTab(),
      DriverRouteTab(),
      DriverFinancialTab(),
      DriverMessagesTab(),
      DriverOpportunitiesTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabTitle(_currentTab),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.text,
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  user.nome.split(' ').first,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Ajuda / FAQ',
            onPressed: () => context.push('/faq'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.route_outlined),
            activeIcon: Icon(Icons.route),
            label: 'Rota',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_outlined),
            activeIcon: Icon(Icons.attach_money),
            label: 'Financeiro',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: talkCount > 0,
              label: Text('$talkCount'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            activeIcon: Badge(
              isLabelVisible: talkCount > 0,
              label: Text('$talkCount'),
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'Mensagens',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.group_add_outlined),
            activeIcon: Icon(Icons.group_add),
            label: 'Vagas',
          ),
        ],
      ),
    );
  }

  String _tabTitle(int index) {
    return switch (index) {
      0 => 'Meu Perfil',
      1 => 'Rota do Dia',
      2 => 'Financeiro',
      3 => 'Mensagens',
      4 => 'Oportunidades',
      _ => 'Rota Escolar',
    };
  }
}
