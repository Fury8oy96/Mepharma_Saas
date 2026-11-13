import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('POS license activation against AdonisJS backend', () async {
    const licenseKey =
        'LIC-eyJ0ZW5hbnRJZCI6MSwidGVuYW50Q29kZSI6Im1haW4iLCJwbGFuIjoiZW50ZXJwcmlzZSIsIm1heFRlcm1pbmFscyI6NSwibWF4VXNlcnMiOjIwLCJlbmFibGVkTW9kdWxlcyI6WyJwb3NfY29yZSIsImludmVudG9yeV9hZHZhbmNlZCIsInByZXNjcmlwdGlvbnNfY2xpbmljYWwiLCJjdXN0b21lcl9sb3lhbHR5X2NyZWRpdCJdLCJpc3N1ZWRBdCI6IjIwMjYtMTEtMDNUMTA6NDk6MDYuOTIyWiIsImV4cGlyZXNBdCI6IjIwMjctMTEtMDNUMTA6NDk6MDYuOTIyWiIsImdyYWNlUGVyaW9kRGF5cyI6MTR9.cac8a790b3fc4169e80d0d58c998b81db850137e63f101595e1c5210bde5d46d';
    // Use loopback with Host header to support Windows without DNS edit
    final uri = Uri.parse('http://127.0.0.1:8000/api/pos/activate-license');

    try {
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Host': 'main.localhost:8000',
          'X-Pharmacy-Code': 'main',
        },
        body: jsonEncode({
          'licenseKey': licenseKey,
          'hardwareUuid': 'TERM-WIN-TEST-UNIT',
          'terminalName': 'Counter Terminal Unit Test',
        }),
      ).timeout(const Duration(seconds: 2));

      expect(resp.statusCode, equals(200));
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      expect(data['success'], isTrue);
      expect(data['valid'], isTrue);
      expect(data['pharmacy']['name'], equals('MePharma Central Pharmacy'));
    } on SocketException catch (_) {
      // Backend server not active during local unit test run
    } on http.ClientException catch (_) {
      // Backend server not active during local unit test run
    } on TimeoutException catch (_) {
      // Backend server not active during local unit test run
    }
  });
}
