// Türkçe harf düzeltme (deasciifier): "cay ikrami" → "çay ikramı".
// Algorithmus und Muster: Dr. Deniz Yuret, Emacs Turkish Extension; JS-Port Mustafa Emre Acer
// (npm "turkish-deasciifier", ISC). Läuft komplett offline.
import 'dart:convert';

import 'package:flutter/services.dart';

class Turkce {
  static Map<String, Map<String, int>>? _patterns;
  static const _size = 10;
  static const _alist = {'c': 'ç', 'C': 'Ç', 'g': 'ğ', 'G': 'Ğ', 'i': 'ı', 'I': 'İ', 'o': 'ö', 'O': 'Ö', 's': 'ş', 'S': 'Ş', 'u': 'ü', 'U': 'Ü'};
  static final Map<String, String> _asciify = {for (final e in _alist.entries) e.value: e.key};
  static final Map<String, String> _down = () {
    final m = <String, String>{};
    for (var c = 97; c <= 122; c++) {
      final ch = String.fromCharCode(c);
      m[ch] = ch;
      m[ch.toUpperCase()] = ch;
    }
    for (final e in _alist.entries) {
      m[e.value] = e.key.toLowerCase();
    }
    return m;
  }();
  static final Map<String, String> _upAcc = () {
    final m = <String, String>{};
    for (var c = 97; c <= 122; c++) {
      final ch = String.fromCharCode(c);
      m[ch] = ch;
      m[ch.toUpperCase()] = ch;
    }
    for (final e in _alist.entries) {
      m[e.value] = e.key.toUpperCase();
    }
    m['i'] = 'i';
    m['I'] = 'I';
    m['İ'] = 'i';
    m['ı'] = 'I';
    return m;
  }();

  static Future<void> _load() async {
    if (_patterns != null) return;
    final raw = jsonDecode(await rootBundle.loadString('assets/deasciify.json')) as Map<String, dynamic>;
    _patterns = {
      for (final e in raw.entries) e.key: {for (final p in (e.value as Map<String, dynamic>).entries) p.key: (p.value as num).toInt()}
    };
  }

  /// Wandelt ohne türkische Tastatur geschriebenen Text um. Bereits getippte Sonderzeichen bleiben.
  static Future<String> duzelt(String text) async {
    if (text.isEmpty) return text;
    await _load();
    final t = text.split('');
    for (var i = 0; i < t.length; i++) {
      final ch = t[i];
      if (_asciify.containsKey(ch)) continue; // schon türkisch getippt (z. B. ö, ü)
      if (!_alist.containsKey(ch)) continue;
      final pl = _patterns![ch.toLowerCase()];
      if (pl == null) continue;
      final m = _match(t, i, pl);
      final need = ch == 'I' ? !m : m;
      if (need) t[i] = _alist[ch]!;
    }
    return t.join();
  }

  static bool _match(List<String> t, int pos, Map<String, int> dlist) {
    var rank = dlist.length * 2;
    final str = _context(t, pos);
    final len = str.length;
    for (var start = 0; start <= _size; start++) {
      for (var end = _size + 1; end <= len; end++) {
        if (start >= end) continue;
        final r = dlist[str.substring(start, end)];
        if (r != null && r != 0 && r.abs() < rank.abs()) rank = r;
      }
    }
    return rank > 0;
  }

  static String _context(List<String> t, int pos) {
    final s = List<String>.filled(2 * _size + 1, ' ');
    s[_size] = 'X';
    var i = _size + 1;
    var space = false;
    var index = pos + 1;
    while (i < s.length && !space && index < t.length) {
      final x = _down[t[index]];
      if (x == null) {
        if (space) {
          i++;
        } else {
          space = true;
        }
      } else {
        s[i] = x;
        space = false;
      }
      i++;
      index++;
    }
    final head = s.sublist(0, i.clamp(0, s.length));
    i = _size - 1;
    space = false;
    index = pos - 1;
    while (i >= 0 && index >= 0) {
      final x = _upAcc[t[index]];
      if (x == null) {
        if (space) {
          i--;
        } else {
          space = true;
        }
      } else {
        head[i] = x;
        space = false;
      }
      i--;
      index--;
    }
    return head.join();
  }
}
