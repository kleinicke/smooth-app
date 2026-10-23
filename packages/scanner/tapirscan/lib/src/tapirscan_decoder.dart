import 'package:flutter/services.dart';

/// One native Tapirscan scanner; the plugin runs its calls one at a time.
class TapirscanDecoder {
  TapirscanDecoder._(this._id);

  static const MethodChannel _channel = MethodChannel(
    'org.openfoodfacts/tapirscan',
  );
  final int _id;
  bool _disposed = false;

  static Future<TapirscanDecoder> create() async {
    final int? id = await _channel.invokeMethod<int>('create');
    if (id == null) {
      throw StateError('Tapirscan did not return a scanner');
    }
    return TapirscanDecoder._(id);
  }

  Future<List<String>> scanLuma({
    required Uint8List bytes,
    required int width,
    required int height,
    required int rowStride,
    required int pixelStride,
  }) async {
    if (_disposed) {
      throw StateError('Tapirscan scanner is disposed');
    }
    // Tapirscan reads padded rows in place; only interleaved planes are copied.
    final bool interleaved = pixelStride != 1;
    return await _channel.invokeListMethod<String>('scan', <String, Object>{
          'id': _id,
          'bytes': interleaved
              ? packLuma(bytes, width, height, rowStride, pixelStride)
              : bytes,
          'width': width,
          'height': height,
          'stride': interleaved ? 0 : rowStride,
        }) ??
        <String>[];
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _channel.invokeMethod<void>('dispose', <String, Object>{'id': _id});
  }
}

/// Copies an interleaved Y plane into packed rows. The last row may be
/// shorter than [rowStride], as in Android camera buffers.
Uint8List packLuma(
  Uint8List bytes,
  int width,
  int height,
  int rowStride,
  int pixelStride,
) {
  if (width < 1 ||
      height < 1 ||
      rowStride < (width - 1) * pixelStride + 1 ||
      pixelStride < 1 ||
      bytes.length < (height - 1) * rowStride + (width - 1) * pixelStride + 1) {
    throw ArgumentError('Invalid camera luminance plane');
  }
  final Uint8List result = Uint8List(width * height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      result[y * width + x] = bytes[y * rowStride + x * pixelStride];
    }
  }
  return result;
}
