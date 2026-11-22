import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'admin.dart';
import 'brand.dart';
import 'data.dart';
import 'pages.dart';
import 'theme.dart';

/// 2 → "2€", 2.5 → "2,50€" (wie auf dem Aushang)
String priceText(double p) {
  if (p == p.roundToDouble()) return '${p.round()}€';
  return '${p.toStringAsFixed(2).replaceAll('.', ',')}€';
}

// ================================================================ Karte in der Lokal-Seite

class PriceCard extends StatefulWidget {
  const PriceCard({super.key});
  @override
  State<PriceCard> createState() => _PriceCardState();
}

class _PriceCardState extends State<PriceCard> {
  bool open = false;
  bool printing = false;

  @override
  Widget build(BuildContext context) {
    final items = app.prices;
    if (items.isEmpty && !app.isAdmin('lokal')) return const SizedBox.shrink();
    return glassBox(
      r: 22,
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => open = !open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(children: [
              const Text('🥤', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('İçecek fiyatları', style: manrope(16, w: 700)),
                  Text('${items.length} ürün', style: manrope(12, color: muted)),
                ]),
              ),
              Text(open ? '▲' : '▼', style: const TextStyle(fontSize: 13, color: gold)),
            ]),
          ),
        ),
        if (open) ...[
          Container(height: 1, color: line),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            child: Column(children: [
              for (var i = 0; i < items.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    border: i < items.length - 1 ? const Border(bottom: BorderSide(color: line)) : null,
                  ),
                  child: Row(children: [
                    Expanded(child: Text(items[i].name, style: manrope(15, w: 500))),
                    Text(priceText(items[i].price), style: manrope(15, w: 800, color: gold)),
                  ]),
                ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: printing
                        ? null
                        : () async {
                            setState(() => printing = true);
                            try {
                              await printPriceList(app.prices);
                            } catch (e) {
                              if (context.mounted) toast(context, 'Yazdırılamadı: $e');
                            }
                            if (mounted) setState(() => printing = false);
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(gradient: goldGradient, borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: printing
                          ? Text('…', style: manrope(15, w: 800, color: bg))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              icon(Ic.printer, size: 18, color: bg),
                              const SizedBox(width: 8),
                              Text('Yazdır', style: manrope(15, w: 800, color: bg)),
                            ]),
                    ),
                  ),
                ),
                if (app.isAdmin('lokal')) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        app.showPriceEdit = true;
                        app.ui();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: gold)),
                        alignment: Alignment.center,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          icon(Ic.pen, size: 16, color: gold),
                          const SizedBox(width: 8),
                          Text('Düzenle', style: manrope(15, w: 800, color: gold)),
                        ]),
                      ),
                    ),
                  ),
                ],
              ]),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ================================================================ Druck (A4, Logo mittig)

Future<void> printPriceList(List<PriceItem> items) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/poppins_regular.ttf'));
  final semi = pw.Font.ttf(await rootBundle.load('assets/fonts/poppins_semibold.ttf'));
  final logo = pw.MemoryImage((await rootBundle.load('assets/img/logo_genclik_dark.png')).buffer.asUint8List());
  const ink = PdfColor.fromInt(0xFF333333);
  const lineC = PdfColor.fromInt(0xFFCFCFCF);
  const bronze = PdfColor.fromInt(0xFFB0804A);

  final doc = pw.Document(title: 'Getränke Preise', author: 'Gençlik Kolları – Merkez Camii Vilsbiburg');
  // Zeilenhöhe an die Anzahl anpassen, damit alles auf eine Seite passt
  final n = items.isEmpty ? 1 : items.length;
  final rowH = (430 / n).clamp(22.0, 36.0);
  final fontSize = (rowH * 0.5).clamp(11.0, 16.0);

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(56, 48, 56, 40),
    build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.SizedBox(height: 6),
      pw.Image(logo, width: 260),
      pw.SizedBox(height: 34),
      pw.Text('GETRÄNKE PREISE', style: pw.TextStyle(font: semi, fontSize: 30, color: ink, letterSpacing: 2)),
      pw.SizedBox(height: 10),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
        pw.Container(width: 150, height: 0.8, color: lineC),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 9),
          child: pw.Transform.rotate(angle: 0.785398, child: pw.Container(width: 7, height: 7, color: bronze)),
        ),
        pw.Container(width: 150, height: 0.8, color: lineC),
      ]),
      pw.SizedBox(height: 28),
      for (var i = 0; i < items.length; i++)
        pw.Container(
          height: rowH,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10),
          decoration: pw.BoxDecoration(
            border: i < items.length - 1 ? const pw.Border(bottom: pw.BorderSide(color: lineC, width: 0.8)) : null,
          ),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Expanded(child: pw.Text(items[i].name, style: pw.TextStyle(font: regular, fontSize: fontSize, color: ink))),
            pw.Text(priceText(items[i].price), style: pw.TextStyle(font: regular, fontSize: fontSize, color: ink)),
          ]),
        ),
    ]),
  ));

  await Printing.layoutPdf(name: 'Getraenke_Preise', onLayout: (_) async => doc.save());
}

// ================================================================ Bearbeiten (Lokal-Yönetici)

class _Row {
  final TextEditingController name;
  final TextEditingController price;
  _Row(String n, double p)
      : name = TextEditingController(text: n),
        price = TextEditingController(text: p == 0 ? '' : priceText(p).replaceAll('€', ''));
}

class PriceEditScreen extends StatefulWidget {
  final VoidCallback onClose;
  const PriceEditScreen({super.key, required this.onClose});
  @override
  State<PriceEditScreen> createState() => _PriceEditScreenState();
}

class _PriceEditScreenState extends State<PriceEditScreen> {
  late final List<_Row> rows = [for (final p in app.prices) _Row(p.name, p.price)];
  bool busy = false;
  String? msg;

  double _parse(String s) => double.tryParse(s.replaceAll('€', '').replaceAll(',', '.').trim()) ?? 0;

  Future<void> save() async {
    setState(() {
      busy = true;
      msg = null;
    });
    try {
      await app.savePrices([
        for (final r in rows)
          if (r.name.text.trim().isNotEmpty) PriceItem(r.name.text.trim(), _parse(r.price.text))
      ]);
      msg = '✓ Kaydedildi';
    } catch (e) {
      msg = 'Kaydedilemedi: $e';
    }
    if (mounted) setState(() => busy = false);
  }

  Widget _small(String t, VoidCallback? onTap, {Color color = gold}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: onTap == null ? line : color.withValues(alpha: 0.5))),
          alignment: Alignment.center,
          child: Text(t, style: manrope(14, w: 800, color: onTap == null ? muted.withValues(alpha: 0.4) : color)),
        ),
      );

  Widget _field(TextEditingController c, String hint, {TextInputType? type, TextAlign align = TextAlign.start}) => TextField(
        controller: c,
        keyboardType: type,
        textAlign: align,
        cursorColor: gold,
        style: manrope(15, w: 600),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: manrope(15, color: muted.withValues(alpha: 0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.onClose();
        },
        child: Material(
          color: bg,
          child: Stack(children: [
            const Positioned.fill(child: BrandBackground()),
            SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 40 + MediaQuery.of(context).viewInsets.bottom),
                children: [
                  Row(children: [
                    Expanded(child: Text('İçecek fiyatları', style: marcellus(25))),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: line)),
                        alignment: Alignment.center,
                        child: const Text('✕', style: TextStyle(fontSize: 18, color: textC)),
                      ),
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 16),
                    child: Text('Ürün adı ve fiyatı değiştirin, ↑↓ ile sıralayın.', style: manrope(13, color: muted)),
                  ),
                  for (var i = 0; i < rows.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                      decoration: glass(r: 16, elevated: false),
                      child: Row(children: [
                        Expanded(flex: 5, child: _field(rows[i].name, 'Ürün adı')),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 64,
                          child: _field(rows[i].price, '0,00', type: const TextInputType.numberWithOptions(decimal: true), align: TextAlign.end),
                        ),
                        Text(' €', style: manrope(15, w: 700, color: gold)),
                        const SizedBox(width: 6),
                        _small('↑', i == 0 ? null : () => setState(() => rows.insert(i - 1, rows.removeAt(i)))),
                        const SizedBox(width: 4),
                        _small('↓', i == rows.length - 1 ? null : () => setState(() => rows.insert(i + 1, rows.removeAt(i)))),
                        const SizedBox(width: 4),
                        _small('✕', () => setState(() => rows.removeAt(i)), color: closedRed),
                      ]),
                    ),
                  GestureDetector(
                    onTap: () => setState(() => rows.add(_Row('', 0))),
                    child: Container(
                      margin: const EdgeInsets.only(top: 4, bottom: 20),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
                      alignment: Alignment.center,
                      child: Text('＋ Ürün ekle', style: manrope(15, w: 700, color: gold)),
                    ),
                  ),
                  if (msg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(msg!,
                          textAlign: TextAlign.center,
                          style: manrope(15, w: 700, color: msg!.startsWith('✓') ? openGreen : closedRed)),
                    ),
                  bigButton(busy ? '…' : 'KAYDET', enabled: !busy, onTap: save),
                ],
              ),
            ),
          ]),
        ),
      );
}
