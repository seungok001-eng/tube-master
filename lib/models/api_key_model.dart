class ApiKeyModel {
  String geminiApiKey;
  String claudeApiKey;
  String elevenLabsApiKey;
  String clovaApiKey;
  String clovaApiSecret;
  String youtubeClientId;
  String youtubeClientSecret;
  String stabilityApiKey;
  String replicateApiKey;
  String falApiKey;      // fal.ai - Kling/Wan/MiniMax/Vidu/Runway/Pixverse/Seedance
  String openAiApiKey;   // OpenAI - Sora 2 / Sora 2 Pro

  ApiKeyModel({
    this.geminiApiKey = '',
    this.claudeApiKey = '',
    this.elevenLabsApiKey = '',
    this.clovaApiKey = '',
    this.clovaApiSecret = '',
    this.youtubeClientId = '',
    this.youtubeClientSecret = '',
    this.stabilityApiKey = '',
    this.replicateApiKey = '',
    this.falApiKey = '',
    this.openAiApiKey = '',
  });

  bool get hasGemini => geminiApiKey.isNotEmpty;
  bool get hasClaude => claudeApiKey.isNotEmpty;
  bool get hasElevenLabs => elevenLabsApiKey.isNotEmpty;
  bool get hasClova => clovaApiKey.isNotEmpty && clovaApiSecret.isNotEmpty;
  bool get hasYoutube => youtubeClientId.isNotEmpty && youtubeClientSecret.isNotEmpty;
  bool get hasStability => stabilityApiKey.isNotEmpty;
  bool get hasFal => falApiKey.isNotEmpty;
  bool get hasOpenAi => openAiApiKey.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'geminiApiKey': geminiApiKey,
        'claudeApiKey': claudeApiKey,
        'elevenLabsApiKey': elevenLabsApiKey,
        'clovaApiKey': clovaApiKey,
        'clovaApiSecret': clovaApiSecret,
        'youtubeClientId': youtubeClientId,
        'youtubeClientSecret': youtubeClientSecret,
        'stabilityApiKey': stabilityApiKey,
        'replicateApiKey': replicateApiKey,
        'falApiKey': falApiKey,
        'openAiApiKey': openAiApiKey,
      };

  factory ApiKeyModel.fromJson(Map<String, dynamic> json) => ApiKeyModel(
        geminiApiKey: json['geminiApiKey'] ?? '',
        claudeApiKey: json['claudeApiKey'] ?? '',
        elevenLabsApiKey: json['elevenLabsApiKey'] ?? '',
        clovaApiKey: json['clovaApiKey'] ?? '',
        clovaApiSecret: json['clovaApiSecret'] ?? '',
        youtubeClientId: json['youtubeClientId'] ?? '',
        youtubeClientSecret: json['youtubeClientSecret'] ?? '',
        stabilityApiKey: json['stabilityApiKey'] ?? '',
        replicateApiKey: json['replicateApiKey'] ?? '',
        // 이전 gensparkApiKey 마이그레이션
        falApiKey: json['falApiKey'] ?? json['gensparkApiKey'] ?? '',
        openAiApiKey: json['openAiApiKey'] ?? '',
      );
}
