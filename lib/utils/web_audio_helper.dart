import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

// 웹 전용 JS interop - 조건부 import
import 'web_audio_helper_web.dart' if (dart.library.io) 'web_audio_helper_stub.dart' as _impl;

/// 웹 환경에서 오디오 재생·다운로드 및 범용 파일 다운로드를 처리하는 유틸리티
class WebAudioHelper {

  // ─── 오디오 재생 ─────────────────────────────────────────

  static void playWav(Uint8List bytes) {
    if (!kIsWeb) return;
    _impl.jsPlayBlob(bytes, 'audio/wav');
  }

  static void playMp3(Uint8List bytes) {
    if (!kIsWeb) return;
    _impl.jsPlayBlob(bytes, 'audio/mp3');
  }

  static void playBytes(Uint8List bytes, {String mimeType = 'audio/wav'}) {
    if (!kIsWeb) return;
    _impl.jsPlayBlob(bytes, mimeType);
  }

  // ─── 재생 제어 ───────────────────────────────────────────

  static void stop() {
    if (!kIsWeb) return;
    _impl.jsStopAudio();
  }

  // ─── 오디오 다운로드 ─────────────────────────────────────

  static void downloadWav(Uint8List bytes, {String fileName = 'audio.wav'}) {
    if (!kIsWeb) return;
    _impl.jsDownloadBlob(bytes, 'audio/wav', fileName);
  }

  static void downloadMp3(Uint8List bytes, {String fileName = 'audio.mp3'}) {
    if (!kIsWeb) return;
    _impl.jsDownloadBlob(bytes, 'audio/mp3', fileName);
  }

  static void downloadBytes(Uint8List bytes,
      {String fileName = 'audio.wav', String mimeType = 'audio/wav'}) {
    if (!kIsWeb) return;
    _impl.jsDownloadBlob(bytes, mimeType, fileName);
  }

  // ─── 범용 파일 다운로드 ──────────────────────────────────

  static void downloadFile(Uint8List bytes,
      {required String fileName,
      String mimeType = 'application/octet-stream'}) {
    if (!kIsWeb) return;
    _impl.jsDownloadBase64(base64Encode(bytes), mimeType, fileName);
  }

  static void downloadText(String content,
      {required String fileName,
      String mimeType = 'text/plain;charset=utf-8'}) {
    if (!kIsWeb) return;
    final utf8Bytes = _encodeUtf8(content);
    downloadFile(utf8Bytes, fileName: fileName, mimeType: mimeType);
  }

  // ─── PCM → WAV 변환 ──────────────────────────────────────

  static Uint8List pcmToWav(
    Uint8List pcmData, {
    int sampleRate = 24000,
    int numChannels = 1,
    int bitsPerSample = 16,
  }) {
    final dataSize = pcmData.length;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;

    final header = ByteData(44);
    int o = 0;
    header.setUint8(o++, 0x52); header.setUint8(o++, 0x49);
    header.setUint8(o++, 0x46); header.setUint8(o++, 0x46);
    header.setUint32(o, 36 + dataSize, Endian.little); o += 4;
    header.setUint8(o++, 0x57); header.setUint8(o++, 0x41);
    header.setUint8(o++, 0x56); header.setUint8(o++, 0x45);
    header.setUint8(o++, 0x66); header.setUint8(o++, 0x6D);
    header.setUint8(o++, 0x74); header.setUint8(o++, 0x20);
    header.setUint32(o, 16, Endian.little); o += 4;
    header.setUint16(o, 1, Endian.little); o += 2;
    header.setUint16(o, numChannels, Endian.little); o += 2;
    header.setUint32(o, sampleRate, Endian.little); o += 4;
    header.setUint32(o, byteRate, Endian.little); o += 4;
    header.setUint16(o, blockAlign, Endian.little); o += 2;
    header.setUint16(o, bitsPerSample, Endian.little); o += 2;
    header.setUint8(o++, 0x64); header.setUint8(o++, 0x61);
    header.setUint8(o++, 0x74); header.setUint8(o++, 0x61);
    header.setUint32(o, dataSize, Endian.little);

    final wav = Uint8List(44 + dataSize);
    wav.setAll(0, header.buffer.asUint8List());
    wav.setAll(44, pcmData);
    return wav;
  }

  static bool isWav(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x52 && bytes[1] == 0x49 &&
        bytes[2] == 0x46 && bytes[3] == 0x46;
  }

  static bool isMp3(Uint8List bytes) {
    if (bytes.length < 3) return false;
    return (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) ||
        (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33);
  }

  static void playAuto(Uint8List bytes, {int sampleRate = 24000}) {
    if (!kIsWeb) return;
    if (isWav(bytes)) {
      _impl.jsPlayBlob(bytes, 'audio/wav');
    } else if (isMp3(bytes)) {
      _impl.jsPlayBlob(bytes, 'audio/mpeg');
    } else {
      _impl.jsPlayBlob(pcmToWav(bytes, sampleRate: sampleRate), 'audio/wav');
    }
  }

  static void downloadAuto(Uint8List bytes,
      {String fileName = 'audio', int sampleRate = 24000}) {
    if (!kIsWeb) return;
    if (isWav(bytes)) {
      _impl.jsDownloadBlob(bytes, 'audio/wav',
          fileName.endsWith('.wav') ? fileName : '$fileName.wav');
    } else if (isMp3(bytes)) {
      _impl.jsDownloadBlob(bytes, 'audio/mpeg',
          fileName.endsWith('.mp3') ? fileName : '$fileName.mp3');
    } else {
      final wav = pcmToWav(bytes, sampleRate: sampleRate);
      _impl.jsDownloadBlob(wav, 'audio/wav',
          fileName.endsWith('.wav') ? fileName : '$fileName.wav');
    }
  }

  static Uint8List _encodeUtf8(String s) {
    final result = <int>[];
    for (final rune in s.runes) {
      if (rune < 0x80) {
        result.add(rune);
      } else if (rune < 0x800) {
        result.add(0xC0 | (rune >> 6));
        result.add(0x80 | (rune & 0x3F));
      } else if (rune < 0x10000) {
        result.add(0xE0 | (rune >> 12));
        result.add(0x80 | ((rune >> 6) & 0x3F));
        result.add(0x80 | (rune & 0x3F));
      } else {
        result.add(0xF0 | (rune >> 18));
        result.add(0x80 | ((rune >> 12) & 0x3F));
        result.add(0x80 | ((rune >> 6) & 0x3F));
        result.add(0x80 | (rune & 0x3F));
      }
    }
    return Uint8List.fromList(result);
  }
}
