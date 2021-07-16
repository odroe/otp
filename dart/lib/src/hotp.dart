import 'dart:math';

import 'package:crypto/crypto.dart';

const String OTP_ALGORITHM = 'sha1';

class HOTP {
  final List<int> secret;

  const HOTP(this.secret);

  Hmac get hmac => new Hmac(sha1, secret);

  String make({
    int counter = 0,
    int digits = 6,
  }) {
    /// Get the counter bytes hmac sha1 bytes;
    final bytes = hmac.convert(_int_to_8_bytes(counter)).bytes;

    /// Get the offset of the last byte;
    final offset = bytes.elementAt(bytes.length - 1) & 0xf;
    final value = (bytes.elementAt(offset) & 0x7f) << 24 |
        (bytes.elementAt(offset + 1) & 0xff) << 16 |
        (bytes.elementAt(offset + 2) & 0xff) << 8 |
        (bytes.elementAt(offset + 3) & 0xff);

    /// get the value string
    final str = (value % pow(10, digits)).toString();

    return str.padLeft(digits, '0');
  }

  bool check(
    String otp, {
    int counter = 0,
    int breadth = 0,
  }) {
    for (int index = counter - breadth; index <= counter + breadth; index++) {
      if (otp ==
          make(
            digits: otp.length,
            counter: index,
          )) {
        return true;
      }
    }
    return false;
  }

  List<int> _int_to_8_bytes(int input) {
    final bit = 8;
    return List<int>.generate(bit, (index) => (input >> (bit * index)) & 0xff).reversed.toList();
  }
}
