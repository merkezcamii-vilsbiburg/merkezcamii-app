// Lokal-Yöneticiler: Beim Öffnen der App am Lokal fragen, ob das Lokal geöffnet werden soll.
// Nur Standort „während der Nutzung“ – kein Hintergrund-Standort. Der Standort verlässt das Telefon nicht.
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';
import 'theme.dart';

const lokalLat = 48.4506277, lokalLng = 12.3554498; // Frontenhausener Str. 23, Vilsbiburg
const _radius = 150.0; // Meter
const _prefKey = 'lokal_konum_sor';

bool _busy = false;

Future<bool> lokalKonumAcik() async => (await SharedPreferences.getInstance()).getBool(_prefKey) ?? false;

/// Einstellung an/aus. Beim Einschalten wird die Standort-Berechtigung angefragt.
Future<String?> setLokalKonum(bool on) async {
  final sp = await SharedPreferences.getInstance();
  if (on) {
    if (!await Geolocator.isLocationServiceEnabled()) return 'Telefonun konum servisi kapalı.';
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      return 'Konum izni verilmedi. Telefon ayarlarından izin verebilirsiniz.';
    }
  }
  await sp.setBool(_prefKey, on);
  return null;
}

/// Aufruf beim Start und wenn die App wieder in den Vordergrund kommt.
Future<void> checkLokalArrival(BuildContext context) async {
  if (_busy) return;
  final app = AppState.i;
  if (!app.isAdmin('lokal') || app.lokalOpen) return;
  final sp = await SharedPreferences.getInstance();
  if (!(sp.getBool(_prefKey) ?? false)) return;
  final last = sp.getInt('lokal_konum_son') ?? 0;
  if (DateTime.now().millisecondsSinceEpoch - last < const Duration(hours: 3).inMilliseconds) return;
  _busy = true;
  try {
    final perm = await Geolocator.checkPermission();
    if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) return;
    if (!await Geolocator.isLocationServiceEnabled()) return;
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
    );
    if (pos.accuracy > 120) return; // zu ungenau – lieber nicht fragen
    final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, lokalLat, lokalLng);
    if (d > _radius) return;
    await app.refresh(); // Kilit-Zustand frisch prüfen
    if (app.lokalOpen || !context.mounted) return;
    await sp.setInt('lokal_konum_son', DateTime.now().millisecondsSinceEpoch);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: line)),
        title: Text('Lokaldesiniz', style: marcellus(24, color: gold)),
        content: Text('Lokali açayım mı? Herkese "lokal açık" bildirimi gider.', style: manrope(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Hayır', style: manrope(16, color: muted))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('AÇ', style: manrope(17, w: 800, color: openGreen))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await app.setLokalOpen(true);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Lokal açılamadı.')));
        }
      }
    }
  } catch (_) {
    // kein Standort / Zeitüberschreitung – still ignorieren
  } finally {
    _busy = false;
  }
}
