/// Stub implementation for web (no dart:io available).
/// 
/// Compression is not available on web, so these return null.
import 'dart:typed_data';

bool get isAvailable => false;

Uint8List? compress(String data) => null;

String? decompress(Uint8List data) => null;
