import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'pages/auth_page.dart';
import 'pages/calendar_page.dart';
import 'pages/focus_page.dart';
import 'pages/home.dart';
import 'pages/parent_page.dart';
import 'pages/points_page.dart';
import 'services/notify.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alerts.init();
  final store = Store();
  await store.load();
  runApp(ChangeNotifierProvider.value(value: store, child: const CamiApp()));
}

class CamiApp extends StatefulWidget {
  const CamiApp({super.key});

  @override
  State<CamiApp> createState() => _CamiAppState();
}

class _CamiAppState extends State<CamiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final path in [
        CamiAssets.roseBg,
        CamiAssets.roseFlower,
        CamiAssets.rosePale,
        CamiAssets.roseBadge,
      ]) {
        precacheImage(AssetImage(path), context);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final store = context.read<Store>();
      if (store.isLoggedIn) store.syncPull();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return MaterialApp(
      title: '小皇冠',
      debugShowCheckedModeBanner: false,
      theme: camiTheme(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: !store.isLoggedIn
          ? const AuthPage()
          : (store.parentMode ? const ParentShell() : const Shell()),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  var index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const CalendarPage(),
      const PointsPage(),
      const SummaryPage(),
    ];
    return RoseBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: index == 0
            ? null
            : AppBar(
                backgroundColor: Colors.transparent,
                title: Text(['', '月历', '积分册', '总结'][index]),
                actions: [
                  if (index == 3)
                    IconButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusPage())),
                      icon: const Icon(Icons.timer_outlined, color: CamiColors.roseDeep),
                    ),
                ],
              ),
        body: SafeArea(
          top: index == 0,
          child: pages[index],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: [
            NavigationDestination(
              icon: Opacity(opacity: 0.55, child: Image.asset(CamiAssets.roseFlower, width: 22, height: 22)),
              selectedIcon: Image.asset(CamiAssets.roseFlower, width: 24, height: 24),
              label: '今日',
            ),
            const NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: '日历'),
            NavigationDestination(
              icon: Opacity(opacity: 0.55, child: Image.asset(CamiAssets.roseBadge, width: 22, height: 22)),
              selectedIcon: Image.asset(CamiAssets.roseBadge, width: 24, height: 24),
              label: '积分',
            ),
            const NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: '总结'),
          ],
        ),
      ),
    );
  }
}
