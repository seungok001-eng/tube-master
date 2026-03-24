import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/channel_model.dart';
import '../models/project_model.dart';
import '../utils/web_audio_helper.dart';

// ─────────────────────────────────────────────────────
// Gemini 서비스 (텍스트 생성 + 이미지 생성 + TTS)
// ─────────────────────────────────────────────────────
class GeminiService {
  final String apiKey;
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  GeminiService(this.apiKey);

  // ────────────────────────────
  // 대본 생성
  // ────────────────────────────
  Future<String> generateScript({
    required String prompt,
    required String topic,
    required int targetMinutes,
    required ScriptAiModel model,
  }) async {
    final userPrompt = '''
주제: $topic
목표 영상 길이: $targetMinutes분 (약 ${targetMinutes * 150}~${targetMinutes * 200}자 분량)

위 주제로 유튜브 영상 대본을 작성해주세요.
대본만 작성하고 제목, 설명 등 부가적인 내용은 포함하지 마세요.
자연스럽게 말하는 것처럼 구어체로 작성해주세요.
''';

    return await _callGemini(
      systemPrompt: prompt,
      userMessage: userPrompt,
      model: model.apiModelId,
    );
  }

  // ────────────────────────────
  // 인트로 5가지 버전 생성
  // ────────────────────────────
  /// 주제와 채널 성격에 맞는 인트로 5가지를 생성합니다.
  /// [introPrompt]: 사용자가 설정한 인트로 스타일 프롬프트 (비어있으면 채널 기본값 사용)
  /// 반환값: 5개 인트로 텍스트 리스트
  Future<List<String>> generateIntroVariants({
    required String topic,
    required ChannelType channelType,
    required ScriptAiModel model,
    String introPrompt = '',
  }) async {
    final styleGuide = introPrompt.isNotEmpty
        ? '인트로 작성 스타일: $introPrompt'
        : _defaultIntroStyle(channelType);

    final systemPrompt = '''
당신은 유튜브 채널 인트로 전문 작가입니다.
채널 유형: ${channelType.displayName}
$styleGuide

인트로 작성 규칙:
- 시청자가 첫 5~15초 안에 영상을 계속 볼지 결정합니다
- 강렬한 hook(궁금증/충격/공감)으로 시작하세요
- 구어체, 자연스러운 말투
- 각 버전은 서로 다른 스타일/접근법을 사용하세요
- 각 인트로는 2~4문장, 50~120자 분량
''';

    final userMessage = '''
주제: $topic

위 주제로 스타일이 완전히 다른 인트로 5가지를 작성해주세요.
반드시 아래 JSON 형식으로만 응답하세요:

{
  "intros": [
    {"style": "충격/반전", "text": "인트로 텍스트 1"},
    {"style": "질문/호기심", "text": "인트로 텍스트 2"},
    {"style": "공감/감정", "text": "인트로 텍스트 3"},
    {"style": "통계/사실", "text": "인트로 텍스트 4"},
    {"style": "스토리텔링", "text": "인트로 텍스트 5"}
  ]
}
''';

    final response = await _callGemini(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      model: model.apiModelId,
    );

    try {
      String cleaned = response.trim();
      if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7);
      if (cleaned.startsWith('```')) cleaned = cleaned.substring(3);
      if (cleaned.endsWith('```')) cleaned = cleaned.substring(0, cleaned.length - 3);

      final parsed = jsonDecode(cleaned.trim()) as Map<String, dynamic>;
      final intros = parsed['intros'] as List<dynamic>;
      return intros.map<String>((item) {
        final style = item['style'] as String? ?? '';
        final text = item['text'] as String? ?? '';
        return '[$style]\n$text';
      }).toList();
    } catch (e) {
      // JSON 파싱 실패 시 텍스트를 라인 단위로 분리
      final lines = response.split('\n').where((l) => l.trim().isNotEmpty).toList();
      return lines.take(5).toList();
    }
  }

  String _defaultIntroStyle(ChannelType type) {
    switch (type) {
      case ChannelType.economy:
        return '경제적 충격 수치나 반전으로 시작, "이 영상을 보면 돈이 보입니다" 스타일';
      case ChannelType.psychology:
        return '심리적 통찰이나 반전으로 시작, 시청자의 자기 인식을 자극하는 스타일';
      case ChannelType.history:
        return '역사적 사실의 충격적 반전이나 "사실 이랬습니다" 스타일';
      case ChannelType.folklore:
        return '야담/설화의 신비로운 분위기로 시작, 옛날 이야기 느낌';
      case ChannelType.patriot:
        return '한국의 위대함이나 자부심을 자극하는 강렬한 시작';
      case ChannelType.story:
        return '공감을 자극하는 감성적 시작, 독자의 경험과 연결';
      case ChannelType.bible:
        return '성경 말씀이나 영적 통찰로 시작, 위안과 희망을 주는 스타일';
      case ChannelType.buddhism:
        return '불교 철학적 질문이나 깨달음으로 시작하는 스타일';
      case ChannelType.asmr:
        return '부드럽고 편안한 분위기를 조성하는 차분한 시작';
      case ChannelType.playlist:
        return '음악의 분위기나 감정을 소개하는 따뜻한 시작';
    }
  }

  // ────────────────────────────
  // 장면 분할
  // ────────────────────────────
  Future<List<Map<String, String>>> splitScenes({
    required String script,
    required ChannelType channelType,
  }) async {
    const systemPrompt = '''
당신은 영상 편집 전문가입니다. 주어진 대본을 영상 장면으로 분할하는 역할을 합니다.

규칙:
1. 대본을 의미 단위로 분할하되 각 장면은 10~30초 분량(약 50~120자)이 되도록 합니다
2. 각 장면에 어울리는 이미지 생성 프롬프트를 영어로 작성합니다
3. 반드시 아래 JSON 형식으로만 응답하세요 (코드블록 없이 순수 JSON만)
4. imagePrompt는 간결하게 100자 이내 영어로 작성하세요

응답 형식:
[
  {
    "script": "장면 대본 텍스트",
    "imagePrompt": "English image prompt (keep under 100 chars)"
  }
]
''';

    // ── 대본 길이별 처리 전략 ──
    // • ~8000자:  단일 요청 (한 번에 처리)
    // • ~30000자: 8000자 청크 × 병렬 처리 (최대 4개 동시)
    // • 30000자+: 8000자 청크 × 병렬 처리 (세마포어 4개 제한)
    const singleLimit = 8000;
    const chunkSize   = 8000;

    if (script.length <= singleLimit) {
      // 단일 요청
      final response = await _callGeminiLarge(
        systemPrompt: systemPrompt,
        userMessage: '다음 대본을 장면으로 분할해주세요:\n\n$script',
        model: 'gemini-3-flash-preview',  // 최신 모델 (2025.12)
      );
      return _parseSceneJson(response);
    }

    // 긴 대본: 청크 병렬 처리
    return await _splitScenesInChunks(script, systemPrompt, chunkSize);
  }

  // 긴 대본을 청크로 나눠 병렬 분할 처리
  Future<List<Map<String, String>>> _splitScenesInChunks(
      String script, String systemPrompt, int chunkSize) async {

    // 1. 청크 목록 생성 (문장 경계에서 자르기)
    final chunks = <String>[];
    int offset = 0;
    while (offset < script.length) {
      int end = (offset + chunkSize).clamp(0, script.length);
      if (end < script.length) {
        // 문장 끊김 방지: 마지막 줄바꿈/마침표 위치에서 자르기
        final cutPos = script.lastIndexOf(RegExp(r'[\n.!?]'), end);
        if (cutPos > offset + 1000) end = cutPos + 1;
      }
      final chunk = script.substring(offset, end).trim();
      if (chunk.isNotEmpty) chunks.add(chunk);
      offset = end;
    }

    // 2. 병렬 처리 - _Semaphore 대신 직접 구현 (최대 4개 동시)
    final results = List<List<Map<String, String>>?>.filled(chunks.length, null);
    final errors  = List<Object?>.filled(chunks.length, null);
    int _running = 0;
    final _lock = <Completer<void>>[];

    Future<void> acquire() async {
      if (_running < 4) { _running++; return; }
      final c = Completer<void>();
      _lock.add(c);
      await c.future;
      _running++;
    }

    void release() {
      _running--;
      if (_lock.isNotEmpty) {
        final c = _lock.removeAt(0);
        c.complete();
      }
    }

    final futures = List.generate(chunks.length, (idx) async {
      await acquire();
      try {
        final response = await _callGeminiLarge(
          systemPrompt: systemPrompt,
          userMessage: '다음 대본을 장면으로 분할해주세요'
              '${chunks.length > 1 ? " (파트 ${idx + 1}/${chunks.length})" : ""}:\n\n${chunks[idx]}',
          model: 'gemini-3-flash-preview',
        );
        results[idx] = _parseSceneJson(response);
      } catch (e) {
        errors[idx] = e;  // ✅ 버그 수정: 에러 저장 (이전엔 무시됨)
      } finally {
        release();
      }
    });

    // 3. 모든 청크 완료 대기
    await Future.wait(futures);

    // 4. 에러 확인 - 하나라도 실패하면 예외 발생
    for (int i = 0; i < errors.length; i++) {
      if (errors[i] != null) {
        throw Exception('파트 ${i + 1} 분할 실패: ${errors[i]}');
      }
    }

    // 5. 순서 보장하여 합치기
    final allScenes = <Map<String, String>>[];
    for (final sceneList in results) {
      if (sceneList != null) allScenes.addAll(sceneList);
    }
    return allScenes;
  }

  // JSON 파싱 + 잘린 JSON 자동 복구
  List<Map<String, String>> _parseSceneJson(String response) {
    try {
      String cleaned = response.trim();
      // 코드블록 제거
      if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7);
      else if (cleaned.startsWith('```')) cleaned = cleaned.substring(3);
      if (cleaned.endsWith('```')) cleaned = cleaned.substring(0, cleaned.length - 3);
      cleaned = cleaned.trim();

      // 1차 시도: 정상 파싱
      try {
        final List<dynamic> parsed = jsonDecode(cleaned);
        return _mapSceneList(parsed);
      } catch (_) {}

      // 2차 시도: JSON 배열 부분 추출
      final startIdx = cleaned.indexOf('[');
      if (startIdx >= 0) {
        final jsonPart = cleaned.substring(startIdx);
        // 완전한 마지막 객체 위치 찾기 (잘린 JSON 복구)
        final recovered = _recoverTruncatedJsonArray(jsonPart);
        if (recovered != null) {
          final List<dynamic> parsed = jsonDecode(recovered);
          return _mapSceneList(parsed);
        }
      }

      throw Exception('JSON 파싱 불가');
    } catch (e) {
      throw Exception('장면 분할 파싱 오류: $e\n응답: ${response.substring(0, response.length.clamp(0, 300))}...');
    }
  }

  List<Map<String, String>> _mapSceneList(List<dynamic> parsed) {
    return parsed.map<Map<String, String>>((item) => {
      'script': item['script']?.toString() ?? '',
      'imagePrompt': item['imagePrompt']?.toString() ?? '',
    }).toList();
  }

  // 잘린 JSON 배열 복구: 완전한 마지막 객체까지만 추출
  String? _recoverTruncatedJsonArray(String jsonStr) {
    // 완성된 객체들만 추출: }, 패턴으로 마지막 완전한 객체 뒤를 찾음
    int lastValidEnd = -1;
    int depth = 0;
    bool inString = false;
    bool escape = false;

    for (int i = 0; i < jsonStr.length; i++) {
      final ch = jsonStr[i];
      if (escape) { escape = false; continue; }
      if (ch == '\\' && inString) { escape = true; continue; }
      if (ch == '"') { inString = !inString; continue; }
      if (inString) continue;

      if (ch == '{' || ch == '[') depth++;
      else if (ch == '}' || ch == ']') {
        depth--;
        if (depth == 1 && ch == '}') {
          // 배열 내 객체 하나가 완전히 닫힘
          lastValidEnd = i;
        }
        if (depth == 0) {
          // 전체 배열이 완전히 닫힘
          return jsonStr.substring(0, i + 1);
        }
      }
    }

    // 배열이 잘린 경우: 마지막 완전한 객체까지 + ']' 추가
    if (lastValidEnd > 0) {
      return '${jsonStr.substring(0, lastValidEnd + 1)}]';
    }
    return null;
  }

  // 출력 토큰이 충분한 Gemini 호출 (장면 분할 전용)
  Future<String> _callGeminiLarge({
    required String systemPrompt,
    required String userMessage,
    required String model,
  }) async {
    final url = '$_baseUrl/models/$model:generateContent?key=$apiKey';
    final body = jsonEncode({
      'system_instruction': {
        'parts': [{'text': systemPrompt}]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': userMessage}]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 65535,  // 최대 출력 토큰 (잘림 방지)
        'responseMimeType': 'application/json',  // JSON 모드로 강제
      }
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(minutes: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // finishReason 확인 (MAX_TOKENS이면 잘린 것)
      final finishReason = data['candidates']?[0]?['finishReason'] ?? '';
      final text = data['candidates'][0]['content']['parts'][0]['text'] ?? '';
      if (finishReason == 'MAX_TOKENS') {
        // 잘렸지만 복구 시도를 위해 그냥 반환 (파서에서 복구)
        return text;
      }
      return text;
    } else {
      String errMsg = 'Gemini API 오류 (${response.statusCode})';
      try {
        final errData = jsonDecode(response.body);
        errMsg = '❌ Gemini API 오류: ${errData['error']?['message'] ?? ''}';
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  // ────────────────────────────
  // 이미지 생성 (Gemini Imagen)
  // ────────────────────────────
  /// [prompt]: 영어로 작성된 이미지 프롬프트
  /// [aspectRatio]: "1:1", "16:9", "9:16", "4:3", "3:4"
  /// 반환값: base64 인코딩된 PNG/JPEG 바이트
  Future<Uint8List> generateImage({
    required String prompt,
    String aspectRatio = '16:9',
    String model = 'imagen-3.0-generate-002',
  }) async {
    // Imagen API 엔드포인트
    final url = '$_baseUrl/models/$model:predict?key=$apiKey';

    final body = jsonEncode({
      'instances': [
        {'prompt': prompt}
      ],
      'parameters': {
        'sampleCount': 1,
        'aspectRatio': aspectRatio,
        'safetyFilterLevel': 'block_only_high',
        'personGeneration': 'allow_adult',
      }
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(minutes: 3));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final predictions = data['predictions'] as List?;
      if (predictions == null || predictions.isEmpty) {
        throw Exception('이미지 생성 결과가 없습니다.');
      }
      final b64 = predictions[0]['bytesBase64Encoded'] as String?;
      if (b64 == null || b64.isEmpty) {
        throw Exception('이미지 데이터가 없습니다.');
      }
      return base64Decode(b64);
    } else {
      String errMsg = 'Imagen API 오류 (${response.statusCode})';
      try {
        final errData = jsonDecode(response.body);
        final code = errData['error']?['code'];
        final msg = errData['error']?['message'] ?? '';
        if (code == 400) {
          errMsg = '❌ 이미지 프롬프트 오류. 내용을 수정하거나 Safety Filter를 확인하세요.\n($msg)';
        } else if (code == 401 || code == 403) {
          errMsg = '❌ Gemini API 키가 올바르지 않거나 Imagen 접근 권한이 없습니다.';
        } else if (code == 429) {
          errMsg = '⚠️ 이미지 생성 한도 초과입니다. 잠시 후 다시 시도해주세요.';
        } else {
          errMsg = '❌ Imagen API 오류: $msg';
        }
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  // ────────────────────────────
  // Gemini 네이티브 이미지 생성 (Nano Banana 계열)
  // ────────────────────────────
  /// model: gemini-3.1-flash-image-preview (Nano Banana 2, 기본)
  ///        gemini-3-pro-image-preview      (Nano Banana Pro)
  ///        gemini-2.5-flash-image          (Nano Banana Stable)
  Future<Uint8List> generateImageWithFlash({
    required String prompt,
    String aspectRatio = '16:9',
    String model = 'gemini-3.1-flash-image-preview',
    String imageSize = '1K',   // "512"(Flash만), "1K", "2K", "4K"
  }) async {
    final url = '$_baseUrl/models/$model:generateContent?key=$apiKey';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseModalities': ['TEXT', 'IMAGE'],
        'imageConfig': {
          'aspectRatio': aspectRatio,
          'imageSize': imageSize,
        },
      }
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: body,
    ).timeout(const Duration(minutes: 3));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('이미지 생성 결과가 없습니다.');
      }
      final parts = candidates[0]['content']['parts'] as List?;
      if (parts == null) throw Exception('이미지 데이터가 없습니다.');

      for (final part in parts) {
        if (part['inlineData'] != null) {
          final b64 = part['inlineData']['data'] as String?;
          if (b64 != null && b64.isNotEmpty) {
            return base64Decode(b64);
          }
        }
      }
      throw Exception('이미지 데이터를 찾을 수 없습니다.');
    } else {
      String errMsg = 'Gemini 이미지 생성 오류 (${response.statusCode})';
      try {
        final errData = jsonDecode(response.body);
        final code = errData['error']?['code'];
        final msg = errData['error']?['message'] ?? '';
        if (code == 400) {
          errMsg = '❌ 이미지 프롬프트 오류 또는 안전 필터에 걸렸습니다.\n($msg)';
        } else if (code == 401 || code == 403) {
          errMsg = '❌ API 키 오류 또는 이미지 생성 권한이 없습니다.\n($msg)';
        } else if (code == 404) {
          errMsg = '❌ 모델을 찾을 수 없습니다. ($model)\n($msg)';
        } else if (code == 429) {
          errMsg = '⚠️ API 호출 한도 초과. 잠시 후 다시 시도해주세요.';
        } else {
          errMsg = '❌ 이미지 생성 오류 ($code): $msg';
        }
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  // ────────────────────────────
  // Gemini TTS (텍스트 → 음성)
  // ────────────────────────────
  /// 반환값: MP3/WAV 오디오 바이트 (base64 디코딩됨)
  Future<Uint8List> generateTts({
    required String text,
    String voiceName = 'Kore',
    double speakingRate = 1.0,
  }) async {
    // 공식 문서 기준: x-goog-api-key 헤더 방식 사용
    // https://ai.google.dev/gemini-api/docs/speech-generation
    const model = 'gemini-2.5-flash-preview-tts';
    final url = '$_baseUrl/models/$model:generateContent';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [{'text': text}]
        }
      ],
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {
              'voiceName': voiceName,
            }
          },
        }
      }
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,   // 헤더 방식 (공식 문서 기준)
      },
      body: requestBody,
    ).timeout(const Duration(minutes: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        // finishReason 확인
        final promptFeedback = data['promptFeedback'];
        final blockReason = promptFeedback?['blockReason'];
        if (blockReason != null) {
          throw Exception('콘텐츠 차단됨: $blockReason');
        }
        throw Exception('TTS 생성 결과가 없습니다. (candidates 없음)');
      }

      final content = candidates[0]['content'];
      if (content == null) throw Exception('오디오 content가 없습니다.');
      final parts = content['parts'] as List?;
      if (parts == null || parts.isEmpty) throw Exception('오디오 parts가 없습니다.');

      for (final part in parts) {
        final inlineData = part['inlineData'];
        if (inlineData != null) {
          final b64 = inlineData['data'] as String?;
          final mimeType = inlineData['mimeType'] as String? ?? '';
          if (b64 != null && b64.isNotEmpty) {
            final rawBytes = base64Decode(b64);

            // Gemini TTS 반환 형식: audio/L16;codec=pcm;rate=24000 (RAW PCM 16bit)
            // just_audio / Windows Media Player가 재생할 수 있도록 WAV 헤더 추가
            if (mimeType.contains('L16') ||
                mimeType.contains('pcm') ||
                mimeType.contains('raw') ||
                (!WebAudioHelper.isWav(rawBytes) && !WebAudioHelper.isMp3(rawBytes))) {
              // mimeType에서 sampleRate 파싱 (예: audio/L16;codec=pcm;rate=24000)
              int sampleRate = 24000;
              final rateMatch = RegExp(r'rate=(\d+)').firstMatch(mimeType);
              if (rateMatch != null) {
                sampleRate = int.tryParse(rateMatch.group(1)!) ?? 24000;
              }
              return WebAudioHelper.pcmToWav(rawBytes, sampleRate: sampleRate);
            }
            return rawBytes;
          }
        }
      }
      throw Exception('오디오 데이터를 찾을 수 없습니다.\nmimeType 또는 data 누락');
    } else {
      // 오류 응답 상세 파싱
      String errMsg = 'Gemini TTS 오류 (${response.statusCode})';
      try {
        final errData = jsonDecode(response.body);
        final errorObj = errData['error'];
        final code = errorObj?['code'];
        final msg = errorObj?['message'] as String? ?? '';
        final status = errorObj?['status'] as String? ?? '';

        if (response.statusCode == 400 && msg.contains('API_KEY_INVALID')) {
          errMsg = '❌ Gemini API 키가 유효하지 않습니다.\n설정에서 API 키를 확인해주세요.';
        } else if (code == 401 || code == 403 || status == 'UNAUTHENTICATED') {
          errMsg = '❌ Gemini API 인증 실패\nAPI 키를 확인해주세요.';
        } else if (code == 429 || status == 'RESOURCE_EXHAUSTED') {
          errMsg = '⚠️ Gemini API 사용량 한도 초과\n잠시 후 다시 시도해주세요.';
        } else if (response.statusCode == 404 || msg.contains('not found')) {
          errMsg = '⚠️ Gemini TTS 모델을 사용할 수 없습니다.\n'
              'Gemini API 키가 TTS(유료) 기능을 지원해야 합니다.\n'
              '→ Google AI Studio에서 결제 설정 확인\n'
              '오류: $msg';
        } else if (msg.contains('not supported') || status == 'INVALID_ARGUMENT') {
          errMsg = '⚠️ TTS 요청 오류: $msg\n'
              'voiceName($voiceName)이 올바른지 확인해주세요.';
        } else {
          errMsg = '❌ Gemini TTS 오류 ($code / ${response.statusCode})\n$msg';
        }
      } catch (_) {
        final bodyPreview = response.body.length > 300
            ? response.body.substring(0, 300)
            : response.body;
        errMsg = 'Gemini TTS 오류 (${response.statusCode})\n$bodyPreview';
      }
      throw Exception(errMsg);
    }
  }

  // ────────────────────────────
  // YouTube 메타데이터 생성
  // ────────────────────────────
  Future<Map<String, dynamic>> generateYoutubeMetadata({
    required String script,
    required ChannelType channelType,
    required String channelName,
  }) async {
    const systemPrompt = '''
당신은 YouTube SEO 전문가입니다.
주어진 대본을 바탕으로 YouTube 업로드에 필요한 메타데이터를 생성합니다.
반드시 아래 JSON 형식으로만 응답하세요:

{
  "title": "클릭하고 싶은 매력적인 제목 (50자 이내)",
  "description": "SEO 최적화된 설명 (500자 이내, 해시태그 포함)",
  "tags": ["태그1", "태그2", "태그3", "태그4", "태그5", "태그6", "태그7", "태그8", "태그9", "태그10"]
}
''';

    final response = await _callGemini(
      systemPrompt: systemPrompt,
      userMessage: '채널명: $channelName\n채널유형: ${channelType.displayName}\n\n대본 요약:\n${script.substring(0, script.length.clamp(0, 2000))}',
      model: 'gemini-2.5-flash',
    );

    try {
      String cleaned = response.trim();
      if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7);
      if (cleaned.startsWith('```')) cleaned = cleaned.substring(3);
      if (cleaned.endsWith('```')) cleaned = cleaned.substring(0, cleaned.length - 3);
      return jsonDecode(cleaned.trim());
    } catch (e) {
      return {
        'title': '제목을 입력하세요',
        'description': '',
        'tags': <String>[],
      };
    }
  }

  // ────────────────────────────
  // 썸네일 텍스트 생성
  // ────────────────────────────
  Future<String> generateThumbnailText(String script, ChannelType channelType) async {
    const systemPrompt = '유튜브 썸네일에 들어갈 강렬하고 클릭을 유도하는 짧은 텍스트를 2줄로 작성해주세요. 각 줄은 10자 이내로 작성하고 줄바꿈으로 구분하세요.';
    return await _callGemini(
      systemPrompt: systemPrompt,
      userMessage: '대본: ${script.substring(0, script.length.clamp(0, 500))}',
      model: 'gemini-2.5-flash',
    );
  }

  // ────────────────────────────
  // 내부: Gemini 텍스트 API 호출
  // ────────────────────────────
  Future<String> _callGemini({
    required String systemPrompt,
    required String userMessage,
    required String model,
  }) async {
    final url = '$_baseUrl/models/$model:generateContent?key=$apiKey';
    final body = jsonEncode({
      'system_instruction': {
        'parts': [{'text': systemPrompt}]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': userMessage}]
        }
      ],
      'generationConfig': {
        'temperature': 0.9,
        'maxOutputTokens': 8192,
      }
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(minutes: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] ?? '';
    } else {
      String errMsg = 'Gemini API 오류 (${response.statusCode})';
      try {
        final errData = jsonDecode(response.body);
        final code = errData['error']?['code'];
        final msg = errData['error']?['message'] ?? '';
        if (code == 400) {
          errMsg = '❌ 잘못된 요청입니다. API 키를 확인해주세요.';
        } else if (code == 401 || code == 403) {
          errMsg = '❌ API 키가 올바르지 않습니다.\n설정 화면에서 Gemini API 키를 확인해주세요.';
        } else if (code == 404) {
          errMsg = '❌ 모델을 찾을 수 없습니다.\n($msg)';
        } else if (code == 429) {
          errMsg = '⚠️ API 사용량 한도 초과입니다.\n잠시 후 다시 시도해주세요.';
        } else if (code == 500) {
          errMsg = '⚠️ Gemini 서버 오류입니다. 잠시 후 다시 시도해주세요.';
        } else {
          errMsg = '❌ Gemini API 오류: $msg';
        }
      } catch (_) {}
      throw Exception(errMsg);
    }
  }
}

// ─────────────────────────────────────────────────────
// ElevenLabs TTS 서비스
// ─────────────────────────────────────────────────────
class ElevenLabsService {
  final String apiKey;
  static const String _baseUrl = 'https://api.elevenlabs.io/v1';

  ElevenLabsService(this.apiKey);

  /// [text]: 변환할 텍스트
  /// [voiceId]: ElevenLabs Voice ID (기본: Rachel)
  /// [stability]: 0.0~1.0 (기본 0.5)
  /// [similarityBoost]: 0.0~1.0 (기본 0.75)
  /// 반환: MP3 오디오 바이트
  Future<Uint8List> generateTts({
    required String text,
    String voiceId = '21m00Tcm4TlvDq8ikWAM', // Rachel (기본)
    double stability = 0.5,
    double similarityBoost = 0.75,
    double speed = 1.0,
  }) async {
    final url = '$_baseUrl/text-to-speech/$voiceId';

    final body = jsonEncode({
      'text': text,
      'model_id': 'eleven_multilingual_v2',
      'voice_settings': {
        'stability': stability,
        'similarity_boost': similarityBoost,
        'speed': speed,
      }
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      },
      body: body,
    ).timeout(const Duration(minutes: 5));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      String errMsg = 'ElevenLabs API 오류 (${response.statusCode})';
      try {
        final errData = jsonDecode(response.body);
        final detail = errData['detail']?['message'] ?? errData['detail'] ?? '';
        if (response.statusCode == 401) {
          errMsg = '❌ ElevenLabs API 키가 올바르지 않습니다.';
        } else if (response.statusCode == 422) {
          errMsg = '❌ Voice ID가 올바르지 않습니다: $voiceId';
        } else if (response.statusCode == 429) {
          errMsg = '⚠️ ElevenLabs 사용량 한도 초과입니다.';
        } else {
          errMsg = '❌ ElevenLabs 오류: $detail';
        }
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  /// 사용 가능한 목소리 목록 조회 (API 키 필요)
  Future<List<Map<String, String>>> getVoices() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/voices'),
      headers: {'xi-api-key': apiKey},
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final voices = data['voices'] as List? ?? [];
      return voices.map<Map<String, String>>((v) => {
        'id': v['voice_id']?.toString() ?? '',
        'name': v['name']?.toString() ?? '',
        'category': v['category']?.toString() ?? '',
        'description': v['description']?.toString() ?? '',
        'preview_url': v['preview_url']?.toString() ?? '',
        'labels': (v['labels'] as Map?)?.values.join(', ') ?? '',
      }).toList();
    }
    return [];
  }

  /// 목소리 미리듣기 - 샘플 텍스트로 TTS 생성
  Future<Uint8List> previewVoice({
    required String voiceId,
    String lang = 'ko',
  }) async {
    const sampleTexts = {
      'ko': '안녕하세요. 저는 이 목소리로 콘텐츠를 만들어 드립니다.',
      'en': 'Hello! I can help you create amazing content with this voice.',
      'ja': 'こんにちは。このボイスでコンテンツを作成します。',
    };
    final text = sampleTexts[lang] ?? sampleTexts['ko']!;
    return generateTts(text: text, voiceId: voiceId);
  }
}

// ─────────────────────────────────────────────────────
// Naver CLOVA TTS 서비스
// ─────────────────────────────────────────────────────
class ClovaTtsService {
  final String clientId;
  final String clientSecret;
  static const String _baseUrl = 'https://naveropenapi.apigw.ntruss.com/tts-premium/v1/tts';

  ClovaTtsService({required this.clientId, required this.clientSecret});

  /// [text]: 변환할 텍스트 (최대 2000자)
  /// [speaker]: 음성 ID (nara, nminseo, njinho 등)
  /// [speed]: -5~5 (0 기본)
  /// [pitch]: -5~5 (0 기본)
  /// [volume]: -5~5 (0 기본)
  /// 반환: MP3 오디오 바이트
  Future<Uint8List> generateTts({
    required String text,
    String speaker = 'nara',
    int speed = 0,
    int pitch = 0,
    int volume = 0,
    String format = 'mp3',
  }) async {
    // CLOVA는 한 번에 2000자까지만 처리 가능
    final chunk = text.length > 2000 ? text.substring(0, 2000) : text;

    final body = {
      'speaker': speaker,
      'volume': volume.toString(),
      'speed': speed.toString(),
      'pitch': pitch.toString(),
      'text': chunk,
      'format': format,
    };

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'X-NCP-APIGW-API-KEY-ID': clientId,
        'X-NCP-APIGW-API-KEY': clientSecret,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    ).timeout(const Duration(minutes: 3));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      // 실제 오류 응답 내용을 최대한 상세히 파싱
      String errMsg = 'CLOVA TTS 오류 (${response.statusCode})';
      String rawBody = '';
      try {
        rawBody = response.body;
        final errData = jsonDecode(rawBody);
        final errorObj = errData['error'];
        final msg = errorObj is Map
            ? (errorObj['message'] ?? errorObj['details'] ?? '')
            : (errData['message'] ?? rawBody);
        final errorCode = errData['errorCode'] ?? errData['code'] ?? '';

        if (response.statusCode == 401 || response.statusCode == 403) {
          errMsg = '❌ CLOVA API 인증 실패 (${response.statusCode})\n'
              '- Client ID: $clientId\n'
              '- 오류: $msg\n'
              '코드: $errorCode\n\n'
              '네이버 클라우드 콘솔에서 Application에 CLOVA Voice 서비스가 등록되어 있는지 확인하세요.';
        } else if (response.statusCode == 429) {
          errMsg = '⚠️ CLOVA API 사용량 한도 초과입니다.';
        } else if (response.statusCode == 400) {
          errMsg = '❌ CLOVA TTS 요청 오류 (400): $msg\n코드: $errorCode';
        } else {
          errMsg = '❌ CLOVA TTS 오류 (${response.statusCode}): $msg\n코드: $errorCode';
        }
      } catch (_) {
        errMsg = 'CLOVA TTS 오류 (${response.statusCode})\n응답: ${rawBody.length > 300 ? rawBody.substring(0, 300) : rawBody}';
      }
      throw Exception(errMsg);
    }
  }
}

// ─────────────────────────────────────────────────────
// Claude 서비스 (대본 생성)
// ─────────────────────────────────────────────────────
class ClaudeService {
  final String apiKey;
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';

  ClaudeService(this.apiKey);

  Future<String> generateScript({
    required String prompt,
    required String topic,
    required int targetMinutes,
    required ScriptAiModel model,
  }) async {
    final userPrompt = '''
주제: $topic
목표 영상 길이: $targetMinutes분 (약 ${targetMinutes * 150}~${targetMinutes * 200}자 분량)

위 주제로 유튜브 영상 대본을 작성해주세요.
대본만 작성하고 제목, 설명 등 부가적인 내용은 포함하지 마세요.
자연스럽게 말하는 것처럼 구어체로 작성해주세요.
''';

    final body = jsonEncode({
      'model': model.apiModelId,
      'max_tokens': 8192,
      'system': prompt,
      'messages': [
        {'role': 'user', 'content': userPrompt}
      ]
    });

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: body,
    ).timeout(const Duration(minutes: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'] ?? '';
    } else {
      String errMsg = 'Claude API 오류 (${response.statusCode})';
      try {
        final errData = jsonDecode(response.body);
        final type = errData['error']?['type'] ?? '';
        final msg = errData['error']?['message'] ?? '';
        if (response.statusCode == 401) {
          errMsg = '❌ Claude API 키가 올바르지 않습니다.\n설정 화면에서 API 키를 확인해주세요.';
        } else if (response.statusCode == 429) {
          errMsg = '⚠️ Claude API 사용량 한도 초과입니다.\n잠시 후 다시 시도해주세요.';
        } else if (type == 'invalid_request_error') {
          errMsg = '❌ 잘못된 요청입니다: $msg';
        } else {
          errMsg = '❌ Claude API 오류: $msg';
        }
      } catch (_) {}
      throw Exception(errMsg);
    }
  }
}

// ─────────────────────────────────────────────────────
// 유틸리티: 긴 텍스트를 청크 단위로 TTS 처리
// ─────────────────────────────────────────────────────
class TtsChunkProcessor {
  /// 긴 텍스트를 chunkSize 단위로 나눠서 여러 번 TTS 생성
  static List<String> splitTextIntoChunks(String text, {int chunkSize = 1500}) {
    final chunks = <String>[];
    // 문장 단위로 자르기
    final sentences = text.split(RegExp(r'(?<=[.!?。！？])\s*'));
    final buffer = StringBuffer();

    for (final sentence in sentences) {
      if (buffer.length + sentence.length > chunkSize && buffer.isNotEmpty) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }
      buffer.write('$sentence ');
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString().trim());
    return chunks.isEmpty ? [text] : chunks;
  }

  /// 여러 오디오 바이트를 단순 연결
  /// WAV 파일들을 합칠 때는 헤더를 제거하고 PCM 데이터만 합쳐서 새 WAV 생성
  static Uint8List combineAudioBytes(List<Uint8List> chunks,
      {int sampleRate = 24000}) {
    if (chunks.isEmpty) return Uint8List(0);
    if (chunks.length == 1) return chunks[0];

    // 각 청크가 WAV 파일인지 확인
    final bool allWav =
        chunks.every((c) => WebAudioHelper.isWav(c));

    if (allWav) {
      // WAV 헤더(44 bytes) 제거하고 PCM 데이터만 합치기
      final pcmChunks = chunks.map((c) {
        if (c.length > 44) {
          return c.sublist(44);
        }
        return c;
      }).toList();

      int total = pcmChunks.fold(0, (sum, c) => sum + c.length);
      final pcmData = Uint8List(total);
      int offset = 0;
      for (final chunk in pcmChunks) {
        pcmData.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      // 새 WAV 헤더 생성
      return WebAudioHelper.pcmToWav(pcmData, sampleRate: sampleRate);
    } else {
      // WAV가 아닌 경우 단순 연결 (MP3 등)
      int total = chunks.fold(0, (sum, c) => sum + c.length);
      final result = Uint8List(total);
      int offset = 0;
      for (final chunk in chunks) {
        result.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      return result;
    }
  }
}

// ─────────────────────────────────────────────────────
// fal.ai 영상 생성 서비스 (Image-to-Video)
// 지원 모델: Kling v3, Wan v2.6, MiniMax, Vidu Q3,
//           Runway Gen4, Pixverse v5, Seedance v1.5
// ─────────────────────────────────────────────────────
class FalVideoService {
  final String apiKey;
  static const String _baseUrl = 'https://queue.fal.run';
  static const String _statusBase = 'https://queue.fal.run';

  FalVideoService(this.apiKey);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Key $apiKey',
  };

  // ────────────────────────────────────────────
  // 영상 생성 요청 → requestId 반환
  // ────────────────────────────────────────────
  Future<String> createVideoTask({
    required String falModelId,   // e.g. 'fal-ai/kling-video/v3/standard/image-to-video'
    required Uint8List imageBytes,
    required String prompt,
    required String aspectRatio,
    required int duration,
    bool hd = false,
  }) async {
    // 이미지를 base64 data URI로 변환
    final b64 = base64Encode(imageBytes);
    final imageUri = 'data:image/jpeg;base64,$b64';

    final body = <String, dynamic>{
      'image_url': imageUri,
      'prompt': prompt,
      'aspect_ratio': aspectRatio,
      'duration': duration,
    };
    if (hd) body['resolution'] = '1080p';

    final url = '$_baseUrl/$falModelId';
    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(const Duration(minutes: 2));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      // fal.ai 큐 방식: request_id 반환
      final requestId = data['request_id'] as String?
          ?? data['id'] as String?;
      if (requestId == null || requestId.isEmpty) {
        // 즉시 완료된 경우 (동기 응답)
        return '__sync__:${response.body}';
      }
      return requestId;
    } else {
      _throwFalError(response);
    }
    throw Exception('fal.ai 영상 생성 요청 실패');
  }

  // ────────────────────────────────────────────
  // 영상 생성 상태 폴링
  // ────────────────────────────────────────────
  Future<String> pollVideoTask({
    required String falModelId,
    required String requestId,
    int maxWaitSeconds = 300,
    void Function(String status, double progress)? onProgress,
  }) async {
    // 동기 응답인 경우 즉시 URL 추출
    if (requestId.startsWith('__sync__:')) {
      final body = requestId.substring('__sync__:'.length);
      return _extractVideoUrl(jsonDecode(body));
    }

    final deadline = DateTime.now().add(Duration(seconds: maxWaitSeconds));
    int interval = 5;

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(Duration(seconds: interval));

      final statusUrl = '$_statusBase/$falModelId/requests/$requestId/status';
      try {
        final response = await http.get(
          Uri.parse(statusUrl),
          headers: _headers,
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body);
        final status = (data['status'] as String? ?? 'IN_QUEUE').toUpperCase();
        final progress = (data['progress'] as num? ?? 0).toDouble();

        onProgress?.call(status.toLowerCase(), progress);

        if (status == 'COMPLETED') {
          // 결과 가져오기
          final resultUrl = '$_statusBase/$falModelId/requests/$requestId';
          final resultResp = await http.get(
            Uri.parse(resultUrl),
            headers: _headers,
          ).timeout(const Duration(seconds: 30));
          if (resultResp.statusCode == 200) {
            return _extractVideoUrl(jsonDecode(resultResp.body));
          }
        } else if (status == 'FAILED') {
          final errMsg = data['error']?['message'] as String? ?? '알 수 없는 오류';
          throw Exception('fal.ai 영상 생성 실패: $errMsg');
        }

        if (interval < 15) interval = (interval * 1.2).round().clamp(5, 15);
      } catch (e) {
        if (e is Exception && e.toString().contains('fal.ai 영상 생성 실패')) rethrow;
        if (kDebugMode) debugPrint('[FalVideo] 폴링 오류 (재시도): $e');
      }
    }
    throw Exception('fal.ai 영상 생성 시간 초과 ($maxWaitSeconds초)');
  }

  String _extractVideoUrl(Map<String, dynamic> data) {
    final videoUrl = data['video']?['url'] as String?
        ?? data['video_url'] as String?
        ?? data['output']?['video_url'] as String?
        ?? (data['video'] is String ? data['video'] as String : null);
    if (videoUrl == null || videoUrl.isEmpty) {
      throw Exception('fal.ai 영상 URL을 받지 못했습니다. 응답: $data');
    }
    return videoUrl;
  }

  void _throwFalError(http.Response response) {
    String errMsg = 'fal.ai API 오류 (${response.statusCode})';
    try {
      final d = jsonDecode(response.body);
      final msg = d['detail'] as String? ?? d['error']?['message'] as String? ?? '';
      if (response.statusCode == 401 || response.statusCode == 403) {
        errMsg = '❌ fal.ai API 키가 올바르지 않습니다.\n설정에서 fal.ai API 키를 확인해주세요.';
      } else if (response.statusCode == 402) {
        errMsg = '❌ fal.ai 크레딧이 부족합니다.\nhttps://fal.ai 에서 충전해주세요.';
      } else if (response.statusCode == 429) {
        errMsg = '⚠️ fal.ai API 호출 한도 초과. 잠시 후 다시 시도해주세요.';
      } else if (msg.isNotEmpty) {
        errMsg = '❌ fal.ai 오류: $msg';
      }
    } catch (_) {}
    throw Exception(errMsg);
  }

  Future<Uint8List> downloadVideo(String videoUrl) async {
    final response = await http.get(Uri.parse(videoUrl))
        .timeout(const Duration(minutes: 5));
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('영상 다운로드 실패 (${response.statusCode})');
  }

  // ────────────────────────────────────────────
  // 통합 함수: 요청 → 폴링 → 다운로드
  // ────────────────────────────────────────────
  Future<Uint8List> generateVideo({
    required String falModelId,
    required Uint8List imageBytes,
    required String prompt,
    required String aspectRatio,
    required int duration,
    bool hd = false,
    void Function(String status, double progress)? onProgress,
  }) async {
    onProgress?.call('requesting', 0.0);
    final requestId = await createVideoTask(
      falModelId: falModelId,
      imageBytes: imageBytes,
      prompt: prompt,
      aspectRatio: aspectRatio,
      duration: duration,
      hd: hd,
    );

    onProgress?.call('processing', 0.1);
    final videoUrl = await pollVideoTask(
      falModelId: falModelId,
      requestId: requestId,
      onProgress: onProgress,
    );

    onProgress?.call('downloading', 0.9);
    final bytes = await downloadVideo(videoUrl);
    onProgress?.call('done', 1.0);
    return bytes;
  }
}

// ─────────────────────────────────────────────────────
// OpenAI Sora 영상 생성 서비스 (Image-to-Video)
// 지원 모델: sora-2, sora-2-pro
// ─────────────────────────────────────────────────────
class OpenAiVideoService {
  final String apiKey;
  static const String _baseUrl = 'https://api.openai.com/v1';

  OpenAiVideoService(this.apiKey);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  Future<Uint8List> generateVideo({
    required String modelId,      // 'sora-2' | 'sora-2-pro'
    required Uint8List imageBytes,
    required String prompt,
    required String aspectRatio,  // '16:9' | '9:16'
    required int duration,
    bool hd = false,
    void Function(String status, double progress)? onProgress,
  }) async {
    onProgress?.call('requesting', 0.0);

    // 이미지를 base64로 인코딩
    final b64 = base64Encode(imageBytes);
    final imageUri = 'data:image/jpeg;base64,$b64';

    // 해상도 설정
    String resolution;
    if (aspectRatio == '9:16') {
      resolution = hd ? '720x1280' : '480x854';
    } else {
      resolution = hd ? '1280x720' : '854x480';
    }

    final body = <String, dynamic>{
      'model': modelId,
      'prompt': prompt,
      'image': imageUri,
      'duration': duration,
      'resolution': resolution,
      'n': 1,
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/video/generations'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(const Duration(minutes: 3));

    if (response.statusCode == 200 || response.statusCode == 202) {
      final data = jsonDecode(response.body);
      final generationId = data['id'] as String?;
      if (generationId == null) {
        throw Exception('OpenAI Sora: generation id를 받지 못했습니다.');
      }

      onProgress?.call('processing', 0.1);
      return await _pollAndDownload(generationId, onProgress);
    } else {
      _throwOpenAiError(response);
    }
    throw Exception('OpenAI Sora 영상 생성 요청 실패');
  }

  Future<Uint8List> _pollAndDownload(
    String generationId,
    void Function(String status, double progress)? onProgress,
  ) async {
    final deadline = DateTime.now().add(const Duration(minutes: 10));
    int interval = 5;

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(Duration(seconds: interval));

      final response = await http.get(
        Uri.parse('$_baseUrl/video/generations/$generationId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) continue;

      final data = jsonDecode(response.body);
      final status = (data['status'] as String? ?? 'processing').toLowerCase();
      onProgress?.call(status, 0.5);

      if (status == 'completed' || status == 'succeeded') {
        final videoUrl = data['url'] as String?
            ?? data['data']?[0]?['url'] as String?;
        if (videoUrl == null) throw Exception('Sora: 영상 URL을 받지 못했습니다.');
        onProgress?.call('downloading', 0.9);
        final dlResp = await http.get(Uri.parse(videoUrl))
            .timeout(const Duration(minutes: 5));
        if (dlResp.statusCode == 200) {
          onProgress?.call('done', 1.0);
          return dlResp.bodyBytes;
        }
        throw Exception('Sora 영상 다운로드 실패 (${dlResp.statusCode})');
      } else if (status == 'failed') {
        final err = data['error']?['message'] as String? ?? '알 수 없는 오류';
        throw Exception('OpenAI Sora 영상 생성 실패: $err');
      }

      if (interval < 15) interval = (interval * 1.2).round().clamp(5, 15);
    }
    throw Exception('OpenAI Sora 영상 생성 시간 초과');
  }

  void _throwOpenAiError(http.Response response) {
    String errMsg = 'OpenAI API 오류 (${response.statusCode})';
    try {
      final d = jsonDecode(response.body);
      final msg = d['error']?['message'] as String? ?? '';
      if (response.statusCode == 401) {
        errMsg = '❌ OpenAI API 키가 올바르지 않습니다.\n설정에서 OpenAI API 키를 확인해주세요.';
      } else if (response.statusCode == 402 || response.statusCode == 429) {
        errMsg = '❌ OpenAI 크레딧 부족 또는 한도 초과입니다.';
      } else if (msg.isNotEmpty) {
        errMsg = '❌ OpenAI 오류: $msg';
      }
    } catch (_) {}
    throw Exception(errMsg);
  }
}

// ─────────────────────────────────────────────────────
// 로컬 영상 생성 서비스 (Automatic1111 / ComfyUI)
// AnimateDiff, SVD, SVD-XT → A1111
// Wan 2.1 / Wan 2.6 → ComfyUI
// ─────────────────────────────────────────────────────
class LocalVideoService {
  final String a1111Url;   // 기본 'http://127.0.0.1:7860'
  final String comfyUrl;   // 기본 'http://127.0.0.1:8188'

  LocalVideoService({
    this.a1111Url = 'http://127.0.0.1:7860',
    this.comfyUrl = 'http://127.0.0.1:8188',
  });

  // ── AnimateDiff (A1111) ──────────────────────
  Future<Uint8List> generateAnimateDiff({
    required Uint8List imageBytes,
    required String prompt,
    required String aspectRatio,
    required int frames,  // 16 or 32
    void Function(String status, double progress)? onProgress,
  }) async {
    onProgress?.call('requesting', 0.0);

    final width  = aspectRatio == '9:16' ? 512 : 768;
    final height = aspectRatio == '9:16' ? 768 : 512;
    final b64 = base64Encode(imageBytes);

    final body = {
      'init_images': [b64],
      'prompt': prompt,
      'negative_prompt': 'blurry, low quality, distorted',
      'steps': 20,
      'width': width,
      'height': height,
      'cfg_scale': 7,
      'sampler_name': 'DPM++ 2M Karras',
      'script_name': 'AnimateDiff',
      'script_args': [
        {
          'model': 'mm_sd_v15_v2.ckpt',
          'format': ['GIF', 'MP4'],
          'video_length': frames,
          'fps': 8,
          'loop_number': 0,
          'closed_loop': 'R-P',
          'batch_size': 1,
          'stride': 1,
          'overlap': -1,
          'interp': 'Off',
          'interp_x': 10,
          'video_source': null,
          'video_path': '',
          'latent_power': 1,
          'latent_scale': 32,
          'last_frame': null,
          'latent_power_last': 1,
          'latent_scale_last': 32,
        }
      ],
    };

    final response = await http.post(
      Uri.parse('$a1111Url/sdapi/v1/img2img'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(minutes: 10));

    onProgress?.call('processing', 0.8);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // AnimateDiff는 mp4를 별도 파일로 저장하거나 base64로 반환
      final videos = data['videos'] as List?;
      if (videos != null && videos.isNotEmpty) {
        onProgress?.call('done', 1.0);
        return base64Decode(videos[0] as String);
      }
      // mp4 저장 경로로 반환되는 경우
      final info = data['info'] as String? ?? '';
      if (info.contains('.mp4')) {
        throw Exception('AnimateDiff: 영상이 로컬에 저장되었습니다.\n경로: $info');
      }
      throw Exception('AnimateDiff: 영상 데이터를 받지 못했습니다.');
    }
    throw Exception('AnimateDiff 오류 (${response.statusCode}): ${response.body}');
  }

  // ── SVD / SVD-XT (A1111) ──────────────────────
  Future<Uint8List> generateSvd({
    required Uint8List imageBytes,
    required String aspectRatio,
    required bool useXt,  // true = SVD-XT (25프레임), false = SVD (14프레임)
    void Function(String status, double progress)? onProgress,
  }) async {
    onProgress?.call('requesting', 0.0);

    final width  = aspectRatio == '9:16' ? 576 : 1024;
    final height = aspectRatio == '9:16' ? 1024 : 576;
    final b64 = base64Encode(imageBytes);
    final frames = useXt ? 25 : 14;

    final body = {
      'image': b64,
      'width': width,
      'height': height,
      'frames': frames,
      'steps': 25,
      'min_cfg': 1.0,
      'video_cfg': 2.5,
      'motion_bucket_id': 127,
      'fps': 6,
      'decode_chunk_size': useXt ? 4 : 8,  // SVD-XT는 메모리 절약
      'fp16': true,  // 8GB VRAM 최적화
      'xformers': true,
    };

    final response = await http.post(
      Uri.parse('$a1111Url/svd/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(minutes: 15));

    onProgress?.call('processing', 0.8);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final videoB64 = data['video'] as String? ?? data['frames_b64'] as String?;
      if (videoB64 != null && videoB64.isNotEmpty) {
        onProgress?.call('done', 1.0);
        return base64Decode(videoB64);
      }
      throw Exception('SVD: 영상 데이터를 받지 못했습니다.');
    }
    throw Exception('SVD 오류 (${response.statusCode}): ${response.body}');
  }

  // ── Wan 2.1 / 2.6 (ComfyUI) ──────────────────────
  Future<Uint8List> generateWan({
    required Uint8List imageBytes,
    required String prompt,
    required String aspectRatio,
    required int duration,
    required bool isWan26,  // true = Wan 2.6, false = Wan 2.1
    void Function(String status, double progress)? onProgress,
    // 사용자 ComfyUI에 실제로 설치된 파일명 (기본값은 다운받은 실제 파일명)
    String unetName = 'Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors',
    String clipName = 'umt5_xxl_fp8_e4m3fn_scaled.safetensors',
    String vaeName = 'Wan2.1_VAE.pth',
    String clipVisionName = 'clip_vision_h.safetensors',
  }) async {
    onProgress?.call('이미지 업로드 중...', 0.02);

    final width  = aspectRatio == '9:16' ? 480 : 832;
    final height = aspectRatio == '9:16' ? 832 : 480;
    final frames = (duration * 16).clamp(16, 81); // 16fps 기준, 최소16 최대81

    // ── Step 1: 이미지를 ComfyUI에 업로드 ──
    String uploadedImageName;
    try {
      final uploadUri = Uri.parse('$comfyUrl/upload/image');
      final request = http.MultipartRequest('POST', uploadUri);
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'tube_input_${DateTime.now().millisecondsSinceEpoch}.png',
      ));
      request.fields['overwrite'] = 'true';
      request.fields['type'] = 'input';

      final streamResp = await request.send().timeout(const Duration(minutes: 2));
      final uploadBody = await streamResp.stream.bytesToString();

      if (streamResp.statusCode == 200) {
        final uploadData = jsonDecode(uploadBody);
        uploadedImageName = uploadData['name'] as String? ?? 'input.png';
        onProgress?.call('이미지 업로드 완료: $uploadedImageName', 0.04);
      } else {
        // 업로드 실패 시 오류 메시지 표시 후 fallback
        onProgress?.call('이미지 업로드 실패(${streamResp.statusCode}) - fallback 사용', 0.04);
        uploadedImageName = 'input.png';
      }
    } catch (e) {
      onProgress?.call('이미지 업로드 오류: $e', 0.04);
      uploadedImageName = 'input.png';
    }

    onProgress?.call('워크플로우 실행 요청 중...', 0.05);

    // ── Step 2: 워크플로우 JSON 전송
    // 공식 ComfyUI Wan 2.1 I2V 워크플로우 기반:
    // https://comfyanonymous.github.io/ComfyUI_examples/wan/
    // 노드 구조: UNETLoader → ModelSamplingSD3 → KSampler
    //            CLIPLoader → CLIPTextEncode(pos/neg) → WanImageToVideo → KSampler
    //            CLIPVisionLoader → CLIPVisionEncode → WanImageToVideo
    //            LoadImage → CLIPVisionEncode, WanImageToVideo
    //            VAELoader → WanImageToVideo, VAEDecode
    //            KSampler → VAEDecode → VHS_VideoCombine
    final workflow = {
      'prompt': {
        // 노드 1: 이미지 로드
        '1': {
          'class_type': 'LoadImage',
          'inputs': {'image': uploadedImageName, 'upload': 'image'},
        },
        // 노드 2: UNet 로드
        '2': {
          'class_type': 'UNETLoader',
          'inputs': {
            'unet_name': unetName,
            'weight_dtype': 'default',
          },
        },
        // 노드 3: ModelSamplingSD3 (공식 워크플로우 필수 노드, shift=8)
        '3': {
          'class_type': 'ModelSamplingSD3',
          'inputs': {
            'model': ['2', 0],
            'shift': 8.0,
          },
        },
        // 노드 4: CLIP 로드
        '4': {
          'class_type': 'CLIPLoader',
          'inputs': {
            'clip_name': clipName,
            'type': 'wan',
            'device': 'default',
          },
        },
        // 노드 5: VAE 로드
        '5': {
          'class_type': 'VAELoader',
          'inputs': {'vae_name': vaeName},
        },
        // 노드 6: CLIP Vision 로드
        '6': {
          'class_type': 'CLIPVisionLoader',
          'inputs': {'clip_name': clipVisionName},
        },
        // 노드 7: CLIP Vision 인코딩
        '7': {
          'class_type': 'CLIPVisionEncode',
          'inputs': {
            'clip_vision': ['6', 0],
            'image': ['1', 0],
            'crop': 'none',
          },
        },
        // 노드 8: Positive 텍스트 인코딩
        '8': {
          'class_type': 'CLIPTextEncode',
          'inputs': {
            'text': prompt,
            'clip': ['4', 0],
          },
        },
        // 노드 9: Negative 텍스트 인코딩 (공식 Wan 권장 네거티브)
        '9': {
          'class_type': 'CLIPTextEncode',
          'inputs': {
            'text': '色调艳丽，过曝，静态，细节模糊不清，字幕，风格，作品，画作，画面，静止，整体发灰，最差质量，低质量，JPEG压缩残留，丑陋的，残缺的，多余的手指，画得不好的手部，画得不好的脸部，畸形的，毁容的，形态畸形的肢体，手指融合，静止不动的画面，杂乱的背景，三条腿，背景人很多，倒着走',
            'clip': ['4', 0],
          },
        },
        // 노드 10: WanImageToVideo (공식 입력 구조 사용)
        '10': {
          'class_type': 'WanImageToVideo',
          'inputs': {
            'positive': ['8', 0],
            'negative': ['9', 0],
            'vae': ['5', 0],
            'clip_vision_output': ['7', 0],
            'start_image': ['1', 0],
            'width': width,
            'height': height,
            'length': frames,
            'batch_size': 1,
          },
        },
        // 노드 11: KSampler
        '11': {
          'class_type': 'KSampler',
          'inputs': {
            'model': ['3', 0],       // ModelSamplingSD3 출력
            'positive': ['10', 0],  // WanImageToVideo positive 출력
            'negative': ['10', 1],  // WanImageToVideo negative 출력
            'latent_image': ['10', 2], // WanImageToVideo latent 출력
            'seed': DateTime.now().millisecondsSinceEpoch % 1000000000,
            'steps': 20,
            'cfg': 6.0,
            'sampler_name': 'uni_pc',
            'scheduler': 'simple',
            'denoise': 1.0,
          },
        },
        // 노드 12: VAEDecode (공식 워크플로우는 VAEDecode 사용)
        '12': {
          'class_type': 'VAEDecode',
          'inputs': {
            'samples': ['11', 0],
            'vae': ['5', 0],
          },
        },
        // 노드 13: 프레임 저장 (ComfyUI 내장 노드 - 별도 설치 불필요)
        // SaveAnimatedWEBP: ComfyUI 기본 내장, WEBP 애니메이션으로 저장
        '13': {
          'class_type': 'SaveAnimatedWEBP',
          'inputs': {
            'images': ['12', 0],
            'filename_prefix': 'wan_output',
            'fps': 16.0,
            'lossless': false,
            'quality': 85,
            'method': 'default',
          },
        },
      }
    };

    final queueResp = await http.post(
      Uri.parse('$comfyUrl/prompt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(workflow),
    ).timeout(const Duration(minutes: 2));

    if (queueResp.statusCode != 200) {
      // ComfyUI 오류 메시지 파싱 시도
      String errorDetail = '';
      try {
        final errData = jsonDecode(queueResp.body);
        final errNode = errData['error'];
        if (errNode is Map) {
          errorDetail = '\n오류: ${errNode['message'] ?? errNode}';
        }
        // 노드별 오류 확인
        final nodeErrors = errData['node_errors'] as Map?;
        if (nodeErrors != null && nodeErrors.isNotEmpty) {
          final firstErr = nodeErrors.values.first;
          errorDetail += '\n노드 오류: ${firstErr['errors']?.first?['message'] ?? firstErr}';
        }
      } catch (_) {
        errorDetail = '\n응답: ${queueResp.body.substring(0, queueResp.body.length.clamp(0, 200))}';
      }
      throw Exception('ComfyUI 요청 실패 (${queueResp.statusCode})$errorDetail\n'
          'ComfyUI가 실행 중인지 확인해주세요: $comfyUrl');
    }

    final queueData = jsonDecode(queueResp.body);
    final promptId = queueData['prompt_id'] as String?;
    if (promptId == null) {
      // prompt_id 없는 경우 오류 내용 표시
      String errMsg = 'ComfyUI: prompt_id를 받지 못했습니다.';
      try {
        final errData = queueData;
        final nodeErrors = errData['node_errors'] as Map?;
        if (nodeErrors != null && nodeErrors.isNotEmpty) {
          final errList = <String>[];
          for (final entry in nodeErrors.entries) {
            final errs = (entry.value as Map)['errors'] as List?;
            for (final e in errs ?? []) {
              errList.add('노드${entry.key}: ${(e as Map)['message'] ?? e}');
            }
          }
          errMsg = '모델 파일을 찾을 수 없습니다:\n${errList.join('\n')}\n\n'
              '앱 설정 → 채널 설정 → 로컬 모델 파일명을 ComfyUI에 실제 있는 파일명으로 수정해주세요.';
        }
      } catch (_) {}
      throw Exception(errMsg);
    }

    onProgress?.call('ComfyUI 큐 접수 완료, 생성 시작...', 0.1);

    // 폴링 - ComfyUI /queue 엔드포인트도 함께 체크하여 진행 상태 표시
    final deadline = DateTime.now().add(const Duration(minutes: 30));
    int interval = 3;
    final startTime = DateTime.now();

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(Duration(seconds: interval));
      // 경과 시간 계산
      final elapsed = DateTime.now().difference(startTime);
      final elapsedMin = elapsed.inMinutes;
      final elapsedSec = elapsed.inSeconds % 60;
      final elapsedStr = elapsedMin > 0 ? '${elapsedMin}분 ${elapsedSec}초' : '${elapsedSec}초';

      // /queue 체크 - 큐 내 위치 확인
      try {
        final queueCheckResp = await http.get(
          Uri.parse('$comfyUrl/queue'),
        ).timeout(const Duration(seconds: 10));
        if (queueCheckResp.statusCode == 200) {
          final queueData2 = jsonDecode(queueCheckResp.body);
          final running = (queueData2['queue_running'] as List?) ?? [];
          final pending = (queueData2['queue_pending'] as List?) ?? [];
          if (running.isNotEmpty) {
            onProgress?.call('생성 중... (경과: $elapsedStr)', 0.15 + (elapsed.inSeconds / 1800).clamp(0.0, 0.72));
          } else if (pending.isNotEmpty) {
            onProgress?.call('큐 대기 중 (${pending.length}개 앞에 있음, 경과: $elapsedStr)', 0.12);
          }
        }
      } catch (_) {}

      final histResp = await http.get(
        Uri.parse('$comfyUrl/history/$promptId'),
      ).timeout(const Duration(seconds: 30));

      if (histResp.statusCode != 200) continue;

      final hist = jsonDecode(histResp.body) as Map<String, dynamic>;
      if (!hist.containsKey(promptId)) {
        // 아직 history에 없으면 실행 중
        onProgress?.call('생성 중... (경과: $elapsedStr)', 0.15 + (elapsed.inSeconds / 1800).clamp(0.0, 0.72));
        continue;
      }

      final promptResult = hist[promptId] as Map<String, dynamic>;

      // ── 실행 오류 확인 ──
      final status = promptResult['status'] as Map<String, dynamic>?;
      if (status != null) {
        final statusStr = status['status_str'] as String? ?? '';
        if (statusStr == 'error') {
          // 오류 메시지 추출
          final messages = status['messages'] as List?;
          String errorMsg = 'ComfyUI 실행 오류';
          for (final msg in messages ?? []) {
            if (msg is List && msg.length > 1 && msg[0] == 'execution_error') {
              final errData = msg[1] as Map?;
              errorMsg = '노드 오류: ${errData?['exception_message'] ?? errData?['exception_type'] ?? errorMsg}\n'
                  '파일명을 확인해주세요 (설정 → 채널 설정 → Wan 모델 파일명)';
              break;
            }
          }
          throw Exception(errorMsg);
        }
      }

      final outputs = promptResult['outputs'] as Map<String, dynamic>?;

      // status_str 확인 - success면 완료된 것
      final statusStr2 = (promptResult['status'] as Map<String, dynamic>?)?['status_str'] as String? ?? '';

      if (outputs == null || outputs.isEmpty) {
        if (statusStr2 == 'success') {
          // 성공으로 표시되었지만 outputs가 비어있음 - 예외 처리
          throw Exception('ComfyUI 생성 완료되었으나 출력 파일이 없습니다.\nComfyUI에서 직접 결과를 확인해주세요.');
        }
        // 아직 실행 중
        onProgress?.call('생성 중... (경과: $elapsedStr)', 0.15 + (elapsed.inSeconds / 1800).clamp(0.0, 0.72));
        continue;
      }

      // 출력에서 webp/mp4/gif 파일 찾기
      // SaveAnimatedWEBP → 'images' 키, VHS_VideoCombine → 'gifs'/'videos' 키
      Map<String, dynamic>? foundFile;
      String? foundSubfolder;

      for (final nodeOut in outputs.values) {
        if (foundFile != null) break;
        final node = nodeOut as Map<String, dynamic>;
        // 모든 가능한 키 순서대로 확인
        final fileList = node['images'] as List?
            ?? node['gifs'] as List?
            ?? node['videos'] as List?;
        if (fileList != null && fileList.isNotEmpty) {
          // webp/mp4/gif 우선순위로 찾기
          Map<String, dynamic>? bestFile;
          for (final f in fileList) {
            final fn = (f as Map<String, dynamic>)['filename'] as String? ?? '';
            if (fn.endsWith('.webp') || fn.endsWith('.mp4') || fn.endsWith('.gif')) {
              bestFile = f;
              break;
            }
          }
          bestFile ??= fileList[0] as Map<String, dynamic>;
          final fn = bestFile['filename'] as String?;
          if (fn != null && fn.isNotEmpty) {
            foundFile = bestFile;
            foundSubfolder = bestFile['subfolder'] as String? ?? '';
          }
        }
      }

      if (foundFile != null) {
          final filename = foundFile['filename'] as String?;
          final subfolder = foundSubfolder ?? '';
          if (filename != null && filename.isNotEmpty) {
            final dlUrl = '$comfyUrl/view?filename=$filename&subfolder=$subfolder&type=output';
            onProgress?.call('영상 다운로드 중... (파일: $filename)', 0.88);

            // 스트리밍 다운로드 - 파일 크기를 모를 때도 진행 표시
            final request = http.Request('GET', Uri.parse(dlUrl));
            final streamedResp = await request.send()
                .timeout(const Duration(minutes: 15));

            if (streamedResp.statusCode == 200) {
              final totalBytes = streamedResp.contentLength ?? 0;
              final chunks = <int>[];
              int received = 0;

              await for (final chunk in streamedResp.stream) {
                chunks.addAll(chunk);
                received += chunk.length;
                if (totalBytes > 0) {
                  final dlPct = received / totalBytes;
                  final dlMb = (received / 1024 / 1024).toStringAsFixed(1);
                  final totalMb = (totalBytes / 1024 / 1024).toStringAsFixed(1);
                  onProgress?.call(
                    '영상 다운로드 중... $dlMb/$totalMb MB',
                    0.88 + dlPct * 0.11,
                  );
                } else {
                  // 파일 크기 모를 때: 받은 크기만 표시
                  final dlMb = (received / 1024 / 1024).toStringAsFixed(1);
                  onProgress?.call('영상 다운로드 중... $dlMb MB 수신', 0.92);
                }
              }

              onProgress?.call('완료!', 1.0);
              return Uint8List.fromList(chunks);
            } else {
              throw Exception('영상 다운로드 실패 (${streamedResp.statusCode}): $filename');
            }
          }
      } else if (statusStr2 == 'success') {
        // 성공으로 마킹됐지만 파일 형식을 찾지 못한 경우
        // outputs 키 목록 기반 오류 메시지
        final keyList = outputs.values
            .map((n) => (n as Map).keys.toList().toString())
            .join(', ');
        throw Exception('ComfyUI 생성 완료 - 파일을 찾을 수 없음\n'
            '출력 키: $keyList\n'
            'SaveAnimatedWEBP 노드가 정상 설치되었는지 확인해주세요.');
      }

      if (interval < 10) interval = (interval * 1.2).round().clamp(3, 10);
    }
    throw Exception('ComfyUI Wan 영상 생성 시간 초과 (30분)\nComfyUI가 여전히 실행 중이라면 직접 결과를 확인해주세요.');
  }
}

// ─────────────────────────────────────────────────────
// 통합 VideoGenerationService
// 모델 종류에 따라 FalVideoService / OpenAiVideoService / LocalVideoService 자동 선택
// ─────────────────────────────────────────────────────
class VideoGenerationService {
  final String falApiKey;
  final String openAiApiKey;
  final String a1111Url;
  final String comfyUrl;
  // Wan 모델 파일명 (채널 설정에서 전달)
  final String wanUnetName;
  final String wanClipName;
  final String wanVaeName;
  final String wanClipVisionName;

  VideoGenerationService({
    required this.falApiKey,
    required this.openAiApiKey,
    this.a1111Url = 'http://127.0.0.1:7860',
    this.comfyUrl = 'http://127.0.0.1:8188',
    this.wanUnetName = 'Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors',
    this.wanClipName = 'umt5_xxl_fp8_e4m3fn_scaled.safetensors',
    this.wanVaeName = 'Wan2.1_VAE.pth',
    this.wanClipVisionName = 'clip_vision_h.safetensors',
  });

  Future<Uint8List> generateVideo({
    required VideoModel model,
    required Uint8List imageBytes,
    required String prompt,
    required String aspectRatio,
    required int duration,
    bool hd = false,
    void Function(String status, double progress)? onProgress,
  }) async {
    switch (model.backend) {
      case VideoBackend.fal:
        if (falApiKey.isEmpty) {
          throw Exception('fal.ai API 키가 없습니다.\n설정 → API 키 → fal.ai API Key를 입력해주세요.');
        }
        return await FalVideoService(falApiKey).generateVideo(
          falModelId: model.falModelId,
          imageBytes: imageBytes,
          prompt: prompt,
          aspectRatio: aspectRatio,
          duration: duration,
          hd: hd,
          onProgress: onProgress,
        );

      case VideoBackend.openai:
        if (openAiApiKey.isEmpty) {
          throw Exception('OpenAI API 키가 없습니다.\n설정 → API 키 → OpenAI API Key를 입력해주세요.');
        }
        return await OpenAiVideoService(openAiApiKey).generateVideo(
          modelId: model.openAiModelId,
          imageBytes: imageBytes,
          prompt: prompt,
          aspectRatio: aspectRatio,
          duration: duration,
          hd: hd,
          onProgress: onProgress,
        );

      case VideoBackend.a1111:
        final localSvc = LocalVideoService(a1111Url: a1111Url, comfyUrl: comfyUrl);
        if (model == VideoModel.animateDiff) {
          return await localSvc.generateAnimateDiff(
            imageBytes: imageBytes,
            prompt: prompt,
            aspectRatio: aspectRatio,
            frames: duration <= 2 ? 16 : 32,
            onProgress: onProgress,
          );
        } else {
          return await localSvc.generateSvd(
            imageBytes: imageBytes,
            aspectRatio: aspectRatio,
            useXt: model == VideoModel.svdXt,
            onProgress: onProgress,
          );
        }

      case VideoBackend.comfyui:
        return await LocalVideoService(a1111Url: a1111Url, comfyUrl: comfyUrl).generateWan(
          imageBytes: imageBytes,
          prompt: prompt,
          aspectRatio: aspectRatio,
          duration: duration,
          isWan26: model == VideoModel.wan26Local,
          onProgress: onProgress,
          unetName: wanUnetName,
          clipName: wanClipName,
          vaeName: wanVaeName,
          clipVisionName: wanClipVisionName,
        );
    }
  }
}

