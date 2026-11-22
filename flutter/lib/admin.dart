import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'brand.dart';
import 'data.dart';
import 'pages.dart';
import 'prayer.dart';
import 'theme.dart';

Widget bigButton(String text, {bool enabled = true, required VoidCallback onTap}) => GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          gradient: enabled
              ? goldGradient
              : const LinearGradient(colors: [Color(0xFF3A3A30), Color(0xFF2C2C24)]),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(text, style: manrope(20, w: 800, color: enabled ? bg : muted, ls: 2)),
      ),
    );

Widget smallGoldButton(String text, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(gradient: goldGradient, borderRadius: BorderRadius.circular(18)),
        alignment: Alignment.center,
        child: Text(text, style: manrope(16, w: 800, color: bg)),
      ),
    );

class _Overlay extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final List<Widget> children;
  const _Overlay({required this.title, required this.onClose, required this.children});

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) onClose();
        },
        child: Material(
          color: bg,
          child: Stack(children: [
            const Positioned.fill(child: BrandBackground()),
            SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 30 + MediaQuery.of(context).viewInsets.bottom),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(children: [
                      Expanded(child: Text(title, style: marcellus(25))),
                      GestureDetector(
                        onTap: onClose,
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
                  ...children,
                ],
              ),
            ),
          ]),
        ),
      );
}

Widget fieldLabel(String t) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(Prayer.upperTr(t), style: manrope(12, w: 700, color: gold, ls: 2)),
    );

Widget bigField(TextEditingController c, String hint,
        {int minLines = 1, int? maxLines = 1, TextInputType? type, bool obscure = false, TextAlign align = TextAlign.start, double size = 19, ValueChanged<String>? onChanged, List<TextInputFormatter>? formatters, bool autofocus = false}) =>
    Container(
      decoration: glass(r: 20, elevated: false),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: TextField(
        controller: c,
        minLines: obscure ? 1 : minLines,
        maxLines: obscure ? 1 : maxLines,
        keyboardType: type,
        obscureText: obscure,
        obscuringCharacter: '●',
        textAlign: align,
        autofocus: autofocus,
        onChanged: onChanged,
        inputFormatters: formatters,
        textCapitalization: TextCapitalization.sentences,
        cursorColor: gold,
        style: manrope(size, color: textC, height: 1.4),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: manrope(size, color: muted.withValues(alpha: 0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );

// ================================================================ Yönetici-Girişi / Panel

class AdminGate extends StatefulWidget {
  final VoidCallback onClose;
  const AdminGate({super.key, required this.onClose});
  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  final pin = TextEditingController();
  String? error;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final name = app.adminName;
    if (name != null) {
      final roles = [
        if (app.isAdmin('super')) 'Ana yönetici',
        if (app.isAdmin('cami')) 'Cami duyuruları',
        if (app.isAdmin('lokal')) 'Lokal (duyurular ve kilitler)',
      ];
      return _Overlay(title: 'Yönetici', onClose: widget.onClose, children: [
        glassBox(
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            Text('GİRİŞ YAPILDI', style: manrope(12, w: 700, color: gold, ls: 2)),
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(name, style: marcellus(28))),
            for (final r in roles)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text('✓ $r', style: manrope(15, color: muted))),
          ]),
        ),
        const SizedBox(height: 20),
        if (app.isAdmin('cami') || app.isAdmin('super')) ...[
          smallGoldButton('⚙️  Cami bilgileri ve bağış', () {
            app.showInfoEdit = true;
            widget.onClose();
          }),
          const SizedBox(height: 12),
        ],
        if (app.isAdmin('super')) ...[
          smallGoldButton('👥  Yöneticileri yönet', () {
            app.showManage = true;
            widget.onClose();
          }),
          const SizedBox(height: 12),
          smallGoldButton('📷  Instagram bağlantısı', () => showDialog(context: context, builder: (_) => const InstagramDialog())),
          const SizedBox(height: 12),
        ],
        smallGoldButton('Tamam', widget.onClose),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            app.logout();
            widget.onClose();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Çıkış yap', textAlign: TextAlign.center, style: manrope(15, w: 600, color: closedRed)),
          ),
        ),
      ]);
    }
    return _Overlay(title: 'Yönetici', onClose: widget.onClose, children: [
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 14),
        child: Text("Yönetici PIN'inizi girin", textAlign: TextAlign.center, style: manrope(16, color: muted)),
      ),
      bigField(pin, '',
          type: TextInputType.number,
          obscure: true,
          align: TextAlign.center,
          size: 34,
          autofocus: true,
          formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
          onChanged: (_) => setState(() => error = null)),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(error!, textAlign: TextAlign.center, style: manrope(15, w: 600, color: closedRed)),
        ),
      const SizedBox(height: 22),
      bigButton(busy ? '…' : 'GİRİŞ', enabled: pin.text.length >= 4 && !busy, onTap: () async {
        setState(() => busy = true);
        try {
          await app.login(pin.text);
        } on ApiError catch (e) {
          error = e.message;
          pin.clear();
        } catch (_) {
          error = 'İnternet bağlantısı yok';
        }
        if (mounted) setState(() => busy = false);
      }),
    ]);
  }
}

// ================================================================ Duyuru yazen

class ComposeScreen extends StatefulWidget {
  final String section;
  final VoidCallback onClose;
  const ComposeScreen({super.key, required this.section, required this.onClose});
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final title = TextEditingController();
  final body = TextEditingController();
  Uint8List? photo;
  bool busy = false, done = false;
  late bool insta = widget.section == 'cami';
  String? error;

  Future<void> pick() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
      if (f == null) return;
      final b = await f.readAsBytes();
      setState(() => photo = b);
    } catch (_) {
      setState(() => error = 'Fotoğraf eklenemedi');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Material(
        color: bg,
        child: Stack(children: [
          const Positioned.fill(child: BrandBackground()),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: goldGradient),
                alignment: Alignment.center,
                child: const Text('✓', style: TextStyle(fontSize: 56, color: bg, fontWeight: FontWeight.bold)),
              ),
              Padding(padding: const EdgeInsets.only(top: 22), child: Text('Gönderildi', style: marcellus(32))),
            ]),
          ),
        ]),
      );
    }
    return _Overlay(
      title: widget.section == 'cami' ? 'Cami duyurusu' : 'Gençlik duyurusu',
      onClose: widget.onClose,
      children: [
        fieldLabel('Başlık'),
        bigField(title, 'Örn: Kermes'),
        const SizedBox(height: 16),
        fieldLabel('Duyuru'),
        bigField(body, 'Duyurunuzu yazın…', minLines: 6, maxLines: null, onChanged: (_) => setState(() {})),
        const SizedBox(height: 16),
        if (photo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(children: [
              AspectRatio(aspectRatio: 16 / 10, child: Image.memory(photo!, fit: BoxFit.cover)),
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => setState(() => photo = null),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.55)),
                    alignment: Alignment.center,
                    child: const Text('✕', style: TextStyle(fontSize: 17, color: Colors.white)),
                  ),
                ),
              ),
            ]),
          )
        else
          GestureDetector(
            onTap: pick,
            child: Container(
              height: 64,
              decoration: glass(r: 20, elevated: false),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                icon(Ic.camera, size: 26, color: gold),
                const SizedBox(width: 10),
                Text('Fotoğraf ekle', style: manrope(18, w: 700)),
              ]),
            ),
          ),
        if (app.instagramReady) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => setState(() => insta = !insta),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: glass(r: 20, elevated: false),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: insta ? goldGradient : null,
                    border: Border.all(color: gold, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: insta ? const Text('✓', style: TextStyle(fontSize: 19, color: bg, fontWeight: FontWeight.bold)) : null,
                ),
                const SizedBox(width: 14),
                Expanded(child: Text('Instagram\'da da paylaş', style: manrope(18, w: 700))),
              ]),
            ),
          ),
          if (insta && photo == null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 6, right: 6),
              child: Text('Fotoğraf yok: Instagram için cami tasarımında bir görsel otomatik hazırlanır.',
                  style: manrope(14, color: muted)),
            ),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(error!, textAlign: TextAlign.center, style: manrope(15, w: 600, color: closedRed)),
          ),
        const SizedBox(height: 22),
        bigButton(busy ? 'GÖNDERİLİYOR…' : 'YAYINLA', enabled: body.text.trim().isNotEmpty && !busy, onTap: () async {
          setState(() {
            busy = true;
            error = null;
          });
          var t = title.text.trim();
          if (t.isEmpty) {
            final first = body.text.trim().split('\n').first;
            t = first.length > 60 ? first.substring(0, 60) : first;
          }
          try {
            await app.post(widget.section, t, body.text.trim(), photo, instagram: app.instagramReady && insta);
            setState(() => done = true);
            await Future.delayed(const Duration(milliseconds: 1600));
            widget.onClose();
          } on ApiError catch (e) {
            setState(() => error = 'Gönderilemedi: ${e.message}');
          } catch (_) {
            setState(() => error = 'Gönderilemedi. İnternet bağlantınızı kontrol edin.');
          }
          if (mounted) setState(() => busy = false);
        }),
      ],
    );
  }
}

// ================================================================ Yöneticileri yönet (nur Kerim)

String roleText(List<String> r) => [
      if (r.contains('super')) 'Ana yönetici',
      if (r.contains('cami')) 'Cami',
      if (r.contains('lokal')) 'Lokal',
    ].join(' · ');

class ManageScreen extends StatefulWidget {
  final VoidCallback onClose;
  const ManageScreen({super.key, required this.onClose});
  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  List<AdminEntry> admins = [];
  bool loading = true, busy = false;
  String? error;
  final name = TextEditingController();
  bool newCami = false, newLokal = true;
  List<String>? shownPin;
  int? confirmDelete;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      admins = await app.adminList();
      error = null;
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> act(Future<void> Function() f) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await f();
      await reload();
    } catch (e) {
      setState(() => error = e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  Widget roleChip(String label, bool on, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: on ? goldGradient : null,
            color: on ? null : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: on ? Colors.transparent : line),
          ),
          child: Text('${on ? '✓ ' : ''}$label', style: manrope(14, w: 700, color: on ? bg : muted)),
        ),
      );

  Widget actionText(String label, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.4))),
          alignment: Alignment.center,
          child: Text(label, style: manrope(14, w: 700, color: color)),
        ),
      );

  @override
  Widget build(BuildContext context) => _Overlay(title: 'Yöneticiler', onClose: widget.onClose, children: [
        if (shownPin != null) ...[
          glassBox(
            padding: const EdgeInsets.all(22),
            child: Column(children: [
              Text('${shownPin![0]} için PIN', style: manrope(14, w: 700, color: gold)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SelectableText(shownPin![1], style: manrope(44, w: 800, ls: 6)),
              ),
              Text("Bu PIN'i ${shownPin![0]}'e iletin. Güvenlik için tekrar gösterilmez.",
                  textAlign: TextAlign.center, style: manrope(13, color: muted)),
              const SizedBox(height: 14),
              smallGoldButton('Tamam, not aldım', () => setState(() => shownPin = null)),
            ]),
          ),
          const SizedBox(height: 18),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error!, textAlign: TextAlign.center, style: manrope(14, w: 600, color: closedRed)),
          ),
        if (loading) Text('Yükleniyor…', style: manrope(14, color: muted)),
        for (final a in admins) ...[
          glassBox(
            r: 20,
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name, style: manrope(18, w: 700)),
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(roleText(a.roles), style: manrope(13, color: gold))),
              if (!a.roles.contains('super')) ...[
                const SizedBox(height: 12),
                Row(children: [
                  roleChip('Cami', a.roles.contains('cami'), () {
                    final r = {...a.roles}..remove('super');
                    r.contains('cami') ? r.remove('cami') : r.add('cami');
                    act(() => app.adminSetRoles(a.id, r.toList()));
                  }),
                  const SizedBox(width: 8),
                  roleChip('Lokal', a.roles.contains('lokal'), () {
                    final r = {...a.roles}..remove('super');
                    r.contains('lokal') ? r.remove('lokal') : r.add('lokal');
                    act(() => app.adminSetRoles(a.id, r.toList()));
                  }),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: actionText('Yeni PIN', gold, () => act(() async => shownPin = await app.adminResetPin(a.id)))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: confirmDelete == a.id
                        ? actionText('Emin misiniz? SİL', closedRed, () {
                            confirmDelete = null;
                            act(() => app.adminRemove(a.id));
                          })
                        : actionText('Sil', closedRed, () => setState(() => confirmDelete = a.id)),
                  ),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 10),
        ],
        Padding(padding: const EdgeInsets.only(top: 18), child: fieldLabel('Yeni yönetici')),
        bigField(name, 'İsim (örn. Fatih)', onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        Row(children: [
          roleChip('Cami duyuruları', newCami, () => setState(() => newCami = !newCami)),
          const SizedBox(width: 8),
          roleChip('Lokal', newLokal, () => setState(() => newLokal = !newLokal)),
        ]),
        const SizedBox(height: 16),
        bigButton(busy ? '…' : 'EKLE', enabled: name.text.trim().isNotEmpty && (newCami || newLokal) && !busy, onTap: () {
          final roles = [if (newCami) 'cami', if (newLokal) 'lokal'];
          final n = name.text.trim();
          act(() async {
            shownPin = await app.adminAdd(n, roles);
            name.clear();
          });
        }),
        const SizedBox(height: 40),
      ]);
}


// ================================================================ Instagram-Verbindung (nur Kerim)

class InstagramDialog extends StatefulWidget {
  const InstagramDialog({super.key});
  @override
  State<InstagramDialog> createState() => _InstagramDialogState();
}

class _InstagramDialogState extends State<InstagramDialog> {
  final token = TextEditingController();
  bool busy = false;
  String? msg;

  @override
  Widget build(BuildContext context) {
    final durum = app.setting('ig_durum');
    return AlertDialog(
      backgroundColor: bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: line)),
      title: Text('Instagram bağlantısı', style: marcellus(24, color: gold)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Durum: ${durum.isEmpty ? 'Bağlı değil' : durum}',
              style: manrope(16, w: 700, color: durum.startsWith('Bağlı:') ? openGreen : textC)),
          const SizedBox(height: 16),
          Text('Yeni token (Meta geliştirici sayfasından):', style: manrope(14, color: muted)),
          const SizedBox(height: 8),
          TextField(
            controller: token,
            minLines: 2,
            maxLines: 4,
            style: manrope(14),
            decoration: InputDecoration(
              hintText: 'IGAA…',
              hintStyle: manrope(14, color: muted),
              filled: true,
              fillColor: bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
            ),
          ),
          if (msg != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(msg!, style: manrope(14, w: 600, color: gold))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Kapat', style: manrope(16, color: muted))),
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  if (token.text.trim().isEmpty) {
                    // Nur Status neu laden
                    await app.refresh();
                    if (mounted) setState(() {});
                    return;
                  }
                  setState(() => busy = true);
                  try {
                    await app.igSetToken(token.text.trim());
                    token.clear();
                    msg = 'Kaydedildi. Birkaç saniye içinde durum güncellenir.';
                    await Future.delayed(const Duration(seconds: 5));
                    await app.refresh();
                  } on ApiError catch (e) {
                    msg = e.message;
                  } catch (_) {
                    msg = 'İnternet bağlantınızı kontrol edin.';
                  }
                  if (mounted) setState(() => busy = false);
                },
          child: Text(busy ? '…' : 'KAYDET / YENİLE', style: manrope(16, w: 800, color: gold)),
        ),
      ],
    );
  }
}
