import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const supabaseUrl = 'https://eglsbxlvoqbkdqtyeghb.supabase.co';
const supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVnbHNieGx2b3Fia2RxdHllZ2hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUyNjU3MjAsImV4cCI6MjExMDg0MTcyMH0.vHiUapBqoaiWNqfUlbyCx6yX3K2QuMx_2Q1PcJ4UhVU';

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => message;
}

class Ann {
  final int id;
  final String section, title, body;
  final String? photo, author;
  final DateTime createdAt;
  Ann(this.id, this.section, this.title, this.body, this.photo, this.author, this.createdAt);
}

class Team {
  final String id, name, logo;
  final String? score;
  Team(this.id, this.name, this.logo, this.score);
}

class MatchItem {
  final String id, league, state, clock;
  final DateTime date;
  final Team home, away;
  MatchItem(this.id, this.league, this.date, this.home, this.away, this.state, this.clock);
}

class Donation {
  final int id;
  final String title;
  final double collected, target;
  Donation(this.id, this.title, this.collected, this.target);
}

class AdminEntry {
  final int id;
  final String name;
  final List<String> roles;
  AdminEntry(this.id, this.name, this.roles);
}

// ---------------------------------------------------------------- HTTP

class Backend {
  static Map<String, String> get _h => {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Content-Type': 'application/json',
      };

  static String _err(http.Response r) {
    try {
      final o = jsonDecode(r.body);
      if (o is Map && o['message'] != null) return o['message'].toString();
    } catch (_) {}
    return 'Sunucu hatası (${r.statusCode})';
  }

  static Future<dynamic> get(String path) async {
    final r = await http.get(Uri.parse('$supabaseUrl/rest/v1/$path'), headers: _h).timeout(const Duration(seconds: 20));
    if (r.statusCode < 200 || r.statusCode > 299) throw ApiError(_err(r));
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  /// RPC; Antwort {"error": "..."} wird zu ApiError.
  static Future<dynamic> rpc(String name, Map<String, dynamic> body) async {
    final r = await http
        .post(Uri.parse('$supabaseUrl/rest/v1/rpc/$name'), headers: _h, body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    if (r.statusCode < 200 || r.statusCode > 299) throw ApiError(_err(r));
    final o = jsonDecode(utf8.decode(r.bodyBytes));
    if (o is Map && o['error'] != null && o['error'].toString().isNotEmpty) throw ApiError(o['error'].toString());
    return o;
  }

  static Future<String> upload(String pin, Uint8List bytes) async {
    final r = await http
        .post(Uri.parse('$supabaseUrl/functions/v1/upload'),
            headers: _h, body: jsonEncode({'pin': pin, 'image': base64Encode(bytes)}))
        .timeout(const Duration(seconds: 60));
    if (r.statusCode < 200 || r.statusCode > 299) throw ApiError(_err(r));
    final o = jsonDecode(r.body);
    if (o['error'] != null) throw ApiError(o['error'].toString());
    return o['url'] as String;
  }
}

// ---------------------------------------------------------------- Zustand

class AppState extends ChangeNotifier {
  static final AppState i = AppState._();
  AppState._();

  late SharedPreferences prefs;

  List<Ann> announcements = [];
  Map<String, bool> locks = {};
  Map<String, String> settings = {};
  List<Donation> donations = [];
  List<MatchItem> matches = [];
  Set<String> turkishTeams = {};
  bool matchesLoading = true;
  String? matchesError;
  bool loaded = false;

  String? adminName;
  Set<String> adminRoles = {};
  String? _pin;
  bool _adminChecked = false;

  int seenCami = -1, seenLokal = -1;

  /// Wird aufgerufen, wenn Einstellungen geladen wurden (z. B. Ramazan-Korrektur)
  void Function()? onSettings;

  String setting(String k) => settings[k] ?? '';

  Future<void> setSetting(String key, String value) async {
    await Backend.rpc('set_setting', {'p_pin': pin, 'p_key': key, 'p_value': value});
    settings[key] = value;
    onSettings?.call();
    notifyListeners();
  }

  Future<void> saveDonation(int? id, String title, double collected, double target) async {
    await Backend.rpc('donation_save',
        {'p_pin': pin, 'p_id': id, 'p_title': title, 'p_collected': collected, 'p_target': target});
    await refresh();
  }

  Future<void> deleteDonation(int id) async {
    await Backend.rpc('donation_delete', {'p_pin': pin, 'p_id': id});
    await refresh();
  }

  // UI-Zustand
  int? openTab;
  String? compose;
  bool showAdmin = false, showManage = false, showInfoEdit = false, showQibla = false, showSettings = false;

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    _pin = prefs.getString('pin');
    adminName = prefs.getString('adminName');
    adminRoles = (prefs.getStringList('roles') ?? []).toSet();
    seenCami = prefs.getInt('seen_cami') ?? -1;
    seenLokal = prefs.getInt('seen_lokal') ?? -1;
  }

  void ui() => notifyListeners();

  String get pin => _pin ?? '';
  bool isAdmin(String role) => adminRoles.contains(role);

  List<Ann> list(String section) {
    final l = announcements.where((a) => a.section == section).toList();
    l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return l;
  }

  int _maxId(String s) => announcements.where((a) => a.section == s).fold(0, (p, a) => a.id > p ? a.id : p);

  int unread(String s) {
    final seen = s == 'cami' ? seenCami : seenLokal;
    if (seen < 0) return 0;
    return announcements.where((a) => a.section == s && a.id > seen).length;
  }

  void markSeen(String s) {
    final m = _maxId(s);
    final cur = s == 'cami' ? seenCami : seenLokal;
    if (cur == m) return;
    if (s == 'cami') {
      seenCami = m;
    } else {
      seenLokal = m;
    }
    prefs.setInt('seen_$s', m);
    notifyListeners();
  }

  Future<void> _revalidate() async {
    if (_adminChecked) return;
    if (_pin == null) {
      _adminChecked = true;
      return;
    }
    try {
      final o = await Backend.rpc('admin_login', {'p_pin': _pin});
      adminName = o['name'] as String?;
      adminRoles = ((o['roles'] as List?) ?? []).map((e) => e.toString()).toSet();
      await prefs.setString('adminName', adminName ?? '');
      await prefs.setStringList('roles', adminRoles.toList());
      _adminChecked = true;
    } on ApiError {
      logout();
      _adminChecked = true;
    } catch (_) {/* offline */}
  }

  Future<void> refresh() async {
    await _revalidate();
    try {
      final a = await Backend.get('announcements?select=*&deleted=eq.false&order=created_at.desc&limit=60') as List;
      final l = await Backend.get('match_locks?select=match_id,open') as List;
      announcements = a.map((o) {
        String? s(dynamic v) => (v == null || v.toString().isEmpty) ? null : v.toString();
        return Ann(
          (o['id'] as num).toInt(),
          o['section'] as String,
          (o['title'] ?? '') as String,
          (o['body'] ?? '') as String,
          s(o['photo_url']),
          s(o['author']),
          DateTime.tryParse(o['created_at'] ?? '') ?? DateTime.now(),
        );
      }).toList();
      locks = {for (final x in l) x['match_id'] as String: x['open'] == true};
      try {
        final st = await Backend.get('settings?select=key,value') as List;
        settings = {for (final x in st) x['key'] as String: (x['value'] ?? '').toString()};
        final dn = await Backend.get('donations?select=id,title,collected,target,sort&order=sort.asc,id.asc') as List;
        donations = dn
            .map((x) => Donation((x['id'] as num).toInt(), x['title'] as String, (x['collected'] as num).toDouble(),
                (x['target'] as num).toDouble()))
            .toList();
        onSettings?.call();
      } catch (_) {}
      loaded = true;
      if (seenCami < 0) markSeen('cami');
      if (seenLokal < 0) markSeen('lokal');
    } catch (_) {
      loaded = true;
    }
    notifyListeners();
  }

  // ---------- Maçlar (über Supabase-Funktion, die ESPN Tag für Tag abfragt) ----------
  Future<void> refreshMatches() async {
    try {
      final r = await http
          .get(Uri.parse('$supabaseUrl/functions/v1/matches'), headers: Backend._h)
          .timeout(const Duration(seconds: 40));
      if (r.statusCode != 200) throw ApiError('HTTP ${r.statusCode}');
      final list = (jsonDecode(utf8.decode(r.bodyBytes))['matches'] as List?) ?? [];
      Team team(dynamic t) {
        final sc = t?['score']?.toString();
        return Team((t?['id'] ?? '').toString(), (t?['name'] ?? '?').toString(), (t?['logo'] ?? '').toString(),
            (sc == null || sc.isEmpty || sc == 'null') ? null : sc);
      }

      final now = DateTime.now().toUtc();
      final cutoff = now.subtract(const Duration(hours: 3));
      matches = list
          .map((m) => MatchItem(
                (m['id'] ?? '').toString(),
                (m['league'] ?? 'sl').toString(),
                DateTime.tryParse((m['date'] ?? '').toString()) ?? now,
                team(m['home']),
                team(m['away']),
                (m['state'] ?? 'pre').toString(),
                (m['clock'] ?? '').toString(),
              ))
          .where((m) => !(m.state == 'post' && m.date.isBefore(cutoff)))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      turkishTeams = {
        for (final m in matches.where((m) => m.league == 'sl')) ...[m.home.id, m.away.id]
      };
      matchesError = null;
    } catch (_) {
      if (matches.isEmpty) matchesError = 'Maç listesi şu an yüklenemedi. Lütfen biraz sonra tekrar deneyin.';
    }
    matchesLoading = false;
    notifyListeners();
  }

  bool isTurkish(MatchItem m) => turkishTeams.contains(m.home.id) || turkishTeams.contains(m.away.id);

  // ---------- Yönetici ----------
  Future<void> login(String pin) async {
    final o = await Backend.rpc('admin_login', {'p_pin': pin});
    _pin = pin;
    adminName = o['name'] as String?;
    adminRoles = ((o['roles'] as List?) ?? []).map((e) => e.toString()).toSet();
    await prefs.setString('pin', pin);
    await prefs.setString('adminName', adminName ?? '');
    await prefs.setStringList('roles', adminRoles.toList());
    notifyListeners();
  }

  void logout() {
    _pin = null;
    adminName = null;
    adminRoles = {};
    prefs.remove('pin');
    prefs.remove('adminName');
    prefs.remove('roles');
    notifyListeners();
  }

  void _auth(Object e) {
    if (e is ApiError && e.message.toUpperCase().contains('PIN')) logout();
  }

  Future<void> post(String section, String title, String body, Uint8List? photo) async {
    try {
      final url = photo == null ? null : await Backend.upload(pin, photo);
      await Backend.rpc('post_announcement', {
        'p_pin': pin,
        'p_section': section,
        'p_title': title,
        'p_body': body,
        'p_photo_url': url,
      });
      await refresh();
      markSeen(section);
    } catch (e) {
      _auth(e);
      rethrow;
    }
  }

  Future<void> delete(Ann a) async {
    try {
      await Backend.rpc('delete_announcement', {'p_pin': pin, 'p_id': a.id});
      announcements.removeWhere((x) => x.id == a.id);
      notifyListeners();
    } catch (e) {
      _auth(e);
      rethrow;
    }
  }

  Future<void> setLock(MatchItem m, bool open) async {
    final before = locks[m.id] ?? false;
    locks[m.id] = open;
    notifyListeners();
    try {
      await Backend.rpc('set_lock', {
        'p_pin': pin,
        'p_match_id': m.id,
        'p_open': open,
        'p_label': '${m.home.name} – ${m.away.name}',
        'p_kickoff': m.date.toUtc().toIso8601String(),
      });
    } catch (e) {
      locks[m.id] = before;
      notifyListeners();
      _auth(e);
      rethrow;
    }
  }

  // ---------- Yöneticileri yönet (nur super) ----------
  Future<List<AdminEntry>> adminList() async {
    final o = await Backend.rpc('admin_list', {'p_pin': pin});
    return ((o['admins'] as List?) ?? [])
        .map((x) => AdminEntry((x['id'] as num).toInt(), x['name'] as String,
            ((x['roles'] as List?) ?? []).map((e) => e.toString()).toList()))
        .toList();
  }

  Future<List<String>> adminAdd(String name, List<String> roles) async {
    final o = await Backend.rpc('admin_add', {'p_pin': pin, 'p_name': name, 'p_roles': roles});
    return [o['name'] as String, o['pin'] as String];
  }

  Future<void> adminRemove(int id) => Backend.rpc('admin_remove', {'p_pin': pin, 'p_id': id});

  Future<List<String>> adminResetPin(int id) async {
    final o = await Backend.rpc('admin_reset_pin', {'p_pin': pin, 'p_id': id});
    return [o['name'] as String, o['pin'] as String];
  }

  Future<void> adminSetRoles(int id, List<String> roles) =>
      Backend.rpc('admin_set_roles', {'p_pin': pin, 'p_id': id, 'p_roles': roles});
}
