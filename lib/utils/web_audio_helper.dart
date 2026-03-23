import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

// 웹 전용 JS interop - 조건부 import
import 'web_audio_helper_web.dart' if (dart.library.io) 'web_audio_helper_stub.dart' as webImpl;

/// 오디오 재생·다운로드 유틸리티
/// - Web  : JS Blob URL 방식
/// - Desktop (Windows/macOS/Linux) : audioplayers 패키지
class WebAudioHelper {
  // Desktop 오디오 플레이어 싱글톤
  static AudioPlayer? _player;

  static AudioPlayer _getPlayer() {
    _player ??= AudioPlayer();
    return _player!;
  }

  // ─── Desktop 재생 ────────────────────────────────────────

  /// Windows/Desktop 에서 바이트를 임시 파일로 저장 후 재생
  static Future<void> playDesktop(Uint8List bytes, {String ext = 'wav'}) async {
    final tmpDir = await getTemporaryDirectory();
    final path = '${tmpDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(path).writeAsBytes(bytes);
    final player = _getPlayer();
    await player.stop();
    await player.play(DeviceFileSource(path));
  }

  /// 재생 중지 (Desktop)
  static Future<void> stopDesktop() async {
    try { await _player?.stop(); } catch (_) {}
  }

  /// Desktop에서 현재 재생 중인지 확인
  static bool get isDesktopPlaying =>
      _player?.state == PlayerState.playing;

  // ─── 통합 재생 API ───────────────────────────────────────

  /// 플랫폼 자동 감지 재생
  /// Web → JS Blob, Desktop → audioplayers
  static Future<void> playAutoAsync(Uint8List bytes,
      {int sampleRate = 24000}) async {
    if (kIsWeb) {
      playAuto(bytes, sampleRate: sampleRate);
    } else {
      if (isMp3(bytes)) {
        await playDesktop(bytes, ext: 'mp3');
      } else if (isWav(bytes)) {
        await playDesktop(bytes, ext: 'wav');
      } else {
        // raw PCM (Gemini TTS) → WAV 헤더 추가 후 재생
        final wav = pcmToWav(bytes, sampleRate: sampleRate);
        await playDesktop(wav, ext: 'wav');
      }
    }
  }

  /// 모든 플랫폼 재생 중지
  static Future<void> stopAll() async {
    if (kIsWeb) {
      stop();
    } else {
      await stopDesktop();
    }
  }

  // ─── Desktop 파일 저장 ───────────────────────────────────

  /// Windows/Desktop 에서 FilePicker 로 오디오 파일 저장
  static Future<String?> saveDesktopAudio(Uint8List bytes,
      {String defaultName = 'tts_audio', int sampleRate = 24000}) async {
    Uint8List saveBytes;
    String ext;
    if (isMp3(bytes)) {
      saveBytes = bytes;
      ext = 'mp3';
    } else if (isWav(bytes)) {
      saveBytes = bytes;
      ext = 'wav';
    } else {
      saveBytes = pcmToWav(bytes, sampleRate: sampleRate);
      ext = 'wav';
    }

    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '오디오 파일 저장',
        fileName: '$defaultName.$ext',
        allowedExtensions: [ext],
        type: FileType.custom,
      );
      if (result != null) {
        await File(result).writeAsBytes(saveBytes);
        return result;
      }
    } catch (_) {
      // FilePicker 실패 시 Documents 폴더에 자동 저장
      final docs = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final out = File('${docs.path}/${defaultName}_$ts.$ext');
      await out.writeAsBytes(saveBytes);
      return out.path;
    }
    return null;
  }

  // ─── Web 전용 재생 ───────────────────────────────────────

  static void playWav(Uint8List bytes) {
    if (!kIsWeb) return;
    webImpl.jsPlayBlob(bytes, 'audio/wav');
  }

  static void playMp3(Uint8List bytes) {
    if (!kIsWeb) return;
    webImpl.jsPlayBlob(bytes, 'audio/mpeg');
  }

  static void playBytes(Uint8List bytes, {String mimeType = 'audio/wav'}) {
    if (!kIsWeb) return;
    webImpl.jsPlayBlob(bytes, mimeType);
  }

  static void playAuto(Uint8List bytes, {int sampleRate = 24000}) {
    if (!kIsWeb) return;
    if (isWav(bytes)) {
      webImpl.jsPlayBlob(bytes, 'audio/wav');
    } else if (isMp3(bytes)) {
      webImpl.jsPlayBlob(bytes, 'audio/mpeg');
    } else {
      webImpl.jsPlayBlob(pcmToWav(bytes, sampleRate: sampleRate), 'audio/wav');
    }
  }

  static void stop() {
    if (!kIsWeb) return;
    webImpl.jsStopAudio();
  }

  // ─── Web 전용 다운로드 ───────────────────────────────────

  static void downloadWav(Uint8List bytes, {String fileName = 'audio.wav'}) {
    if (!kIsWeb) return;
    webImpl.jsDownloadBlob(bytes, 'audio/wav', fileName);
  }

  static void downloadMp3(Uint8List bytes, {String fileName = 'audio.mp3'}) {
    if (!kIsWeb) return;
    webImpl.jsDownloadBlob(bytes, 'audio/mpeg', fileName);
  }

  static void downloadBytes(Uint8List bytes,
      {String fileName = 'audio.wav', String mimeType = 'audio/wav'}) {
    if (!kIsWeb) return;
    webImpl.jsDownloadBlob(bytes, mimeType, fileName);
  }

  static void downloadFile(Uint8List bytes,
      {required String fileName,
      String mimeType = 'application/octet-stream'}) {
    if (!kIsWeb) return;
    webImpl.jsDownloadBase64(base64Encode(bytes), mimeType, fileName);
  }

  static void downloadText(String content,
      {required String fileName,
      String mimeType = 'text/plain;charset=utf-8'}) {
    if (!kIsWeb) return;
    final utf8Bytes = _encodeUtf8(content);
    downloadFile(utf8Bytes, fileName: fileName, mimeType: mimeType);
  }

  static void downloadAuto(Uint8List bytes,
      {String fileName = 'audio', int sampleRate = 24000}) {
    if (!kIsWeb) return;
    if (isWav(bytes)) {
      webImpl.jsDownloadBlob(bytes, 'audio/wav',
          fileName.endsWith('.wav') ? fileName : '$fileName.wav');
    } else if (isMp3(bytes)) {
      webImpl.jsDownloadBlob(bytes, 'audio/mpeg',
          fileName.endsWith('.mp3') ? fileName : '$fileName.mp3');
    } else {
      final wav = pcmToWav(bytes, sampleRate: sampleRate);
      webImpl.jsDownloadBlob(wav, 'audio/wav',
          fileName.endsWith('.wav') ? fileName : '$fileName.wav');
    }
  }

  // ─── 오디오 포맷 유틸리티 ───────────────────────────────

  /// PCM raw → WAV 파일 변환 (44바이트 헤더 추가)
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
    // RIFF 청크
    header.setUint8(o++, 0x52); header.setUint8(o++, 0x49);
    header.setUint8(o++, 0x46); header.setUint8(o++, 0x46);
    header.setUint32(o, 36 + dataSize, Endian.little); o += 4;
    // WAVE 청크
    header.setUint8(o++, 0x57); header.setUint8(o++, 0x41);
    header.setUint8(o++, 0x56); header.setUint8(o++, 0x45);
    // fmt 청크
    header.setUint8(o++, 0x66); header.setUint8(o++, 0x6D);
    header.setUint8(o++, 0x74); header.setUint8(o++, 0x20);
    header.setUint32(o, 16, Endian.little); o += 4;
    header.setUint16(o, 1, Endian.little); o += 2;  // PCM
    header.setUint16(o, numChannels, Endian.little); o += 2;
    header.setUint32(o, sampleRate, Endian.little); o += 4;
    header.setUint32(o, byteRate, Endian.little); o += 4;
    header.setUint16(o, blockAlign, Endian.little); o += 2;
    header.setUint16(o, bitsPerSample, Endian.little); o += 2;
    // data 청크
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
