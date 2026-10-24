/// Normalises Ethiopian numbers to E.164 (+2519XXXXXXXX / +2517XXXXXXXX).
class PhoneUtils {
  static String? normalize(String input) {
    final trimmed = input.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (trimmed.isEmpty) return null;
    String s = trimmed;
    if (s.startsWith('00')) s = '+${s.substring(2)}';
    if (s.startsWith('9') && s.length == 9) s = '+251$s';
    if (s.startsWith('07') && s.length == 10) s = '+251${s.substring(1)}';
    if (s.startsWith('09') && s.length == 10) s = '+251${s.substring(1)}';
    final re = RegExp(r'^\+251(9|7)\d{8}$');
    if (!re.hasMatch(s)) return null;
    return s;
  }

  static String mask(String e164) {
    final n = normalize(e164);
    if (n == null || n.length < 9) return e164;
    // +251 9X XXX XXXX
    return '+251 ${n[4]}X XXX ${n.substring(8, 11)} ${n.substring(11)}';
  }

  static bool isValid(String input) => normalize(input) != null;
}
