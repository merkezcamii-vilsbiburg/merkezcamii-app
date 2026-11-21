import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'brand.dart';
import 'notify.dart';
import 'pages.dart';
import 'theme.dart';

/// Ezan-Vorschau (bis eigene Aufnahmen kommen: freesound.org, CC BY)
const ezanUrls = {
  'sabah': 'https://cdn.freesound.org/previews/28/28775_5726-hq.mp3',
  'normal': 'https://cdn.freesound.org/previews/255/255231_4232604-hq.mp3',
};

/// Zahnrad oben rechts auf der Vakitler-Seite
Widget gearButton() => GestureDetector(
      onTap: () {
        app.showSettings = true;
        app.ui();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: line),
        ),
        alignment: Alignment.center,
        child: icon(Ic.gear, size: 21, color: textC.withValues(alpha: 0.85)),
      ),
    );

class SettingsScreen extends StatefulWidget {
  final VoidCallback onClose;
  const SettingsScreen({super.key, required this.onClose});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SharedPreferences? p;
  final player = AudioPlayer();
  String? playing; // 'sabah' | 'normal'
  bool loadingAudio = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((v) => setState(() => p = v));
    player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => playing = null);
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> _set(String key, Object v, {bool reschedule = true}) async {
    if (v is String) await p!.setString(key, v);
    if (v is bool) await p!.setBool(key, v);
    setState(() {});
    if (reschedule) await scheduleEzans();
  }

  Future<void> _play(String which) async {
    if (playing == which) {
      await player.stop();
      setState(() => playing = null);
      return;
    }
    setState(() {
      loadingAudio = true;
      playing = which;
    });
    try {
      await player.stop();
      await player.play(UrlSource(ezanUrls[which]!));
    } catch (_) {
      if (mounted) {
        toast(context, 'Ezan çalınamadı. İnternet bağlantısını kontrol edin.');
        setState(() => playing = null);
      }
    }
    if (mounted) setState(() => loadingAudio = false);
  }

  void _close() {
    player.stop();
    widget.onClose();
  }

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title, style: manrope(12, w: 700, color: gold, ls: 2)),
          ),
          glassBox(r: 22, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Column(children: children)),
        ]),
      );

  Widget _modeChip(String label, bool on, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: on ? goldGradient : null,
            color: on ? null : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? Colors.transparent : line),
          ),
          alignment: Alignment.center,
          child: Text(label, maxLines: 1, style: manrope(12, w: 700, color: on ? bg : muted)),
        ),
      );

  Widget _toggle(String title, String sub, bool on, ValueChanged<bool> onChange) => InkWell(
        onTap: () => onChange(!on),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: manrope(15, w: 600)),
                if (sub.isNotEmpty) Text(sub, style: manrope(12, color: muted)),
              ]),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 26,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: on ? goldGradient : null,
                color: on ? null : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, color: on ? bg : textC),
              ),
            ),
          ]),
        ),
      );

  Widget _playRow(String which, String label) {
    final on = playing == which;
    return GestureDetector(
      onTap: () => _play(which),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: on ? goldGradient : null, border: Border.all(color: on ? Colors.transparent : line)),
            alignment: Alignment.center,
            child: on && loadingAudio
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: bg))
                : Text(on ? '■' : '▶', style: TextStyle(fontSize: on ? 14 : 16, color: on ? bg : gold)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: manrope(15, w: 600))),
          if (on) Text('Çalıyor', style: manrope(12, w: 700, color: gold)),
        ]),
      ),
    );
  }

  Widget _helpRow(String emoji, String title, String sub, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: manrope(15, w: 600)),
                Text(sub, style: manrope(12, color: muted)),
              ]),
            ),
            Text('›', style: manrope(22, color: gold)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = this.p;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Material(
        color: bg,
        child: Stack(children: [
          const Positioned.fill(child: BrandBackground()),
          SafeArea(
            child: p == null
                ? const SizedBox.shrink()
                : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(children: [
                        Expanded(child: Text('Ayarlar', style: marcellus(25))),
                        GestureDetector(
                          onTap: _close,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: line)),
                            alignment: Alignment.center,
                            child: const Text('✕', style: TextStyle(fontSize: 18, color: textC)),
                          ),
                        ),
                      ]),
                    ),

                    // 1) Ezan pro Vakit
                    _section('EZAN', [
                      for (final k in EzanSettings.keys)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            SizedBox(width: 62, child: Text(EzanSettings.labels[k]!, style: manrope(14, w: 600))),
                            for (final m in const [
                              ['ezan', 'Ezan'],
                              ['bildirim', 'Bildirim'],
                              ['kapali', 'Kapalı']
                            ]) ...[
                              Expanded(child: _modeChip(m[1], EzanSettings.mode(p, k) == m[0], () => _set('mode_$k', m[0]))),
                              if (m[0] != 'kapali') const SizedBox(width: 6),
                            ],
                          ]),
                        ),
                      Container(margin: const EdgeInsets.symmetric(vertical: 6), height: 1, color: line),
                      _toggle('Sessiz modda da ezan oku', 'Kapalıyken telefon sessizdeyse sadece bildirim gelir',
                          EzanSettings.silentToo(p), (v) => _set('silentToo', v)),
                    ]),

                    // 2) Ezan dinle
                    _section('EZANI DİNLE', [
                      _playRow('sabah', 'Sabah ezanı'),
                      Container(height: 1, color: line),
                      _playRow('normal', 'Ezan (öğle, ikindi, akşam, yatsı)'),
                    ]),

                    // 3) Hatırlatmalar
                    _section('HATIRLATMALAR', [
                      _toggle('Cuma hatırlatması', 'Cuma günü öğleden 45 dk önce', EzanSettings.cuma(p), (v) => _set('cuma', v)),
                    ]),

                    // 4) Duyuru-Bildirimleri
                    _section('DUYURU BİLDİRİMLERİ', [
                      _toggle('Cami duyuruları', 'Yeni cami duyurusu gelince bildirim', p.getBool('push_cami') ?? true, (v) async {
                        await setTopic('cami', v);
                        setState(() {});
                      }),
                      Container(height: 1, color: line),
                      _toggle('Gençlik / Lokal', 'Gençlik duyuruları ve lokal maçları', p.getBool('push_lokal') ?? true, (v) async {
                        await setTopic('lokal', v);
                        setState(() {});
                      }),
                    ]),

                    // 5) Hilfe
                    _section('BİLDİRİMLER ÇALIŞMIYORSA', [
                      _helpRow('🔔', 'Bildirim izni', 'Uygulamanın bildirim göstermesine izin verin',
                          () => AppSettings.openAppSettings(type: AppSettingsType.notification)),
                      if (Platform.isAndroid) ...[
                        Container(height: 1, color: line),
                        _helpRow('🔋', 'Pil ayarı', '"Kısıtlanmamış" seçin, ezan ve bildirimler kaçmasın',
                            () => AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization)),
                      ],
                    ]),

                    const SizedBox(height: 10),
                    Text('Merkez Camii Vilsbiburg · Sürüm 1.2', textAlign: TextAlign.center, style: manrope(12, color: muted)),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Ezan kayıtları: sazman, RJStefanski (freesound.org, CC BY)',
                          textAlign: TextAlign.center, style: manrope(10.5, color: muted.withValues(alpha: 0.5))),
                    ),
                  ]),
          ),
        ]),
      ),
    );
  }
}
