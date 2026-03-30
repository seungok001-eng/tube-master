import 'dart:convert';

enum ChannelType {
  economy,
  patriot,
  folklore,
  story,
  bible,
  buddhism,
  psychology,
  history,
  asmr,
  playlist,
}

extension ChannelTypeExtension on ChannelType {
  String get displayName {
    switch (this) {
      case ChannelType.economy: return '경제';
      case ChannelType.patriot: return '국뽕';
      case ChannelType.folklore: return '야담';
      case ChannelType.story: return '사연';
      case ChannelType.bible: return '성경';
      case ChannelType.buddhism: return '불교';
      case ChannelType.psychology: return '심리학';
      case ChannelType.history: return '역사';
      case ChannelType.asmr: return 'ASMR';
      case ChannelType.playlist: return '플레이리스트';
    }
  }

  String get emoji {
    switch (this) {
      case ChannelType.economy: return '📊';
      case ChannelType.patriot: return '🇰🇷';
      case ChannelType.folklore: return '📖';
      case ChannelType.story: return '💌';
      case ChannelType.bible: return '✝️';
      case ChannelType.buddhism: return '☸️';
      case ChannelType.psychology: return '🧠';
      case ChannelType.history: return '🏛️';
      case ChannelType.asmr: return '🎧';
      case ChannelType.playlist: return '🎵';
    }
  }

  String get defaultScriptPrompt {
    switch (this) {
      case ChannelType.economy:
        return '당신은 경제 전문 유튜브 대본 작가입니다. 한국, 일본, 미국 경제 이슈를 쉽고 재미있게 설명하는 대본을 작성해주세요. 전문 용어는 쉽게 풀어서 설명하고, 시청자가 끝까지 시청하고 싶도록 흥미롭게 작성해주세요.';
      case ChannelType.patriot:
        return '당신은 국뽕 유튜브 채널 대본 작가입니다. 대한민국의 자랑스러운 역사, 문화, 기술, 인물 등을 소개하는 웅장하고 감동적인 대본을 작성해주세요. 애국심을 자극하면서도 사실에 기반한 내용으로 작성해주세요.';
      case ChannelType.folklore:
        return '당신은 야담 유튜브 채널 대본 작가입니다. 조선시대와 한국 전통 야담, 기이한 이야기, 전설 등을 흥미롭게 각색하여 대본을 작성해주세요. 옛날 분위기를 살리면서도 현대 시청자가 이해하기 쉽게 작성해주세요.';
      case ChannelType.story:
        return '당신은 사연 유튜브 채널 대본 작가입니다. 시청자의 감동적이고 공감가는 사연을 바탕으로 대본을 작성해주세요. 감정이입이 되도록 섬세하게 묘사하고, 시청자가 눈물을 흘릴 수 있을 만큼 감동적으로 작성해주세요.';
      case ChannelType.bible:
        return '당신은 성경 유튜브 채널 대본 작가입니다. 성경 말씀과 이야기를 현대인들이 이해하기 쉽고 삶에 적용할 수 있도록 대본을 작성해주세요. 경건하고 따뜻한 톤으로 신앙인들에게 위로와 용기를 주는 내용으로 작성해주세요.';
      case ChannelType.buddhism:
        return '당신은 불교 유튜브 채널 대본 작가입니다. 불교의 가르침, 선사들의 이야기, 명상법 등을 현대인의 삶에 맞게 쉽게 풀어쓴 대본을 작성해주세요. 차분하고 지혜로운 톤으로 마음의 평화를 전하는 내용으로 작성해주세요.';
      case ChannelType.psychology:
        return '당신은 심리학 유튜브 채널 대본 작가입니다. 심리학 이론과 연구를 일반인도 이해할 수 있게 쉽게 설명하는 대본을 작성해주세요. 실생활에서 바로 적용할 수 있는 심리 팁과 자기계발 내용을 포함하여 작성해주세요.';
      case ChannelType.history:
        return '당신은 역사 유튜브 채널 대본 작가입니다. 한국사와 세계사의 흥미로운 사건, 인물, 비화 등을 다큐멘터리 스타일로 대본을 작성해주세요. 역사적 사실에 기반하면서도 드라마틱하게 스토리텔링하여 작성해주세요.';
      case ChannelType.asmr:
        return '당신은 ASMR 유튜브 채널 기획자입니다. ASMR 영상의 컨셉, 사용할 소리, 분위기 등을 기획하는 내용을 작성해주세요. 시청자가 편안함과 수면을 취할 수 있도록 차분하고 감각적인 내용으로 작성해주세요.';
      case ChannelType.playlist:
        return '당신은 플레이리스트 유튜브 채널 기획자입니다. 특정 감성이나 상황에 맞는 음악 플레이리스트 영상 컨셉을 작성해주세요. 어떤 분위기의 음악을 담을지, 배경 영상은 어떻게 할지 등을 기획해주세요.';
    }
  }

  bool get isScriptBased {
    switch (this) {
      case ChannelType.folklore:
      case ChannelType.story:
      case ChannelType.patriot:
      case ChannelType.history:
        return true;
      default:
        return false;
    }
  }
}

class ChannelModel {
  final String id;
  String name;
  ChannelType type;
  String youtubeChannelId;
  String youtubeChannelName;
  String scriptPrompt;
  String imagePrompt;
  String musicPrompt;
  String lyricsPrompt;
  String introPrompt;    // 인트로 생성 프롬프트 (비워두면 AI 자동 생성)
  TtsSettings ttsSettings;
  VideoSettings videoSettings;
  ThumbnailSettings thumbnailSettings;
  bool isActive;
  DateTime createdAt;

  ChannelModel({
    required this.id,
    required this.name,
    required this.type,
    this.youtubeChannelId = '',
    this.youtubeChannelName = '',
    String? scriptPrompt,
    this.imagePrompt = '',
    this.musicPrompt = '',
    this.lyricsPrompt = '',
    this.introPrompt = '',
    TtsSettings? ttsSettings,
    VideoSettings? videoSettings,
    ThumbnailSettings? thumbnailSettings,
    this.isActive = true,
    DateTime? createdAt,
  })  : scriptPrompt = scriptPrompt ?? type.defaultScriptPrompt,
        ttsSettings = ttsSettings ?? TtsSettings(),
        videoSettings = videoSettings ?? VideoSettings(),
        thumbnailSettings = thumbnailSettings ?? ThumbnailSettings(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'youtubeChannelId': youtubeChannelId,
        'youtubeChannelName': youtubeChannelName,
        'scriptPrompt': scriptPrompt,
        'imagePrompt': imagePrompt,
        'musicPrompt': musicPrompt,
        'introPrompt': introPrompt,
        'lyricsPrompt': lyricsPrompt,
        'ttsSettings': ttsSettings.toJson(),
        'videoSettings': videoSettings.toJson(),
        'thumbnailSettings': thumbnailSettings.toJson(),
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChannelModel.fromJson(Map<String, dynamic> json) => ChannelModel(
        id: json['id'],
        name: json['name'],
        type: ChannelType.values[json['type']],
        youtubeChannelId: json['youtubeChannelId'] ?? '',
        youtubeChannelName: json['youtubeChannelName'] ?? '',
        scriptPrompt: json['scriptPrompt'],
        imagePrompt: json['imagePrompt'] ?? '',
        musicPrompt: json['musicPrompt'] ?? '',
        introPrompt: json['introPrompt'] ?? '',
        lyricsPrompt: json['lyricsPrompt'] ?? '',
        ttsSettings: TtsSettings.fromJson(json['ttsSettings'] ?? {}),
        videoSettings: VideoSettings.fromJson(json['videoSettings'] ?? {}),
        thumbnailSettings: ThumbnailSettings.fromJson(json['thumbnailSettings'] ?? {}),
        isActive: json['isActive'] ?? true,
        createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      );

  ChannelModel copyWith({
    String? name,
    ChannelType? type,
    String? youtubeChannelId,
    String? youtubeChannelName,
    String? scriptPrompt,
    String? imagePrompt,
    String? musicPrompt,
    String? introPrompt,
    String? lyricsPrompt,
    TtsSettings? ttsSettings,
    VideoSettings? videoSettings,
    ThumbnailSettings? thumbnailSettings,
    bool? isActive,
  }) => ChannelModel(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    youtubeChannelId: youtubeChannelId ?? this.youtubeChannelId,
    youtubeChannelName: youtubeChannelName ?? this.youtubeChannelName,
    scriptPrompt: scriptPrompt ?? this.scriptPrompt,
    imagePrompt: imagePrompt ?? this.imagePrompt,
    musicPrompt: musicPrompt ?? this.musicPrompt,
    introPrompt: introPrompt ?? this.introPrompt,
    lyricsPrompt: lyricsPrompt ?? this.lyricsPrompt,
    ttsSettings: ttsSettings ?? this.ttsSettings,
    videoSettings: videoSettings ?? this.videoSettings,
    thumbnailSettings: thumbnailSettings ?? this.thumbnailSettings,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
  );
}

// TTS 설정
enum TtsEngine { gemini, elevenlabs, clova, local }

extension TtsEngineExt on TtsEngine {
  String get displayName {
    switch (this) {
      case TtsEngine.gemini: return 'Gemini TTS';
      case TtsEngine.elevenlabs: return 'ElevenLabs';
      case TtsEngine.clova: return '네이버 CLOVA';
      case TtsEngine.local: return '직접 녹음';
    }
  }
}

class TtsSettings {
  TtsEngine engine;
  String voiceId;
  double speed;
  double pitch;
  double volume;

  TtsSettings({
    this.engine = TtsEngine.gemini,
    this.voiceId = '',
    this.speed = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'engine': engine.index,
        'voiceId': voiceId,
        'speed': speed,
        'pitch': pitch,
        'volume': volume,
      };

  factory TtsSettings.fromJson(Map<String, dynamic> json) => TtsSettings(
        engine: TtsEngine.values[json['engine'] ?? 0],
        voiceId: json['voiceId'] ?? '',
        speed: (json['speed'] ?? 1.0).toDouble(),
        pitch: (json['pitch'] ?? 1.0).toDouble(),
        volume: (json['volume'] ?? 1.0).toDouble(),
      );
}

// 영상 설정
enum VideoStyle { slideshow, aiVideo, mixed }
enum ImageRatio { ratio9x16, ratio16x9, ratio1x1, ratio4x3, ratio3x4 }

// ─────────────────────────────────────────────────────
// 이미지 스타일 (30개)
// ─────────────────────────────────────────────────────
enum ImageStyle {
  none,           // 스타일 없음 (기본)
  // ── 한국/동양 특화 ──
  koreanFolktale, // 한국 야담·설화풍
  minhwa,         // 한국 민화
  joseon,         // 조선시대 목판화
  dongHwa,        // 한국 동화 일러스트
  // ── 애니메이션 계열 ──
  anime2d,        // 일본 애니메이션 2D
  animeStudio,    // 지브리·스튜디오 애니 풍
  chibi,          // 치비·SD 캐릭터
  webtoon,        // 한국 웹툰 스타일
  cartoon2d,      // 서양 카툰 2D
  cartoon3d,      // 3D 애니메이션 (픽사·드림웍스)
  // ── 삽화·디자인 ──
  stickFigure,    // 졸라맨·스틱 피규어
  flatDesign,     // 플랫 디자인 (모션그래픽)
  infographic,    // 인포그래픽
  paperCraft,     // 페이퍼 컷 아트
  watercolor,     // 수채화
  oilPainting,    // 유화
  sketchPencil,   // 연필 스케치
  comicBook,      // 코믹북·만화
  // ── 실사·영상 계열 ──
  realistic,      // 사진 실사
  cinematic,      // 영화적 시네마틱
  documentary,    // 다큐멘터리 스타일
  noir,           // 느와르 (흑백·고대비)
  vintage,        // 빈티지·레트로 필름
  dramatic,       // 드라마틱·연극 조명
  // ── 특수 분위기 ──
  scienceFiction, // SF·사이버펑크
  fantasy,        // 판타지·마법
  horror,         // 공포·다크 판타지
  miniature,      // 미니어처·틸트시프트
  pixelArt,       // 픽셀 아트·레트로 게임
}

extension ImageStyleExt on ImageStyle {
  String get displayName {
    switch (this) {
      case ImageStyle.none:           return '없음 (기본)';
      case ImageStyle.koreanFolktale: return '한국 야담·설화';
      case ImageStyle.minhwa:         return '한국 민화';
      case ImageStyle.joseon:         return '조선 목판화';
      case ImageStyle.dongHwa:        return '한국 동화 일러스트';
      case ImageStyle.anime2d:        return '일본 애니메이션 2D';
      case ImageStyle.animeStudio:    return '지브리·스튜디오 애니';
      case ImageStyle.chibi:          return '치비·SD 캐릭터';
      case ImageStyle.webtoon:        return '한국 웹툰';
      case ImageStyle.cartoon2d:      return '서양 카툰 2D';
      case ImageStyle.cartoon3d:      return '3D 애니메이션 (픽사풍)';
      case ImageStyle.stickFigure:    return '졸라맨·스틱 피규어';
      case ImageStyle.flatDesign:     return '플랫 디자인';
      case ImageStyle.infographic:    return '인포그래픽';
      case ImageStyle.paperCraft:     return '페이퍼 컷 아트';
      case ImageStyle.watercolor:     return '수채화';
      case ImageStyle.oilPainting:    return '유화';
      case ImageStyle.sketchPencil:   return '연필 스케치';
      case ImageStyle.comicBook:      return '코믹북·만화';
      case ImageStyle.realistic:      return '사진 실사';
      case ImageStyle.cinematic:      return '영화 시네마틱';
      case ImageStyle.documentary:    return '다큐멘터리';
      case ImageStyle.noir:           return '느와르 (흑백)';
      case ImageStyle.vintage:        return '빈티지·레트로';
      case ImageStyle.dramatic:       return '드라마틱·연극';
      case ImageStyle.scienceFiction: return 'SF·사이버펑크';
      case ImageStyle.fantasy:        return '판타지·마법';
      case ImageStyle.horror:         return '공포·다크 판타지';
      case ImageStyle.miniature:      return '미니어처·틸트시프트';
      case ImageStyle.pixelArt:       return '픽셀 아트';
    }
  }

  String get emoji {
    switch (this) {
      case ImageStyle.none:           return '🔲';
      case ImageStyle.koreanFolktale: return '📜';
      case ImageStyle.minhwa:         return '🎨';
      case ImageStyle.joseon:         return '🏺';
      case ImageStyle.dongHwa:        return '📚';
      case ImageStyle.anime2d:        return '⛩️';
      case ImageStyle.animeStudio:    return '🌿';
      case ImageStyle.chibi:          return '🐥';
      case ImageStyle.webtoon:        return '💬';
      case ImageStyle.cartoon2d:      return '🎠';
      case ImageStyle.cartoon3d:      return '🎬';
      case ImageStyle.stickFigure:    return '🕴️';
      case ImageStyle.flatDesign:     return '🔷';
      case ImageStyle.infographic:    return '📊';
      case ImageStyle.paperCraft:     return '✂️';
      case ImageStyle.watercolor:     return '💧';
      case ImageStyle.oilPainting:    return '🖼️';
      case ImageStyle.sketchPencil:   return '✏️';
      case ImageStyle.comicBook:      return '💥';
      case ImageStyle.realistic:      return '📷';
      case ImageStyle.cinematic:      return '🎥';
      case ImageStyle.documentary:    return '🎞️';
      case ImageStyle.noir:           return '🌑';
      case ImageStyle.vintage:        return '📽️';
      case ImageStyle.dramatic:       return '🎭';
      case ImageStyle.scienceFiction: return '🚀';
      case ImageStyle.fantasy:        return '🧙';
      case ImageStyle.horror:         return '💀';
      case ImageStyle.miniature:      return '🔬';
      case ImageStyle.pixelArt:       return '👾';
    }
  }

  /// 카테고리 그룹
  String get category {
    switch (this) {
      case ImageStyle.none:
        return '기본';
      case ImageStyle.koreanFolktale:
      case ImageStyle.minhwa:
      case ImageStyle.joseon:
      case ImageStyle.dongHwa:
        return '한국·동양';
      case ImageStyle.anime2d:
      case ImageStyle.animeStudio:
      case ImageStyle.chibi:
      case ImageStyle.webtoon:
      case ImageStyle.cartoon2d:
      case ImageStyle.cartoon3d:
        return '애니·카툰';
      case ImageStyle.stickFigure:
      case ImageStyle.flatDesign:
      case ImageStyle.infographic:
      case ImageStyle.paperCraft:
      case ImageStyle.watercolor:
      case ImageStyle.oilPainting:
      case ImageStyle.sketchPencil:
      case ImageStyle.comicBook:
        return '삽화·그림';
      case ImageStyle.realistic:
      case ImageStyle.cinematic:
      case ImageStyle.documentary:
      case ImageStyle.noir:
      case ImageStyle.vintage:
      case ImageStyle.dramatic:
        return '실사·영상';
      case ImageStyle.scienceFiction:
      case ImageStyle.fantasy:
      case ImageStyle.horror:
      case ImageStyle.miniature:
      case ImageStyle.pixelArt:
        return '특수·장르';
    }
  }

  /// Gemini 이미지 생성 프롬프트에 삽입될 스타일 지시문
  String get promptSuffix {
    switch (this) {
      case ImageStyle.none:           return '';
      case ImageStyle.koreanFolktale: return 'Korean folk tale illustration style, traditional ink brush painting, muted earthy tones, storytelling art';
      case ImageStyle.minhwa:         return 'Korean Minhwa folk painting style, vibrant primary colors, folk art, traditional Korean painting with tigers, flowers, birds';
      case ImageStyle.joseon:         return 'Joseon dynasty woodblock print style, monochrome ink illustration, traditional Korean historical artwork';
      case ImageStyle.dongHwa:        return 'Korean children\'s storybook illustration, soft warm colors, gentle friendly characters, whimsical fairy tale art';
      case ImageStyle.anime2d:        return 'Japanese anime style, 2D animation, clean line art, vibrant colors, expressive eyes, manga-inspired';
      case ImageStyle.animeStudio:    return 'Studio Ghibli inspired animation style, soft watercolor backgrounds, detailed nature, whimsical characters, Miyazaki aesthetic';
      case ImageStyle.chibi:          return 'Chibi SD character style, super-deformed cute characters, big eyes, tiny body, kawaii illustration';
      case ImageStyle.webtoon:        return 'Korean webtoon style, clean digital illustration, expressive characters, modern manhwa art style';
      case ImageStyle.cartoon2d:      return 'Western cartoon 2D animation style, bold outlines, flat colors, exaggerated expressions, Saturday morning cartoon';
      case ImageStyle.cartoon3d:      return 'Pixar/DreamWorks 3D animated movie style, high quality CGI, expressive 3D characters, warm cinematic lighting';
      case ImageStyle.stickFigure:    return 'stick figure illustration, simple stick man characters, minimalist black and white drawing, comic strip style';
      case ImageStyle.flatDesign:     return 'flat design illustration, modern vector art, clean geometric shapes, minimal style, motion graphics aesthetic';
      case ImageStyle.infographic:    return 'infographic illustration style, data visualization, clean icons, modern flat design, educational visual';
      case ImageStyle.paperCraft:     return 'paper cut art style, layered paper craft, shadow depth, colorful paper illustration, handmade look';
      case ImageStyle.watercolor:     return 'watercolor painting style, soft flowing colors, wet-on-wet technique, delicate washes, artistic illustration';
      case ImageStyle.oilPainting:    return 'oil painting style, thick brushstrokes, rich textures, classic fine art, dramatic lighting, museum quality';
      case ImageStyle.sketchPencil:   return 'pencil sketch illustration, hand-drawn look, graphite texture, detailed line work, artistic drawing';
      case ImageStyle.comicBook:      return 'comic book style, bold ink outlines, halftone dots, dynamic action poses, superhero comic art';
      case ImageStyle.realistic:      return 'photorealistic, ultra high detail, 8K resolution, professional photography quality, sharp focus';
      case ImageStyle.cinematic:      return 'cinematic movie still, anamorphic lens, dramatic lighting, film grain, Hollywood blockbuster quality, wide angle';
      case ImageStyle.documentary:    return 'documentary photography style, candid realistic, natural lighting, journalistic, authentic and raw';
      case ImageStyle.noir:           return 'film noir style, high contrast black and white, dramatic shadows, chiaroscuro lighting, 1940s detective atmosphere';
      case ImageStyle.vintage:        return 'vintage retro film style, faded colors, light leaks, grain texture, old photograph aesthetic, nostalgic';
      case ImageStyle.dramatic:       return 'dramatic theatrical lighting, stage production style, intense shadows, spotlight effect, theatrical atmosphere';
      case ImageStyle.scienceFiction: return 'cyberpunk sci-fi style, neon lights, futuristic technology, dark dystopian atmosphere, blade runner aesthetic';
      case ImageStyle.fantasy:        return 'epic fantasy illustration, magical atmosphere, mystical lighting, detailed world-building, high fantasy art';
      case ImageStyle.horror:         return 'dark horror illustration, unsettling atmosphere, deep shadows, gothic horror style, eerie and chilling';
      case ImageStyle.miniature:      return 'tilt-shift miniature effect, tiny scale look, shallow depth of field, model-like appearance, toy world aesthetic';
      case ImageStyle.pixelArt:       return 'pixel art style, retro 8-bit/16-bit game graphics, pixelated, classic video game aesthetic';
    }
  }
}

// ─────────────────────────────────────────────────────
// 캐릭터 참조 모델
// ─────────────────────────────────────────────────────
class CharacterReference {
  final String id;
  String name;           // 캐릭터 이름 (예: "경제 마스코트", "졸라맨 주인공")
  String description;    // 캐릭터 설명 (외모, 특징 등 → 프롬프트에 삽입)
  String? imagePath;     // 업로드된 참조 이미지 파일명
  List<int>? imageBytes; // 메모리 상의 이미지 바이트 (저장 시 base64)
  bool isActive;         // 이미지 생성 시 참조 활성화 여부

  CharacterReference({
    required this.id,
    required this.name,
    this.description = '',
    this.imagePath,
    this.imageBytes,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'imagePath': imagePath,
    'imageBytes': imageBytes != null ? base64Encode(imageBytes!) : null,
    'isActive': isActive,
  };

  factory CharacterReference.fromJson(Map<String, dynamic> json) {
    return CharacterReference(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imagePath: json['imagePath'],
      imageBytes: json['imageBytes'] != null
          ? base64Decode(json['imageBytes'] as String)
          : null,
      isActive: json['isActive'] ?? true,
    );
  }
}
// nanoBanana2  = gemini-3.1-flash-image-preview  (최신 Flash, 무료한도)
// nanoBananaPro = gemini-3-pro-image-preview       (최고품질, 유료)
// nanoBananaStable = gemini-2.5-flash-image        (안정 버전, 유료)
// imagen4       = imagen-4.0-generate-001          (사진품질, 유료 $0.04)
// imagen4Ultra  = imagen-4.0-ultra-generate-001    (초고품질, 유료 $0.06)
// imagen3       = imagen-3.0-generate-002          (기존, 유료 $0.04)
// geminiFlashImage → nanoBanana2와 동일, 하위호환용으로 유지
enum ImageModel { nanoBanana2, nanoBananaPro, nanoBananaStable, imagen4, imagen4Ultra, imagen3, geminiFlashImage, stableDiffusion, localSD }
// ☁️ 클라우드(유료): kling3~veo31Fast  🖥️ 로컬(무료): animateDiff~wan26Local
enum VideoModel {
  // ── fal.ai API ──
  kling3, wan26, minimax, vidu, runway, pixverse, seedance,
  // ── fal.ai Veo 계열 (Google DeepMind) ──
  veo3, veo3Fast, veo31, veo31Fast,
  // ── OpenAI API ──
  sora2, sora2Pro,
  // ── 로컬 (Automatic1111 WebUI) ──
  animateDiff, svd, svdXt,
  // ── 로컬 (ComfyUI) ──
  wan21Local, wan26Local,
}
enum ImageResolution { hd720, fhd1080, qhd2k, uhd4k }

extension ImageRatioExt on ImageRatio {
  String get displayName {
    switch (this) {
      case ImageRatio.ratio9x16: return '9:16 (세로)';
      case ImageRatio.ratio16x9: return '16:9 (가로)';
      case ImageRatio.ratio1x1: return '1:1 (정사각)';
      case ImageRatio.ratio4x3: return '4:3';
      case ImageRatio.ratio3x4: return '3:4';
    }
  }

  String get ratioValue {
    switch (this) {
      case ImageRatio.ratio9x16: return '9:16';
      case ImageRatio.ratio16x9: return '16:9';
      case ImageRatio.ratio1x1: return '1:1';
      case ImageRatio.ratio4x3: return '4:3';
      case ImageRatio.ratio3x4: return '3:4';
    }
  }

  String get value {
    switch (this) {
      case ImageRatio.ratio9x16: return '9:16';
      case ImageRatio.ratio16x9: return '16:9';
      case ImageRatio.ratio1x1: return '1:1';
      case ImageRatio.ratio4x3: return '4:3';
      case ImageRatio.ratio3x4: return '3:4';
    }
  }
}

extension ImageModelExt on ImageModel {
  String get displayName {
    switch (this) {
      case ImageModel.nanoBanana2:      return 'Nano Banana 2 ✨ (무료한도)';
      case ImageModel.nanoBananaPro:    return 'Nano Banana Pro 🏆 (최고품질)';
      case ImageModel.nanoBananaStable: return 'Nano Banana (안정) 🛡️';
      case ImageModel.imagen4:          return 'Imagen 4 📸 (\$0.04/장)';
      case ImageModel.imagen4Ultra:     return 'Imagen 4 Ultra 💎 (\$0.06/장)';
      case ImageModel.imagen3:          return 'Imagen 3 (\$0.04/장)';
      case ImageModel.geminiFlashImage: return 'Gemini Flash Image (무료한도)';
      case ImageModel.stableDiffusion:  return 'Stable Diffusion (API)';
      case ImageModel.localSD:          return 'Stable Diffusion (로컬 무료)';
    }
  }

  /// 모델 설명
  String get description {
    switch (this) {
      case ImageModel.nanoBanana2:      return 'Gemini 3.1 Flash · 빠름 · 무료 일일한도 · 1K~4K';
      case ImageModel.nanoBananaPro:    return 'Gemini 3 Pro · Thinking모드 · 4K · 유료';
      case ImageModel.nanoBananaStable: return 'Gemini 2.5 Flash · 안정적 · 유료 ~\$0.04/장';
      case ImageModel.imagen4:          return 'Google 사진품질 · 텍스트렌더링 향상 · \$0.04/장';
      case ImageModel.imagen4Ultra:     return 'Google 최고사진품질 · 2K · \$0.06/장';
      case ImageModel.imagen3:          return 'Google 이전세대 · \$0.04/장';
      case ImageModel.geminiFlashImage: return 'Nano Banana 2와 동일 (하위호환)';
      case ImageModel.stableDiffusion:  return '외부 SD API 서버 필요';
      case ImageModel.localSD:          return '로컬 Automatic1111 WebUI 필요';
    }
  }

  /// Gemini generateContent 방식 여부 (nanoBanana 계열)
  bool get isNanoBanana => this == ImageModel.nanoBanana2 ||
      this == ImageModel.nanoBananaPro ||
      this == ImageModel.nanoBananaStable ||
      this == ImageModel.geminiFlashImage;

  /// Imagen predict 방식 여부
  bool get isImagen => this == ImageModel.imagen3 ||
      this == ImageModel.imagen4 ||
      this == ImageModel.imagen4Ultra;

  bool get isLocal => this == ImageModel.localSD;

  /// 무료 사용 가능 여부 (일일 한도 내)
  bool get isFree => this == ImageModel.localSD ||
      this == ImageModel.nanoBanana2 ||
      this == ImageModel.geminiFlashImage;

  /// 유료 결제 필요 여부
  bool get requiresBilling => isImagen ||
      this == ImageModel.nanoBananaPro ||
      this == ImageModel.nanoBananaStable;

  /// Gemini generateContent 모델 ID (nanoBanana 계열)
  String? get geminiModelId {
    switch (this) {
      case ImageModel.nanoBanana2:      return 'gemini-3.1-flash-image-preview';
      case ImageModel.nanoBananaPro:    return 'gemini-3-pro-image-preview';
      case ImageModel.nanoBananaStable: return 'gemini-2.5-flash-image';
      case ImageModel.geminiFlashImage: return 'gemini-3.1-flash-image-preview';
      default: return null;
    }
  }

  /// Imagen predict 모델 ID
  String? get imagenModelId {
    switch (this) {
      case ImageModel.imagen3:      return 'imagen-3.0-generate-002';
      case ImageModel.imagen4:      return 'imagen-4.0-generate-001';
      case ImageModel.imagen4Ultra: return 'imagen-4.0-ultra-generate-001';
      default: return null;
    }
  }
}

extension VideoModelExt on VideoModel {
  String get displayName {
    switch (this) {
      // ── fal.ai ──
      case VideoModel.kling3:     return 'Kling v3 🎬 (fal.ai)';
      case VideoModel.wan26:      return 'Wan v2.6 🌊 (fal.ai)';
      case VideoModel.minimax:    return 'MiniMax Hailuo 🌟 (fal.ai)';
      case VideoModel.vidu:       return 'Vidu Q3 🎯 (fal.ai)';
      case VideoModel.runway:     return 'Runway Gen4 ✈️ (fal.ai)';
      case VideoModel.pixverse:   return 'Pixverse v5 🎨 (fal.ai)';
      case VideoModel.seedance:   return 'Seedance v1.5 💃 (fal.ai)';
      case VideoModel.veo3:       return 'Veo 3 🌿 (Google·fal.ai)';
      case VideoModel.veo3Fast:   return 'Veo 3 Fast ⚡ (Google·fal.ai)';
      case VideoModel.veo31:      return 'Veo 3.1 🌿✨ (Google·fal.ai)';
      case VideoModel.veo31Fast:  return 'Veo 3.1 Fast ⚡✨ (Google·fal.ai)';
      // ── OpenAI ──
      case VideoModel.sora2:      return 'Sora 2 🟢 (OpenAI)';
      case VideoModel.sora2Pro:   return 'Sora 2 Pro ⭐ (OpenAI)';
      // ── 로컬 A1111 ──
      case VideoModel.animateDiff: return 'AnimateDiff 🖥️ (로컬 무료)';
      case VideoModel.svd:         return 'SVD 🖥️ (로컬 무료)';
      case VideoModel.svdXt:       return 'SVD-XT 25f 🖥️ (로컬 무료)';
      // ── 로컬 ComfyUI ──
      case VideoModel.wan21Local:  return 'Wan 2.1 로컬 🖥️ (ComfyUI)';
      case VideoModel.wan26Local:  return 'Wan 2.6 로컬 🖥️ (ComfyUI)';
    }
  }

  /// API 백엔드 종류
  VideoBackend get backend {
    switch (this) {
      case VideoModel.kling3:
      case VideoModel.wan26:
      case VideoModel.minimax:
      case VideoModel.vidu:
      case VideoModel.runway:
      case VideoModel.pixverse:
      case VideoModel.seedance:
      case VideoModel.veo3:
      case VideoModel.veo3Fast:
      case VideoModel.veo31:
      case VideoModel.veo31Fast:   return VideoBackend.fal;
      case VideoModel.sora2:
      case VideoModel.sora2Pro:    return VideoBackend.openai;
      case VideoModel.animateDiff:
      case VideoModel.svd:
      case VideoModel.svdXt:       return VideoBackend.a1111;
      case VideoModel.wan21Local:
      case VideoModel.wan26Local:  return VideoBackend.comfyui;
    }
  }

  bool get isLocal => backend == VideoBackend.a1111 || backend == VideoBackend.comfyui;
  bool get isFalAi => backend == VideoBackend.fal;
  bool get isOpenAi => backend == VideoBackend.openai;

  /// fal.ai 모델 ID (fal.ai 전용)
  String get falModelId {
    switch (this) {
      case VideoModel.kling3:    return 'fal-ai/kling-video/v3/standard/image-to-video';
      case VideoModel.wan26:     return 'fal-ai/wan-i2v-480p';
      case VideoModel.minimax:   return 'fal-ai/minimax-video/image-to-video';
      case VideoModel.vidu:      return 'vidu/q3';
      case VideoModel.runway:    return 'fal-ai/runway-gen4/image-to-video';
      case VideoModel.pixverse:  return 'fal-ai/pixverse/v4.5/image-to-video';
      case VideoModel.seedance:  return 'fal-ai/bytedance/seedance/v1.5/pro/image-to-video';
      case VideoModel.veo3:       return 'fal-ai/google/veo3/image-to-video';
      case VideoModel.veo3Fast:   return 'fal-ai/google/veo3/fast/image-to-video';
      case VideoModel.veo31:      return 'fal-ai/google/veo3.1/image-to-video';
      case VideoModel.veo31Fast:  return 'fal-ai/google/veo3.1/fast/image-to-video';
      default:                   return '';
    }
  }

  /// OpenAI 모델 ID (OpenAI 전용)
  String get openAiModelId {
    switch (this) {
      case VideoModel.sora2:    return 'sora-2';
      case VideoModel.sora2Pro: return 'sora-2-pro';
      default:                  return '';
    }
  }

  /// 지원 영상 비율 목록
  List<String> get supportedRatios {
    switch (this) {
      case VideoModel.kling3:     return ['16:9', '9:16', '1:1'];
      case VideoModel.wan26:      return ['16:9', '9:16', '1:1', '4:3'];
      case VideoModel.minimax:    return ['16:9', '9:16'];
      case VideoModel.vidu:       return ['16:9', '9:16', '4:3', '1:1'];
      case VideoModel.runway:     return ['16:9', '9:16'];
      case VideoModel.pixverse:   return ['16:9', '9:16', '4:3', '1:1'];
      case VideoModel.seedance:   return ['16:9', '9:16', '4:3', '1:1'];
      case VideoModel.veo3:       return ['16:9', '9:16'];
      case VideoModel.veo3Fast:   return ['16:9', '9:16'];
      case VideoModel.veo31:      return ['16:9', '9:16'];
      case VideoModel.veo31Fast:  return ['16:9', '9:16'];
      case VideoModel.sora2:      return ['16:9', '9:16'];
      case VideoModel.sora2Pro:   return ['16:9', '9:16'];
      case VideoModel.animateDiff: return ['16:9', '9:16', '1:1'];
      case VideoModel.svd:         return ['16:9', '9:16'];
      case VideoModel.svdXt:       return ['16:9', '9:16'];
      case VideoModel.wan21Local:  return ['16:9', '9:16', '1:1'];
      case VideoModel.wan26Local:  return ['16:9', '9:16', '1:1', '4:3'];
    }
  }

  /// 지원 영상 길이(초) 목록
  List<int> get supportedDurations {
    switch (this) {
      case VideoModel.kling3:     return [5, 10, 15];
      case VideoModel.wan26:      return [5, 10, 15];
      case VideoModel.minimax:    return [6, 10];
      case VideoModel.vidu:       return [4, 8];
      case VideoModel.runway:     return [5, 10];
      case VideoModel.pixverse:   return [5, 8];
      case VideoModel.seedance:   return [5, 10];
      case VideoModel.veo3:       return [8];
      case VideoModel.veo3Fast:   return [8];
      case VideoModel.veo31:      return [8];
      case VideoModel.veo31Fast:  return [8];
      case VideoModel.sora2:      return [5, 10, 15];
      case VideoModel.sora2Pro:   return [5, 10, 15];
      case VideoModel.animateDiff: return [2, 4];
      case VideoModel.svd:         return [4];
      case VideoModel.svdXt:       return [4];
      case VideoModel.wan21Local:  return [5, 10];
      case VideoModel.wan26Local:  return [5, 10, 15];
    }
  }

  /// 장당 예상 비용 (USD, 로컬=0)
  double get costPerClip {
    switch (this) {
      case VideoModel.kling3:     return 0.42;  // $0.084/초 × 5초
      case VideoModel.wan26:      return 0.25;  // $0.05/초 × 5초
      case VideoModel.minimax:    return 0.28;  // 6초 기준
      case VideoModel.vidu:       return 0.20;
      case VideoModel.runway:     return 0.50;  // $0.10/초 × 5초
      case VideoModel.pixverse:   return 0.20;
      case VideoModel.seedance:   return 0.33;
      case VideoModel.veo3:       return 0.80;
      case VideoModel.veo3Fast:   return 0.40;
      case VideoModel.veo31:      return 0.80;
      case VideoModel.veo31Fast:  return 0.40;
      case VideoModel.sora2:      return 0.50;  // $0.10/초 × 5초
      case VideoModel.sora2Pro:   return 1.50;  // $0.30/초 × 5초
      case VideoModel.animateDiff: return 0.0;
      case VideoModel.svd:         return 0.0;
      case VideoModel.svdXt:       return 0.0;
      case VideoModel.wan21Local:  return 0.0;
      case VideoModel.wan26Local:  return 0.0;
    }
  }

  /// VRAM 요구량 (로컬 모델)
  String get vramRequirement {
    switch (this) {
      case VideoModel.animateDiff: return '6GB+';
      case VideoModel.svd:         return '8GB+';
      case VideoModel.svdXt:       return '8GB+ (fp16 최적화)';
      case VideoModel.wan21Local:  return '8GB+ (Q4 양자화)';
      case VideoModel.wan26Local:  return '16GB+ 권장';
      default:                     return '';
    }
  }

  /// 모델 설명
  String get description {
    switch (this) {
      case VideoModel.kling3:     return '최고 품질·일관성 · 5/10/15초 · \$0.42/클립(5초)';
      case VideoModel.wan26:      return '고품질·빠름 · 5/10/15초 · \$0.25/클립(5초)';
      case VideoModel.minimax:    return '자연스러운 모션 · 6/10초 · \$0.28/클립';
      case VideoModel.vidu:       return '인물 일관성 우수 · 4/8초 · \$0.20/클립';
      case VideoModel.runway:     return '영화적 품질 · 5/10초 · \$0.50/클립(5초)';
      case VideoModel.pixverse:   return '다양한 스타일 · 5/8초 · \$0.20/클립';
      case VideoModel.seedance:   return 'ByteDance·오디오 지원 · 5/10초 · \$0.33/클립(5초)';
      case VideoModel.veo3:       return 'Google DeepMind 개발 (fal.ai 경유) · 오디오 자동생성 · 8초 · \$0.80/클립';
      case VideoModel.veo3Fast:   return 'Google DeepMind 개발 (fal.ai 경유) · 빠름+오디오 · 8초 · \$0.40/클립';
      case VideoModel.veo31:      return 'Google DeepMind 최신 (fal.ai 경유) · 오디오 자동생성 · 8초 · \$0.80/클립';
      case VideoModel.veo31Fast:  return 'Google 최신+빠름 (fal.ai 경유) · 8초 · \$0.40/클립';
      case VideoModel.sora2:      return 'OpenAI 표준 · 5~15초 · \$0.50/클립(5초)';
      case VideoModel.sora2Pro:   return 'OpenAI Pro·1080p · 5~15초 · \$1.50/클립(5초)';
      case VideoModel.animateDiff: return 'SD 1.5 기반 · 2/4초 · 무료 · A1111 필요 · 6GB+';
      case VideoModel.svd:         return 'Stability AI 공식 i2v · 4초 · 무료 · A1111 필요 · 8GB+';
      case VideoModel.svdXt:       return 'SVD 25프레임 확장 · 4초 · 무료 · fp16 · 8GB+';
      case VideoModel.wan21Local:  return '오픈소스 고품질 · 5/10초 · 무료 · ComfyUI · 8GB+(Q4)';
      case VideoModel.wan26Local:  return '최신 오픈소스 · 5~15초 · 무료 · ComfyUI · 16GB+';
    }
  }
}

/// 영상 생성 백엔드 종류
enum VideoBackend { fal, openai, a1111, comfyui }

extension ImageResolutionExt on ImageResolution {
  String get displayName {
    switch (this) {
      case ImageResolution.hd720: return '720p (HD)';
      case ImageResolution.fhd1080: return '1080p (FHD)';
      case ImageResolution.qhd2k: return '2K (QHD)';
      case ImageResolution.uhd4k: return '4K (UHD)';
    }
  }
}

class VideoSettings {
  VideoStyle style;
  ImageModel imageModel;
  VideoModel videoModel;
  ImageRatio imageRatio;
  ImageResolution imageResolution;
  ImageStyle imageStyle;            // 이미지 스타일
  List<CharacterReference> characters; // 캐릭터 참조 목록
  int aiVideoSceneCount; // 앞 몇 장면을 AI 영상으로
  double transitionDuration; // 화면 전환 속도 (초)
  double sceneDuration; // 장면당 기본 표시 시간
  bool useZoomEffect;
  double zoomIntensity;
  bool useBgm;
  String localSdUrl;      // 로컬 A1111 WebUI URL
  String localSdModel;
  String localComfyUrl;   // 로컬 ComfyUI URL
  // ── Wan 모델 파일명 (ComfyUI에 실제 있는 파일명) ──
  String wanUnetName;      // UNet 모델 파일명
  String wanClipName;      // CLIP(T5) 파일명
  String wanVaeName;       // VAE 파일명
  String wanClipVisionName; // CLIP Vision 파일명
  // ── AI 영상 생성 설정 ──
  String videoRatio;   // '16:9' | '9:16' | '1:1' | '4:3'
  int    videoDuration; // 초 (5/8/10/15)
  bool   videoHd;      // HD(720p) vs FHD(1080p)

  VideoSettings({
    this.style = VideoStyle.slideshow,
    this.imageModel = ImageModel.nanoBanana2,
    this.videoModel = VideoModel.kling3,
    this.imageRatio = ImageRatio.ratio16x9,
    this.imageResolution = ImageResolution.fhd1080,
    this.imageStyle = ImageStyle.none,
    List<CharacterReference>? characters,
    this.aiVideoSceneCount = 0,  // 기본값 0: 동영상 생성 없이 이미지만 사용
    this.transitionDuration = 0.5,
    this.sceneDuration = 5.0,
    this.useZoomEffect = true,
    this.zoomIntensity = 1.1,
    this.useBgm = true,
    this.localSdUrl = 'http://127.0.0.1:7860',
    this.localSdModel = '',
    this.localComfyUrl = 'http://127.0.0.1:8188',
    this.wanUnetName = 'Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors',
    this.wanClipName = 'umt5_xxl_fp8_e4m3fn_scaled.safetensors',
    this.wanVaeName = 'Wan2.1_VAE.pth',
    this.wanClipVisionName = 'clip_vision_h.safetensors',
    this.videoRatio = '16:9',
    this.videoDuration = 5,
    this.videoHd = false,
  }) : characters = characters ?? [];

  Map<String, dynamic> toJson() => {
        'style': style.index,
        'imageModel': imageModel.name,
        'videoModel': videoModel.name,
        'imageRatio': imageRatio.index,
        'imageResolution': imageResolution.index,
        'imageStyle': imageStyle.name,
        'characters': characters.map((c) => c.toJson()).toList(),
        'aiVideoSceneCount': aiVideoSceneCount,
        'transitionDuration': transitionDuration,
        'sceneDuration': sceneDuration,
        'useZoomEffect': useZoomEffect,
        'zoomIntensity': zoomIntensity,
        'useBgm': useBgm,
        'localSdUrl': localSdUrl,
        'localSdModel': localSdModel,
        'localComfyUrl': localComfyUrl,
        'wanUnetName': wanUnetName,
        'wanClipName': wanClipName,
        'wanVaeName': wanVaeName,
        'wanClipVisionName': wanClipVisionName,
        'videoRatio': videoRatio,
        'videoDuration': videoDuration,
        'videoHd': videoHd,
      };

  factory VideoSettings.fromJson(Map<String, dynamic> json) {
    ImageStyle parsedStyle = ImageStyle.none;
    try {
      parsedStyle = ImageStyle.values.firstWhere((e) => e.name == (json['imageStyle'] ?? 'none'));
    } catch (_) {}

    List<CharacterReference> chars = [];
    if (json['characters'] != null) {
      try {
        chars = (json['characters'] as List)
            .map((c) => CharacterReference.fromJson(c as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    return VideoSettings(
      style: VideoStyle.values[json['style'] ?? 0],
      imageModel: _parseImageModel(json['imageModel']),
      videoModel: _parseVideoModel(json['videoModel']),
      imageRatio: ImageRatio.values[json['imageRatio'] ?? 1],
      imageResolution: ImageResolution.values[json['imageResolution'] ?? 1],
      imageStyle: parsedStyle,
      characters: chars,
      aiVideoSceneCount: json['aiVideoSceneCount'] ?? 0,  // 기본값 0
      transitionDuration: (json['transitionDuration'] ?? 0.5).toDouble(),
      sceneDuration: (json['sceneDuration'] ?? 5.0).toDouble(),
      useZoomEffect: json['useZoomEffect'] ?? true,
      zoomIntensity: (json['zoomIntensity'] ?? 1.1).toDouble(),
      useBgm: json['useBgm'] ?? true,
      localSdUrl: json['localSdUrl'] ?? 'http://127.0.0.1:7860',
      localSdModel: json['localSdModel'] ?? '',
      localComfyUrl: json['localComfyUrl'] ?? 'http://127.0.0.1:8188',
      wanUnetName: json['wanUnetName'] ?? 'Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors',
      wanClipName: json['wanClipName'] ?? 'umt5_xxl_fp8_e4m3fn_scaled.safetensors',
      wanVaeName: json['wanVaeName'] ?? 'Wan2.1_VAE.pth',
      wanClipVisionName: json['wanClipVisionName'] ?? 'clip_vision_h.safetensors',
      videoRatio: json['videoRatio'] ?? '16:9',
      videoDuration: json['videoDuration'] ?? 5,
      videoHd: json['videoHd'] ?? false,
    );
  }
}

/// ImageModel JSON 역직렬화 - 이름 또는 인덱스 모두 지원 (이전 저장 데이터 호환)
ImageModel _parseImageModel(dynamic value) {
  if (value == null) return ImageModel.nanoBanana2;
  if (value is String) {
    // 이름으로 찾기
    try {
      return ImageModel.values.firstWhere((e) => e.name == value);
    } catch (_) {}
    // 이전 이름 매핑 (마이그레이션)
    const legacyMap = {
      'nanoBanana1':    ImageModel.nanoBanana2,
      'gptImage':       ImageModel.imagen4,
      'zImage':         ImageModel.nanoBanana2,
      'seedream':       ImageModel.nanoBanana2,
      'geminiFlashImage': ImageModel.nanoBanana2,
    };
    return legacyMap[value] ?? ImageModel.nanoBanana2;
  }
  if (value is int) {
    // 이전 인덱스 기반 저장 데이터 마이그레이션
    // 구 enum 순서: nanoBanana2(0), nanoBanana1(1), nanoBananaPro(2), gptImage(3),
    //              imagen3(4), geminiFlashImage(5), stableDiffusion(6), zImage(7), seedream(8), localSD(9)
    const legacyIndex = [
      ImageModel.nanoBanana2,    // 0
      ImageModel.nanoBanana2,    // 1 (nanoBanana1 → nanoBanana2)
      ImageModel.nanoBananaPro,  // 2
      ImageModel.imagen4,        // 3 (gptImage → imagen4)
      ImageModel.imagen3,        // 4
      ImageModel.nanoBanana2,    // 5 (geminiFlashImage → nanoBanana2)
      ImageModel.stableDiffusion,// 6
      ImageModel.nanoBanana2,    // 7 (zImage → nanoBanana2)
      ImageModel.nanoBanana2,    // 8 (seedream → nanoBanana2)
      ImageModel.localSD,        // 9
    ];
    if (value >= 0 && value < legacyIndex.length) return legacyIndex[value];
  }
  return ImageModel.nanoBanana2;
}

/// VideoModel JSON 역직렬화 - 이름 또는 인덱스 모두 지원
VideoModel _parseVideoModel(dynamic value) {
  if (value == null) return VideoModel.kling3;
  if (value is String) {
    try {
      return VideoModel.values.firstWhere((e) => e.name == value);
    } catch (_) {}
    // 이전 이름 마이그레이션
    const legacyMap = <String, VideoModel>{
      'sora1':  VideoModel.sora2,    // 구 sora1 → sora2
      'sora2':  VideoModel.sora2Pro, // 구 sora2(Pro) → sora2Pro
    };
    if (legacyMap.containsKey(value)) return legacyMap[value]!;
  }
  if (value is int) {
    // 구 enum 순서: kling3(0) wan26(1) minimax(2) vidu(3) runway(4) sora1(5) sora2(6) pixverse(7) seedance(8)
    const legacy = [
      VideoModel.kling3, VideoModel.wan26, VideoModel.minimax, VideoModel.vidu,
      VideoModel.runway, VideoModel.sora2, VideoModel.sora2Pro,
      VideoModel.pixverse, VideoModel.seedance,
    ];
    if (value >= 0 && value < legacy.length) return legacy[value];
  }
  return VideoModel.kling3;
}

// 썸네일 설정
class ThumbnailSettings {
  String templateId;
  String logoPath;
  String watermarkPath;
  String introVideoPath;
  String outroVideoPath;
  String fontFamily;
  String titleColor;
  String backgroundColor;
  bool useTemplate;

  ThumbnailSettings({
    this.templateId = '',
    this.logoPath = '',
    this.watermarkPath = '',
    this.introVideoPath = '',
    this.outroVideoPath = '',
    this.fontFamily = 'NotoSansKR',
    this.titleColor = '#FFFFFF',
    this.backgroundColor = '#000000',
    this.useTemplate = false,
  });

  Map<String, dynamic> toJson() => {
        'templateId': templateId,
        'logoPath': logoPath,
        'watermarkPath': watermarkPath,
        'introVideoPath': introVideoPath,
        'outroVideoPath': outroVideoPath,
        'fontFamily': fontFamily,
        'titleColor': titleColor,
        'backgroundColor': backgroundColor,
        'useTemplate': useTemplate,
      };

  factory ThumbnailSettings.fromJson(Map<String, dynamic> json) => ThumbnailSettings(
        templateId: json['templateId'] ?? '',
        logoPath: json['logoPath'] ?? '',
        watermarkPath: json['watermarkPath'] ?? '',
        introVideoPath: json['introVideoPath'] ?? '',
        outroVideoPath: json['outroVideoPath'] ?? '',
        fontFamily: json['fontFamily'] ?? 'NotoSansKR',
        titleColor: json['titleColor'] ?? '#FFFFFF',
        backgroundColor: json['backgroundColor'] ?? '#000000',
        useTemplate: json['useTemplate'] ?? false,
      );
}
