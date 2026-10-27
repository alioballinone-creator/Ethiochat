/// Money helpers. All wallet values are integer minor units (santim).
String formatEtb(int amountMinor,
    {bool signed = false, bool showCurrency = true}) {
  final negative = amountMinor < 0;
  final abs = amountMinor.abs();
  final whole = abs ~/ 100;
  final cents = (abs % 100).toString().padLeft(2, '0');
  final digits = whole.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final sign = negative
      ? '-'
      : signed && amountMinor > 0
          ? '+'
          : '';
  return '$sign${showCurrency ? 'ETB ' : ''}$buffer.$cents';
}

int parseEtbToMinor(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return 0;
  final value = double.tryParse(cleaned) ?? 0;
  return (value * 100).round();
}
