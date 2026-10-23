import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_tapirscan/src/tapirscan_decoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'packs padded rows and interleaved pixels without requiring last-row padding',
    () {
      final Uint8List plane = Uint8List.fromList(<int>[
        1,
        99,
        2,
        99,
        3,
        99,
        99,
        99,
        4,
        99,
        5,
        99,
        6,
        99,
        99,
        99,
        7,
        99,
        8,
        99,
        9,
      ]);
      expect(packLuma(plane, 3, 3, 8, 2), <int>[1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(() => packLuma(plane, 3, 3, 8, 3), throwsArgumentError);
      expect(() => packLuma(plane, 3, 3, 2, 1), throwsArgumentError);
    },
  );

  test('passes plain frames in place and disposes exactly once', () async {
    const MethodChannel channel = MethodChannel('org.openfoodfacts/tapirscan');
    final List<MethodCall> calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          if (call.method == 'create') {
            return 7;
          }
          if (call.method == 'scan') {
            return <String>['12345670'];
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final TapirscanDecoder decoder = await TapirscanDecoder.create();
    expect(
      await decoder.scanLuma(
        bytes: Uint8List(9),
        width: 3,
        height: 3,
        rowStride: 3,
        pixelStride: 1,
      ),
      <String>['12345670'],
    );
    final Map<Object?, Object?> scan =
        calls[1].arguments as Map<Object?, Object?>;
    expect(scan['id'], 7);
    expect(scan['stride'], 3);
    await decoder.dispose();
    await decoder.dispose();
    expect(
      calls.where((MethodCall call) => call.method == 'dispose'),
      hasLength(1),
    );
    await expectLater(
      decoder.scanLuma(
        bytes: Uint8List(9),
        width: 3,
        height: 3,
        rowStride: 3,
        pixelStride: 1,
      ),
      throwsStateError,
    );
  });
}
