/// Native implementation using dart:io (mobile/desktop).
/// 
/// Provides gzip compression for ~75% size reduction.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

bool get isAvailable => true;

Uint8List? compress(String data) {
  try {
    final bytes = utf8.encode(data);
    return Uint8List.fromList(gzip.encode(bytes));
  } catch (_) {
    return null;
  }
}

String? decompress(Uint8List data) {
  try {
    final bytes = gzip.decode(data);
    return utf8.decode(bytes);
  } catch (_) {
    return null;
  }
}
