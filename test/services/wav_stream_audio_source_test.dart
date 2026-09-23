import 'dart:typed_data';

import 'package:flick/services/wav_stream_audio_source.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _wavHeader() {
  final header = Uint8List(44);
  final view = ByteData.sublistView(header);
  header.setAll(0, 'RIFF'.codeUnits);
  view.setUint32(4, 36, Endian.little);
  header.setAll(8, 'WAVE'.codeUnits);
  header.setAll(12, 'fmt '.codeUnits);
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 2, Endian.little);
  view.setUint32(24, 44100, Endian.little);
  header.setAll(36, 'data'.codeUnits);
  return header;
}

void main() {
  group('VirtualWavLayout', () {
    test('patches RIFF and data chunk sizes', () {
      final layout = VirtualWavLayout(
        header: _wavHeader(),
        blockAlign: 4,
        totalFrames: 100,
      );
      final view = ByteData.sublistView(layout.header);

      expect(layout.dataOffset, 44);
      expect(layout.dataLength, 400);
      expect(layout.totalLength, 444);
      expect(view.getUint32(4, Endian.little), 36 + 400);
      expect(view.getUint32(40, Endian.little), 400);
    });

    test('clip window shifts absolute frame mapping', () {
      final layout = VirtualWavLayout(
        header: _wavHeader(),
        blockAlign: 4,
        totalFrames: 5,
        startFrame: 10,
      );

      expect(layout.offsetOfFrame(10), layout.dataOffset);
      expect(layout.offsetOfFrame(12), layout.dataOffset + 8);
      expect(layout.frameAtOffset(layout.dataOffset), 10);
      expect(layout.frameAtOffset(layout.dataOffset + 8), 12);
      expect(layout.frameAtOffset(0), 10);
      expect(layout.frameAtOffset(layout.totalLength), 15);
    });

    test('frameAtOffset rounds down inside a frame', () {
      final layout = VirtualWavLayout(
        header: _wavHeader(),
        blockAlign: 4,
        totalFrames: 8,
      );

      expect(layout.frameAtOffset(layout.dataOffset + 3), 0);
      expect(layout.frameAtOffset(layout.dataOffset + 4), 1);
      expect(layout.frameAtOffset(layout.dataOffset + 7), 1);
    });

    test('resolveRange clamps to the media length', () {
      final layout = VirtualWavLayout(
        header: _wavHeader(),
        blockAlign: 4,
        totalFrames: 10,
      );
      final total = layout.totalLength;

      expect(layout.resolveRange(null, null), (offset: 0, length: total));
      expect(layout.resolveRange(10, 20), (offset: 10, length: 10));
      expect(layout.resolveRange(total + 50, total + 100), (
        offset: total,
        length: 0,
      ));
      expect(layout.resolveRange(5, 3), (offset: 5, length: 0));
      expect(layout.resolveRange(-5, total + 5), (offset: 0, length: total));
    });

    test('round-trips every frame offset', () {
      final layout = VirtualWavLayout(
        header: _wavHeader(),
        blockAlign: 6,
        totalFrames: 12,
        startFrame: 30,
      );

      for (var frame = 30; frame < 30 + 12; frame++) {
        expect(layout.frameAtOffset(layout.offsetOfFrame(frame)), frame);
      }
    });

    test('flags data sections that overflow the 32-bit WAV header', () {
      final withinLimits = VirtualWavLayout(
        header: _wavHeader(),
        blockAlign: 3,
        totalFrames: 1431655753,
      );
      final beyondLimits = VirtualWavLayout(
        header: _wavHeader(),
        blockAlign: 3,
        totalFrames: 1431655754,
      );

      expect(withinLimits.dataLength, 0xFFFFFFFF - 36);
      expect(withinLimits.exceedsWav32BitLimits, isFalse);
      expect(beyondLimits.exceedsWav32BitLimits, isTrue);
    });

    test('defaults pacing sample rate to zero', () {
      final unpaced = VirtualWavLayout(
        header: _wavHeader(),
        blockAlign: 4,
        totalFrames: 10,
      );
      final paced = VirtualWavLayout(
        header: _wavHeader(),
        blockAlign: 4,
        totalFrames: 10,
        sampleRate: 96000,
      );

      expect(unpaced.sampleRate, 0);
      expect(paced.sampleRate, 96000);
    });
  });
}
