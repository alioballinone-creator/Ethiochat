import 'package:ethiochat/core/utils/phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneUtils.normalize', () {
    test('normalises 09xxxxxxxx', () {
      expect(PhoneUtils.normalize('0912345678'), '+251912345678');
    });
    test('normalises 9xxxxxxxx', () {
      expect(PhoneUtils.normalize('912345678'), '+251912345678');
    });
    test('normalises +2519xxxxxxxx', () {
      expect(PhoneUtils.normalize('+251912345678'), '+251912345678');
    });
    test('normalises 07xxxxxxxx to 7 prefix', () {
      expect(PhoneUtils.normalize('0712345678'), '+251712345678');
    });
    test('rejects invalid', () {
      expect(PhoneUtils.normalize('123'), isNull);
      expect(PhoneUtils.normalize('+251812345678'), isNull);
    });
    test('strips spaces and dashes', () {
      expect(PhoneUtils.normalize('+251 91 234 5678'), '+251912345678');
    });
  });

  group('PhoneUtils.mask', () {
    test('masks to +251 9X XXX XXXX format', () {
      expect(PhoneUtils.mask('+251912345678'), '+251 9X XXX 456 78');
    });
  });
}
