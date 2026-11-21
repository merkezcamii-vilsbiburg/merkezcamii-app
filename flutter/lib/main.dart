import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin.dart';
import 'brand.dart';
import 'data.dart';
import 'extras.dart';
import 'islamic.dart';
import 'notify.dart';
import 'pages.dart';
import 'prices.dart';
import 'settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await AppState.i.init();
  // Ramazan-/Kurban-Korrektur aus den Einstellungen übernehmen und Bildirimler neu planen
  String lastKey = '';
  AppState.i.onSettings = () {
    final r = AppState.i.setting('ramazan_baslangic'), k = AppState.i.setting('kurban_bayrami');
    final key = '$r|$k';
    if (key == lastKey) return;
    lastKey = key;
    Islamic.applySettings(r, k);
    scheduleEzans();
  };
  await initNotifications((tab) {
    AppState.i.openTab = tab;
    AppState.i.ui();
  });
  runApp(const MerkezCamiiApp());
  // Hintergrund-Dienste nach dem Start
  unawaited(initPush());
  unawaited(scheduleEzans());
}

class MerkezCamiiApp extends StatelessWidget {
  const MerkezCamiiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Merkez Camii',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bg,
          colorScheme: const ColorScheme.dark(primary: gold, surface: bg),
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          textSelectionTheme: const TextSelectionThemeData(cursorColor: gold, selectionHandleColor: gold),
        ),
        home: const Root(),
      );
}

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool splashDone = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: bg,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: splashDone
              ? const MainScreen(key: ValueKey('main'))
              : Splash(key: const ValueKey('splash'), onDone: () => setState(() => splashDone = true)),
        ),
      );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int tab = 0;
  Timer? t1, t2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    app.addListener(_onApp);
    app.refresh();
    app.refreshMatches();
    t1 = Timer.periodic(const Duration(seconds: 30), (_) => app.refresh());
    t2 = Timer.periodic(const Duration(minutes: 2), (_) => app.refreshMatches());
    Future.delayed(const Duration(milliseconds: 1200), requestPermissions);
    _onApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    app.removeListener(_onApp);
    t1?.cancel();
    t2?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      app.refresh();
      scheduleEzans();
    }
  }

  void _onApp() {
    final o = app.openTab;
    if (o != null) {
      app.openTab = null;
      setState(() => tab = o);
      app.refresh();
    }
    if (app.loaded) {
      if (tab == 1) app.markSeen('cami');
      if (tab == 2) app.markSeen('lokal');
    }
    if (mounted) setState(() {});
  }

  void _select(int i) {
    setState(() => tab = i);
    _onApp();
  }

  Widget _page() {
    switch (tab) {
      case 1:
        return const DuyurularPage(key: ValueKey(1));
      case 2:
        return const LokalPage(key: ValueKey(2));
      case 3:
        return const HakkimizdaPage(key: ValueKey(3));
      default:
        return const VakitlerPage(key: ValueKey(0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlayOpen = app.compose != null || app.showAdmin || app.showManage || app.showInfoEdit || app.showQibla || app.showSettings || app.showPriceEdit;
    return PopScope(
      canPop: tab == 0 && !overlayOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !overlayOpen && tab != 0) _select(0);
      },
      child: Stack(children: [
        const Positioned.fill(child: BrandBackground()),
        Positioned.fill(
          child: AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: _page()),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: TabBar4(selected: tab, onSelect: _select)),
        if (app.compose != null)
          Positioned.fill(
            child: ComposeScreen(
              section: app.compose!,
              onClose: () {
                app.compose = null;
                app.ui();
              },
            ),
          ),
        if (app.showAdmin)
          Positioned.fill(
            child: AdminGate(onClose: () {
              app.showAdmin = false;
              app.ui();
            }),
          ),
        if (app.showInfoEdit)
          Positioned.fill(
            child: InfoEditScreen(onClose: () {
              app.showInfoEdit = false;
              app.ui();
            }),
          ),
        if (app.showPriceEdit)
          Positioned.fill(
            child: PriceEditScreen(onClose: () {
              app.showPriceEdit = false;
              app.ui();
            }),
          ),
        if (app.showSettings)
          Positioned.fill(
            child: SettingsScreen(onClose: () {
              app.showSettings = false;
              app.ui();
            }),
          ),
        if (app.showQibla)
          Positioned.fill(
            child: QiblaScreen(onClose: () {
              app.showQibla = false;
              app.ui();
            }),
          ),
        if (app.showManage)
          Positioned.fill(
            child: ManageScreen(onClose: () {
              app.showManage = false;
              app.ui();
            }),
          ),
      ]),
    );
  }
}

class TabBar4 extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const TabBar4({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final badges = [0, app.unread('cami'), app.unread('lokal'), 0];
    const labels = ['Vakitler', 'Duyurular', 'Lokal', 'Hakkımızda'];
    final icons = [Ic.clock, Ic.speaker, null, Ic.mosque];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: FadeUp(
            delayMs: 250,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 440, minWidth: MediaQuery.of(context).size.width * 0.94 > 440 ? 440 : MediaQuery.of(context).size.width * 0.94),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.94,
                padding: const EdgeInsets.all(6),
                decoration: glass(r: 22),
                child: Row(children: [
                  for (var i = 0; i < 4; i++) ...[
                    Expanded(child: _item(i, labels[i], icons[i], badges[i])),
                    if (i < 3) const SizedBox(width: 4),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int i, String label, String? svg, int badge) {
    final on = i == selected;
    final c = on ? bg : muted;
    return GestureDetector(
      onTap: () => onSelect(i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          gradient: on ? goldGradient : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 22,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              if (svg != null)
                icon(svg, size: 22, color: c)
              else
                Padding(
                  padding: const EdgeInsets.only(top: 3, bottom: 1),
                  child: Image.asset('assets/img/logo_genclik.png', height: 15, color: c, colorBlendMode: BlendMode.srcIn),
                ),
              if (!on && badge > 0) Positioned(right: -14, top: -6, child: goldBadge(badge)),
            ]),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: manrope(11, w: 600, color: c)),
        ]),
      ),
    );
  }
}
