/// Formats area in Rai to Thai land measurement units: ไร่-งาน-ตารางวา
///
/// Conversion: 1 ไร่ = 4 งาน = 400 ตารางวา
///   - 1 งาน = 100 ตารางวา
///
/// If area >= 1 rai → "X ไร่ Y งาน Z ตร.วา"
/// If area < 1 rai  → "Y งาน Z ตร.วา" (omit ไร่)
String formatThaiArea(double areaRai) {
  final int rai = areaRai.floor();
  final double remainderAfterRai = areaRai - rai;

  final int ngan = (remainderAfterRai * 4).floor();
  final double remainderAfterNgan = remainderAfterRai - (ngan / 4);

  final double wa = remainderAfterNgan * 400;

  final parts = <String>[];

  if (rai > 0) {
    parts.add('$rai ไร่');
  }

  if (ngan > 0) {
    parts.add('$ngan งาน');
  }

  if (wa >= 0.01 || parts.isEmpty) {
    parts.add('${wa.toStringAsFixed(2)} ตร.วา');
  }

  return parts.join(' ');
}
