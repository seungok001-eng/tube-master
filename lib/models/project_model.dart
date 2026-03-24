import 'dart:typed_data';
import 'channel_model.dart';

enum ScriptAiModel {
  // Gemini 2.5 계열
  geminiFlash,
  geminiFlashLite,
  geminiPro,
  // Gemini 3.x 계열 (최신)
  gemini3Flash,
  gemini31FlashImage,
  gemini3ProImage,
  // Claude 계열
  claude35Sonnet,
  claude4Sonnet,
}

extension ScriptAiModelExt on ScriptAiModel {
  String get displayName {
    switch (this) {
      case ScriptAiModel.geminiFlash: return 'Gemini 2.5 Flash (추천 ✅)';
      case ScriptAiModel.geminiFlashLite: return 'Gemini 2.5 Flash-Lite (저렴 💰)';
      case ScriptAiModel.geminiPro: return 'Gemini 2.5 Pro (최고품질 🏆)';
      case ScriptAiModel.gemini3Flash: return 'Gemini 3.0 Flash (최신 🚀)';
      case ScriptAiModel.gemini31FlashImage: return 'Gemini 3.1 Flash-Image (이미지 특화)';
      case ScriptAiModel.gemini3ProImage: return 'Gemini 3 Pro Image (최고급 이미지)';
      case ScriptAiModel.claude35Sonnet: return 'Claude 3.5 Sonnet';
      case ScriptAiModel.claude4Sonnet: return 'Claude 3.7 Sonnet (최신)';
    }
  }

  String get apiModelId {
    switch (this) {
      case ScriptAiModel.geminiFlash: return 'gemini-2.5-flash';
      case ScriptAiModel.geminiFlashLite: return 'gemini-2.5-flash-lite-preview-06-17';
      case ScriptAiModel.geminiPro: return 'gemini-2.5-pro';
      case ScriptAiModel.gemini3Flash: return 'gemini-3-flash-preview';
      case ScriptAiModel.gemini31FlashImage: return 'gemini-3.1-flash-image-preview';
      case ScriptAiModel.gemini3ProImage: return 'gemini-3-pro-image-preview';
      case ScriptAiModel.claude35Sonnet: return 'claude-3-5-sonnet-20241022';
      case ScriptAiModel.claude4Sonnet: return 'claude-3-7-sonnet-20250219';
    }
  }

  bool get isGemini => this != ScriptAiModel.claude35Sonnet &&
                       this != ScriptAiModel.claude4Sonnet;

  bool get isClaude => this == ScriptAiModel.claude35Sonnet ||
                       this == ScriptAiModel.claude4Sonnet;

  String get modelGroup {
    if (isClaude) return 'Claude';
    if (this == ScriptAiModel.gemini3Flash ||
        this == ScriptAiModel.gemini31FlashImage ||
        this == ScriptAiModel.gemini3ProImage) return 'Gemini 3.x';
    return 'Gemini 2.5';
  }
}

enum ProjectStatus { 
  draft,         // 초안
  scriptReady,   // 대본 완료
  sceneSplit,    // 장면 분할 완료
  mediaGenerating, // 미디어 생성 중
  mediaReady,    // 미디어 완료
  ttsReady,      // 음성 완료
  subtitleReady, // 자막 완료
  rendering,     // 렌더링 중
  rendered,      // 렌더링 완료
  thumbnailReady, // 썸네일 완료
  uploading,     // 업로드 중
  uploaded,      // 업로드 완료
}

extension ProjectStatusExt on ProjectStatus {
  String get displayName {
    switch (this) {
      case ProjectStatus.draft: return '초안';
      case ProjectStatus.scriptReady: return '대본 완료';
      case ProjectStatus.sceneSplit: return '장면 분할 완료';
      case ProjectStatus.mediaGenerating: return '미디어 생성 중';
      case ProjectStatus.mediaReady: return '미디어 완료';
      case ProjectStatus.ttsReady: return '음성 완료';
      case ProjectStatus.subtitleReady: return '자막 완료';
      case ProjectStatus.rendering: return '렌더링 중';
      case ProjectStatus.rendered: return '렌더링 완료';
      case ProjectStatus.thumbnailReady: return '썸네일 완료';
      case ProjectStatus.uploading: return '업로드 중';
      case ProjectStatus.uploaded: return '업로드 완료';
    }
  }

  int get step => index;
}

class SceneModel {
  String id;
  int order;
  String scriptText;
  String imagePrompt;
  String videoPrompt;
  String imagePath;
  String videoPath;
  String audioPath;
  double duration; // 초
  bool useAiVideo; // AI 영상 사용 여부
  bool isGenerated;
  
  // 런타임 전용 (JSON 저장 안함)
  Uint8List? imageBytes;    // 생성된 이미지 바이트
  Uint8List? videoBytes;    // 생성된 AI 영상 바이트 (mp4)
  Uint8List? sceneTtsBytes; // 장면별 TTS 오디오 바이트 (duration 자동 계산용)

  SceneModel({
    required this.id,
    required this.order,
    required this.scriptText,
    this.imagePrompt = '',
    this.videoPrompt = '',
    this.imagePath = '',
    this.videoPath = '',
    this.audioPath = '',
    this.duration = 5.0,
    this.useAiVideo = false,
    this.isGenerated = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'order': order,
        'scriptText': scriptText,
        'imagePrompt': imagePrompt,
        'videoPrompt': videoPrompt,
        'imagePath': imagePath,
        'videoPath': videoPath,
        'audioPath': audioPath,
        'duration': duration,
        'useAiVideo': useAiVideo,
        'isGenerated': isGenerated,
      };

  factory SceneModel.fromJson(Map<String, dynamic> json) => SceneModel(
        id: json['id'],
        order: json['order'],
        scriptText: json['scriptText'],
        imagePrompt: json['imagePrompt'] ?? '',
        videoPrompt: json['videoPrompt'] ?? '',
        imagePath: json['imagePath'] ?? '',
        videoPath: json['videoPath'] ?? '',
        audioPath: json['audioPath'] ?? '',
        duration: (json['duration'] ?? 5.0).toDouble(),
        useAiVideo: json['useAiVideo'] ?? false,
        isGenerated: json['isGenerated'] ?? false,
      );
}

class SubtitleEntry {
  String id;
  double startTime; // 초
  double endTime; // 초
  String text;
  bool isEdited;

  SubtitleEntry({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.text,
    this.isEdited = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime,
        'endTime': endTime,
        'text': text,
        'isEdited': isEdited,
      };

  factory SubtitleEntry.fromJson(Map<String, dynamic> json) => SubtitleEntry(
        id: json['id'],
        startTime: (json['startTime'] ?? 0.0).toDouble(),
        endTime: (json['endTime'] ?? 0.0).toDouble(),
        text: json['text'],
        isEdited: json['isEdited'] ?? false,
      );

  // SRT 형식 변환
  String toSrt(int index) {
    String formatTime(double seconds) {
      final h = (seconds ~/ 3600).toString().padLeft(2, '0');
      final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final s = (seconds % 60).toStringAsFixed(3).padLeft(6, '0').replaceAll('.', ',');
      return '$h:$m:$s';
    }
    return '$index\n${formatTime(startTime)} --> ${formatTime(endTime)}\n$text\n';
  }
}

class YoutubeUploadSettings {
  String title;
  String description;
  List<String> tags;
  String categoryId;
  String privacyStatus; // public, private, unlisted
  bool isMadeForKids;
  DateTime? scheduledTime;
  String thumbnailPath;

  YoutubeUploadSettings({
    this.title = '',
    this.description = '',
    this.tags = const [],
    this.categoryId = '22',
    this.privacyStatus = 'public',
    this.isMadeForKids = false,
    this.scheduledTime,
    this.thumbnailPath = '',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'tags': tags,
        'categoryId': categoryId,
        'privacyStatus': privacyStatus,
        'isMadeForKids': isMadeForKids,
        'scheduledTime': scheduledTime?.toIso8601String(),
        'thumbnailPath': thumbnailPath,
      };

  factory YoutubeUploadSettings.fromJson(Map<String, dynamic> json) => YoutubeUploadSettings(
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        tags: List<String>.from(json['tags'] ?? []),
        categoryId: json['categoryId'] ?? '22',
        privacyStatus: json['privacyStatus'] ?? 'public',
        isMadeForKids: json['isMadeForKids'] ?? false,
        scheduledTime: json['scheduledTime'] != null ? DateTime.parse(json['scheduledTime']) : null,
        thumbnailPath: json['thumbnailPath'] ?? '',
      );
}

class ProjectModel {
  final String id;
  String title;
  String channelId;
  ChannelType channelType;
  ProjectStatus status;
  
  // 대본 관련
  String script; // 전체 대본
  ScriptAiModel scriptModel;
  int targetMinutes; // 목표 영상 길이 (분)
  bool isDirectInput; // 직접 입력 여부
  
  // 장면 관련
  List<SceneModel> scenes;
  
  // 자막
  List<SubtitleEntry> subtitles;
  
  // 파일 경로
  String ttsAudioPath;
  String finalVideoPath;
  String thumbnailPath;
  String projectFolderPath;
  
  // 런타임 전용 (JSON 저장 안함)
  Uint8List? ttsAudioBytes; // 생성된 TTS 오디오 바이트
  Uint8List? thumbnailBytes; // 생성된 썸네일 바이트
  
  // 유튜브 업로드
  YoutubeUploadSettings uploadSettings;
  
  // 비용 추적
  double estimatedCost;
  double actualCost;
  
  DateTime createdAt;
  DateTime updatedAt;

  ProjectModel({
    required this.id,
    required this.title,
    required this.channelId,
    required this.channelType,
    this.status = ProjectStatus.draft,
    this.script = '',
    this.scriptModel = ScriptAiModel.geminiFlash,
    this.targetMinutes = 20,
    this.isDirectInput = false,
    List<SceneModel>? scenes,
    List<SubtitleEntry>? subtitles,
    this.ttsAudioPath = '',
    this.finalVideoPath = '',
    this.thumbnailPath = '',
    this.projectFolderPath = '',
    YoutubeUploadSettings? uploadSettings,
    this.estimatedCost = 0.0,
    this.actualCost = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : scenes = scenes ?? [],
        subtitles = subtitles ?? [],
        uploadSettings = uploadSettings ?? YoutubeUploadSettings(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get totalScenes => scenes.length;
  int get generatedScenes => scenes.where((s) => s.isGenerated).length;
  double get progress => totalScenes == 0 ? 0 : generatedScenes / totalScenes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'channelId': channelId,
        'channelType': channelType.index,
        'status': status.index,
        'script': script,
        'scriptModel': scriptModel.index,
        'targetMinutes': targetMinutes,
        'isDirectInput': isDirectInput,
        'scenes': scenes.map((s) => s.toJson()).toList(),
        'subtitles': subtitles.map((s) => s.toJson()).toList(),
        'ttsAudioPath': ttsAudioPath,
        'finalVideoPath': finalVideoPath,
        'thumbnailPath': thumbnailPath,
        'projectFolderPath': projectFolderPath,
        'uploadSettings': uploadSettings.toJson(),
        'estimatedCost': estimatedCost,
        'actualCost': actualCost,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ProjectModel.fromJson(Map<String, dynamic> json) => ProjectModel(
        id: json['id'],
        title: json['title'],
        channelId: json['channelId'],
        channelType: ChannelType.values[json['channelType']],
        status: ProjectStatus.values[json['status'] ?? 0],
        script: json['script'] ?? '',
        scriptModel: ScriptAiModel.values[json['scriptModel'] ?? 0],
        targetMinutes: json['targetMinutes'] ?? 20,
        isDirectInput: json['isDirectInput'] ?? false,
        scenes: (json['scenes'] as List<dynamic>?)
                ?.map((s) => SceneModel.fromJson(s))
                .toList() ?? [],
        subtitles: (json['subtitles'] as List<dynamic>?)
                ?.map((s) => SubtitleEntry.fromJson(s))
                .toList() ?? [],
        ttsAudioPath: json['ttsAudioPath'] ?? '',
        finalVideoPath: json['finalVideoPath'] ?? '',
        thumbnailPath: json['thumbnailPath'] ?? '',
        projectFolderPath: json['projectFolderPath'] ?? '',
        uploadSettings: YoutubeUploadSettings.fromJson(json['uploadSettings'] ?? {}),
        estimatedCost: (json['estimatedCost'] ?? 0.0).toDouble(),
        actualCost: (json['actualCost'] ?? 0.0).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      );
}
