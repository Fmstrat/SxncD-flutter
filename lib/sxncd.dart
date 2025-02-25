import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class SxncdResponse {
  bool success;
  String? data;
  String? action;
  String? error;

  SxncdResponse(
    this.success,
    {
      this.data,
      this.action,
      this.error,
    }
  );
}

class EncryptionHelper {
  static Uint8List _generateKeyFromPassword(String password, String salt) {
    final key = pbkdf2(
      password,
      salt,
      10000, // Iterations
      32,    // Key length
    );
    return Uint8List.fromList(key);
  }

  static List<int> pbkdf2(String password, String salt, int iterations, int length) {
    final key = utf8.encode(password);
    final saltBytes = utf8.encode(salt);

    var hmac = Hmac(sha256, key);
    var derivedKey = List<int>.filled(length, 0);
    var block = Uint8List.fromList(hmac.convert(saltBytes).bytes);

    for (int i = 0; i < iterations; i++) {
      block = Uint8List.fromList(hmac.convert(block).bytes);
    }
    
    derivedKey.setRange(0, length, block);
    return derivedKey;
  }


  static String deriveSaltFromPassword(String password) {
    final bytes = utf8.encode(password + ":sxncd-final-padded-salt");
    return base64Encode(sha256.convert(bytes).bytes).substring(0, 16);
  }

  static String encryptString(String plainText, String password) {
    final salt = deriveSaltFromPassword(password);
    final key = _generateKeyFromPassword(password, salt);
    final iv = encrypt.IV.fromLength(16);

    final encrypter = encrypt.Encrypter(encrypt.AES(
      encrypt.Key(key),
      mode: encrypt.AESMode.cbc,
    ));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return base64Encode(iv.bytes + encrypted.bytes);
  }

  static String decryptString(String encryptedText, String password) {
    final salt = deriveSaltFromPassword(password);
    final key = _generateKeyFromPassword(password, salt);
    final data = base64Decode(encryptedText);

    final iv = encrypt.IV(Uint8List.fromList(data.sublist(0, 16)));
    final encryptedData = encrypt.Encrypted(Uint8List.fromList(data.sublist(16)));

    final encrypter = encrypt.Encrypter(encrypt.AES(
      encrypt.Key(key),
      mode: encrypt.AESMode.cbc,
    ));

    return encrypter.decrypt(encryptedData, iv: iv);
  }
}

Future<SxncdResponse> sxncdSync(String url, String apiKey, String deviceName, String data, DateTime savedTs, [String? password]) async {
  try {
    String settings = data;
    if (password != null && password != '') {
      settings = EncryptionHelper.encryptString(settings, password);
    }
    final syncResponse = await http.post(Uri.parse('${url}/api/v1/sync/update'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': apiKey,
      },
      body: jsonEncode({
        'deviceName': deviceName,
        'savedTs': savedTs.toIso8601String(),
        'settings': settings,
      }),
    ).timeout(Duration(seconds: 5));    
    if (syncResponse.statusCode != 200) {
      final jsonData = jsonDecode(syncResponse.body);
      final SxncdResponse response = SxncdResponse(
        false,
        error: jsonData['error'],
      );
      return Future.value(response);
    } else {
      final jsonData = jsonDecode(syncResponse.body);
      String data = jsonData['data'];
      if (password != null && password != '') {
        try {
          data = EncryptionHelper.decryptString(jsonData['data'], password);
        } catch (e) {
          // Data is not encrypted
        }
      }
      final SxncdResponse response = SxncdResponse(
        true,
        action: jsonData['action'],
        data: data,
      );
      return Future.value(response);
    }
  } catch (e) {
    final SxncdResponse response = SxncdResponse(
      false,
      error: e.toString(),
    );
    return Future.value(response);
  }
}
