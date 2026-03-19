// 웹 전용 구현 (dart:js_interop 사용)
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

void jsPlayBlob(Uint8List bytes, String mimeType) {
  try {
    final b64 = base64Encode(bytes);
    _tubeMasterPlayBlob(b64.toJS, mimeType.toJS);
  } catch (_) {}
}

void jsDownloadBlob(Uint8List bytes, String mimeType, String fileName) {
  try {
    final b64 = base64Encode(bytes);
    _tubeMasterDownloadBlob(b64.toJS, mimeType.toJS, fileName.toJS);
  } catch (_) {}
}

void jsStopAudio() {
  try {
    _tubeMasterStopAudio();
  } catch (_) {}
}

void jsDownloadBase64(String b64, String mimeType, String fileName) {
  try {
    _tubeMasterDownloadBase64(b64.toJS, mimeType.toJS, fileName.toJS);
  } catch (_) {}
}

@JS('tubeMasterPlayBlob')
external void _tubeMasterPlayBlob(JSString base64Data, JSString mimeType);

@JS('tubeMasterDownloadBlob')
external void _tubeMasterDownloadBlob(
    JSString base64Data, JSString mimeType, JSString filename);

@JS('tubeMasterStopAudio')
external void _tubeMasterStopAudio();

@JS('tubeMasterDownloadBase64')
external void _tubeMasterDownloadBase64(
    JSString base64Data, JSString mimeType, JSString filename);
