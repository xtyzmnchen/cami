import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/l10n.dart';
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
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
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
    final locale = store.localeCode == 'en' ? const Locale('en') : const Locale('zh', 'CN');
    return MaterialApp(
      title: store.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: camiTheme(),
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
      localizationsDelegates: const [
        AppL10nDelegate(),
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

  void _pull() {
    if (!mounted) return;
    final store = context.read<Store>();
    if (store.isLoggedIn) store.syncPull();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
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
                title: Text(['', s.calendar, s.pointsBook, s.summary][index]),
                actions: [
                  if (index == 3)
                    IconButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusPage())),
                      icon: const Icon(Icons.timer_outlined, color: CamiColors.roseDeep),
                      tooltip: s.pomodoro,
                    ),
                ],
              ),
        body: SafeArea(
          top: index == 0,
          child: pages[index],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) {
            setState(() => index = value);
            _pull(); // 点底部 tab 同步云端
          },
          destinations: [
            NavigationDestination(
              icon: _TabIcon(CamiAssets.tabToday, selected: false),
              selectedIcon: _TabIcon(CamiAssets.tabToday, selected: true),
              label: s.tabToday,
            ),
            NavigationDestination(
              icon: _TabIcon(CamiAssets.tabCalendar, selected: false),
              selectedIcon: _TabIcon(CamiAssets.tabCalendar, selected: true),
              label: s.tabCalendar,
            ),
            NavigationDestination(
              icon: _TabIcon(CamiAssets.tabPoints, selected: false),
              selectedIcon: _TabIcon(CamiAssets.tabPoints, selected: true),
              label: s.tabPoints,
            ),
            NavigationDestination(
              icon: _TabIcon(CamiAssets.tabSummary, selected: false),
              selectedIcon: _TabIcon(CamiAssets.tabSummary, selected: true),
              label: s.tabSummary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon(this.asset, {required this.selected});
  final String asset;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: selected ? 1 : 0.55,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: selected ? 1.08 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            asset,
            width: selected ? 28 : 24,
            height: selected ? 28 : 24,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
