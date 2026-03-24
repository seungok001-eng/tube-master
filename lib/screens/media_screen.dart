import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/app_provider.dart';
import '../models/project_model.dart';
import '../models/channel_model.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../utils/web_audio_helper.dart';

// ─────────────────────────────────────
// 미디어 생성 화면 (이미지 + TTS + 자막)
// ─────────────────────────────────────
class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() => _tabIndex = _tabCtrl.index);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final project = provider.currentProject;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, provider, project),
            TabBar(
              controller: _tabCtrl,
              tabs: const [
                Tab(text: '🖼️ 이미지 생성'),
                Tab(text: '🎙️ TTS 음성'),
                Tab(text: '📝 자막 편집'),
              ],
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              labelStyle: GoogleFonts.notoSansKr(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.notoSansKr(fontSize: 13),
            ),
            Expanded(
              child: project == null
                  ? _buildNoProjectState(context, provider)
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _ImageGenerationTab(project: project, provider: provider),
                        _TtsTab(project: project, provider: provider),
                        _SubtitleTab(project: project, provider: provider),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AppProvider provider, ProjectModel? project) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_rounded, color: AppTheme.primary, size: 22),
          const SizedBox(width: 10),
          Text('미디어 생성',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          if (project != null)
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  project.title,
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.primaryLight, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          const Spacer(),
          if (project == null)
            TextButton.icon(
              onPressed: () => provider.setNavIndex(2),
              icon: const Icon(Icons.folder_open_rounded, size: 16),
              label: Text('프로젝트 선택', style: GoogleFonts.notoSansKr()),
            ),
          if (project != null)
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.bgCard,
                    title: Text('대본 화면으로 이동',
                        style: GoogleFonts.notoSansKr(
                            color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                    content: Text(
                      '대본 작성 화면으로 돌아가서 대본을 수정할 수 있습니다.\n\n'
                      '수정 후 장면 재분할 또는 이미지/TTS 재생성이 필요할 수 있습니다.',
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('취소', style: GoogleFonts.notoSansKr(
                            color: AppTheme.textSecondary)),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          provider.setNavIndex(3); // 대본 작성 화면
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: Text('대본 수정하기',
                            style: GoogleFonts.notoSansKr(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: Text('대본 수정', style: GoogleFonts.notoSansKr(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoProjectState(BuildContext context, AppProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text('프로젝트를 먼저 선택하세요',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text('대본 작성 화면에서 장면 분할까지 완료한 후 이용하세요',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textHint, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => provider.setNavIndex(3),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Text('대본 작성으로 이동', style: GoogleFonts.notoSansKr()),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────
// 탭 1: 이미지 생성
// ───────────────────────────────────────
class _ImageGenerationTab extends StatefulWidget {
  final ProjectModel project;
  final AppProvider provider;
  const _ImageGenerationTab({required this.project, required this.provider});

  @override
  State<_ImageGenerationTab> createState() => _ImageGenerationTabState();
}

class _ImageGenerationTabState extends State<_ImageGenerationTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 탭 전환 시에도 State 유지 (생성 작업 중단 방지)
  bool _isGenerating = false;
  bool _isCancelled = false;   // 전체 생성 취소 플래그
  bool _isVideoGenerating = false; // 단독 영상 생성 중 여부
  bool _isVideoCancelled = false;  // 영상 취소 플래그 (단독/전체 공용)
  int _currentScene = 0;
  String _statusMsg = '';
  int _generatingVideoScene = -1; // 현재 영상 생성 중인 씬 인덱스
  double _videoSceneProgress = 0.0; // 현재 씬 영상 생성 진행률 (0.0~1.0)
  String _videoSceneProgressText = ''; // 진행 상태 텍스트
  ImageModel _selectedModel = ImageModel.nanoBanana2;
  ImageRatio _selectedRatio = ImageRatio.ratio16x9;
  ImageResolution _selectedRes = ImageResolution.fhd1080;
  ImageStyle _selectedStyle = ImageStyle.none;
  int _aiVideoSceneCount = 0;         // AI 영상으로 만들 장면 수
  int _concurrency = 3;
  final List<int> _errorScenes = [];
  final Map<int, String> _errorMessages = {};
  // ── AI 영상 설정 ──
  VideoModel _videoModel = VideoModel.kling3;
  String _videoRatio = '16:9';
  int _videoDuration = 5;
  bool _videoHd = false;

  // 캐릭터 참조 목록 (채널 설정에서 로드 + 로컬 관리)
  final List<CharacterReference> _characters = [];

  // ImageResolution → Gemini imageSize 문자열 변환
  String get _selectedResolution {
    switch (_selectedRes) {
      case ImageResolution.hd720:   return '512';   // Flash만 지원
      case ImageResolution.fhd1080: return '1K';
      case ImageResolution.qhd2k:   return '2K';
      case ImageResolution.uhd4k:   return '4K';
    }
  }

  @override
  void initState() {
    super.initState();
    // 채널 설정에서 스타일/캐릭터 로드
    final channel = widget.provider.channels
        .where((c) => c.id == widget.project.channelId)
        .firstOrNull;
    if (channel != null) {
      _selectedStyle = channel.videoSettings.imageStyle;
      _selectedModel = channel.videoSettings.imageModel;
      _selectedRatio = channel.videoSettings.imageRatio;
      _selectedRes = channel.videoSettings.imageResolution;
      _characters.addAll(channel.videoSettings.characters);
      _videoModel = channel.videoSettings.videoModel;
      _videoRatio = channel.videoSettings.videoRatio;
      _videoDuration = channel.videoSettings.videoDuration;
      _videoHd = channel.videoSettings.videoHd;
      _aiVideoSceneCount = channel.videoSettings.aiVideoSceneCount;
    }
  }

  // 채널 설정에 스타일/캐릭터 저장
  void _saveSettingsToChannel() {
    final channel = widget.provider.channels
        .where((c) => c.id == widget.project.channelId)
        .firstOrNull;
    if (channel == null) return;
    final updated = channel.copyWith(
      videoSettings: VideoSettings(
        style: channel.videoSettings.style,
        imageModel: _selectedModel,
        videoModel: _videoModel,
        imageRatio: _selectedRatio,
        imageResolution: _selectedRes,
        imageStyle: _selectedStyle,
        characters: List.from(_characters),
        aiVideoSceneCount: _aiVideoSceneCount,
        transitionDuration: channel.videoSettings.transitionDuration,
        sceneDuration: channel.videoSettings.sceneDuration,
        useZoomEffect: channel.videoSettings.useZoomEffect,
        zoomIntensity: channel.videoSettings.zoomIntensity,
        useBgm: channel.videoSettings.useBgm,
        localSdUrl: channel.videoSettings.localSdUrl,
        localSdModel: channel.videoSettings.localSdModel,
        videoRatio: _videoRatio,
        videoDuration: _videoDuration,
        videoHd: _videoHd,
      ),
    );
    widget.provider.updateChannel(updated);
  }

  // 생성 진행률
  double get _progress =>
      widget.project.totalScenes == 0
          ? 0
          : _currentScene / widget.project.totalScenes;

  Future<void> _generateAllImages() async {
    if (widget.project.scenes.isEmpty) {
      _showSnack('장면이 없습니다. 대본 작성 화면에서 장면을 분할해주세요.');
      return;
    }
    final apiKey = widget.provider.apiKeys.geminiApiKey;
    if (apiKey.isEmpty && !_selectedModel.isLocal) {
      _showSnack('설정에서 Gemini API 키를 입력해주세요.');
      return;
    }
    if (_aiVideoSceneCount > 0 && _videoModel.isFalAi && widget.provider.apiKeys.falApiKey.isEmpty) {
      _showSnack('AI 영상 생성을 위해 설정에서 fal.ai API 키를 입력해주세요.');
      return;
    }
    if (_aiVideoSceneCount > 0 && _videoModel.isOpenAi && widget.provider.apiKeys.openAiApiKey.isEmpty) {
      _showSnack('Sora 영상 생성을 위해 설정에서 OpenAI API 키를 입력해주세요.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _isCancelled = false;
      _currentScene = 0;
      _statusMsg = '이미지 생성 준비 중...';
      _errorScenes.clear();
      _errorMessages.clear();
    });

    // ✅ 전체 재생성 시 모든 씬 상태 초기화 (이전 생성 결과 제거)
    for (final scene in widget.project.scenes) {
      scene.isGenerated = false;
      scene.imageBytes = null;
      scene.videoBytes = null;
      scene.videoPath = '';
    }

    // AI 영상 플래그 설정
    for (int i = 0; i < widget.project.scenes.length; i++) {
      widget.project.scenes[i].useAiVideo = (i < _aiVideoSceneCount);
    }

    final geminiService = GeminiService(apiKey);
    final scenes = widget.project.scenes;

    // ── 1단계: 전체 장면 이미지 생성 ──
    int imgSuccess = 0;
    for (int start = 0; start < scenes.length; start += _concurrency) {
      if (!mounted || _isCancelled) break;
      final end = (start + _concurrency).clamp(0, scenes.length);
      final batch = List.generate(end - start, (i) => start + i);

      setState(() {
        _currentScene = end;
        // ✅ 수정: start+1 ~ end 표시 (end가 scenes.length를 초과하지 않도록)
        _statusMsg = '[1/2] 이미지 생성 ${start + 1}~$end / ${scenes.length}장 ($_concurrency개 동시)';
      });

      final results = await Future.wait(
        batch.map((i) => _generateOneImage(geminiService, i)),
      );
      for (final ok in results) { if (ok) imgSuccess++; }

      if (end < scenes.length && !_isCancelled) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // ── 2단계: AI 영상 생성 (이미지가 있는 AI 영상 장면만, 순차 처리) ──
    if (_aiVideoSceneCount > 0 && !_isCancelled) {
      final channel = widget.provider.channels
          .where((c) => c.id == widget.project.channelId).firstOrNull;
      final videoService = VideoGenerationService(
        falApiKey: widget.provider.apiKeys.falApiKey,
        openAiApiKey: widget.provider.apiKeys.openAiApiKey,
        a1111Url: channel?.videoSettings.localSdUrl ?? 'http://127.0.0.1:7860',
        comfyUrl: channel?.videoSettings.localComfyUrl ?? 'http://127.0.0.1:8188',
        wanUnetName: channel?.videoSettings.wanUnetName ?? 'Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors',
        wanClipName: channel?.videoSettings.wanClipName ?? 'umt5_xxl_fp8_e4m3fn_scaled.safetensors',
        wanVaeName: channel?.videoSettings.wanVaeName ?? 'Wan2.1_VAE.pth',
        wanClipVisionName: channel?.videoSettings.wanClipVisionName ?? 'clip_vision_h.safetensors',
      );
      int videoSuccess = 0;
      int videoTotal = 0;

      for (int i = 0; i < scenes.length && i < _aiVideoSceneCount; i++) {
        if (_isCancelled || _isVideoCancelled) break;
        final scene = scenes[i];
        if (scene.imageBytes == null) {
          // 이미지 생성 실패 장면은 영상도 건너뜀
          setState(() => _statusMsg = '[2/2] 장면 ${i + 1} 이미지 없어 영상 건너뜀');
          continue;
        }
        videoTotal++;
        setState(() {
          _statusMsg = '[2/2] AI 영상 생성 중... 장면 ${i + 1}/$_aiVideoSceneCount '
              '(${_videoModel.displayName}, ${_videoRatio}, ${_videoDuration}초)';
          _generatingVideoScene = i;
          _videoSceneProgress = 0.0;
          _videoSceneProgressText = '시작 중...';
        });

        try {
          final videoBytes = await videoService.generateVideo(
            model: _videoModel,
            imageBytes: scene.imageBytes!,
            prompt: scene.imagePrompt.isNotEmpty
                ? scene.imagePrompt
                : 'Smooth cinematic motion based on the scene',
            aspectRatio: _videoRatio,
            duration: _videoDuration,
            hd: _videoHd,
            onProgress: (status, progress) {
              if (mounted) {
                setState(() {
                  _statusMsg = '[2/2] 장면 ${i + 1} 영상 생성 중... '
                      '$status (${(progress * 100).toInt()}%)';
                  _videoSceneProgress = progress;
                  _videoSceneProgressText = status;
                });
              }
            },
          );
          scene.videoBytes = videoBytes;
          setState(() {
            _generatingVideoScene = -1;
            _videoSceneProgress = 0.0;
            _videoSceneProgressText = '';
          });
          // WEBP/MP4 자동 감지하여 확장자 설정
          final isWebp = videoBytes.length > 4 &&
              videoBytes[0] == 0x52 && videoBytes[1] == 0x49 &&
              videoBytes[2] == 0x46 && videoBytes[3] == 0x46;
          scene.videoPath = 'aivideo_${scene.id}.${isWebp ? 'webp' : 'mp4'}';
          videoSuccess++;
          if (mounted) {
            setState(() {
              _statusMsg = '[2/2] 장면 ${i + 1} 영상 완료 ✅ ($videoSuccess/$videoTotal)';
            });
          }
        } catch (e) {
          final errStr = e.toString().replaceAll('Exception: ', '');
          _errorMessages[i] = '🎬 영상 오류: $errStr';
          if (kDebugMode) debugPrint('[Video] 장면 ${i+1} 오류: $e');
          if (mounted) {
            setState(() {
              _statusMsg = '[2/2] 장면 ${i + 1} 영상 실패 ❌';
              _generatingVideoScene = -1;
              _videoSceneProgress = 0.0;
              _videoSceneProgressText = '';
            });
            // 오류 내용을 스낵바로도 표시
            _showSnack('❌ 장면 ${i+1} 영상 실패: ${errStr.length > 100 ? errStr.substring(0, 100) + '...' : errStr}');
          }
        }
      }

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generatingVideoScene = -1;  // 취소/완료 시 항상 초기화
          _videoSceneProgress = 0.0;
          _videoSceneProgressText = '';
          if (_isCancelled || _isVideoCancelled) {
            _statusMsg = '⏹ 취소됨. (이미지 $imgSuccess장, 영상 $videoSuccess/$videoTotal)';
          } else {
            _statusMsg = '✅ 완료! 이미지 $imgSuccess/${scenes.length}장, '
                '영상 $videoSuccess/$videoTotal클립';
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusMsg = _isCancelled
              ? '⏹ 취소됨. (이미지 $imgSuccess/${scenes.length}장)'
              : '✅ 이미지 생성 완료! (${scenes.length}장)';
        });
      }
    }

    widget.provider.updateProject(widget.project);
    widget.provider.addNotification(
      '🖼️ "${widget.project.title}" 미디어 생성 완료',
    );
  }

  /// 스타일 + 캐릭터 정보를 포함한 최종 프롬프트 생성
  String _buildPrompt(String basePrompt) {
    final parts = <String>[basePrompt];

    // 활성화된 캐릭터 설명 추가
    final activeChars = _characters.where((c) => c.isActive && c.description.isNotEmpty).toList();
    if (activeChars.isNotEmpty) {
      final charDesc = activeChars
          .map((c) => '${c.name}: ${c.description}')
          .join('; ');
      parts.add('Character reference - $charDesc');
    }

    // 이미지 스타일 suffix 추가
    if (_selectedStyle != ImageStyle.none) {
      parts.add(_selectedStyle.promptSuffix);
    }

    return parts.join('. ');
  }

  /// 단일 장면 이미지 생성 (Future.wait에서 사용)
  Future<bool> _generateOneImage(GeminiService geminiService, int i) async {
    final scene = widget.project.scenes[i];

    if (_selectedModel.isLocal) {
      try {
        final rawPrompt = scene.imagePrompt.isNotEmpty
            ? scene.imagePrompt
            : 'Beautiful scene: ${scene.scriptText.substring(0, scene.scriptText.length.clamp(0, 100))}';
        final bytes = await _generateWithLocalSd(
          prompt: _buildPrompt(rawPrompt),
        );
        scene.imageBytes = bytes;
        scene.isGenerated = true;
        scene.imagePath = 'local_${scene.id}.png';
        return true;
      } catch (e) {
        _errorScenes.add(i);
        _errorMessages[i] = e.toString().replaceAll('Exception: ', '');
        return false;
      }
    }

    try {
      final rawPrompt = scene.imagePrompt.isNotEmpty
          ? scene.imagePrompt
          : 'Cinematic scene illustration: ${scene.scriptText.substring(0, scene.scriptText.length.clamp(0, 150))}';
      final prompt = _buildPrompt(rawPrompt);

      Uint8List bytes;
      if (_selectedModel.isNanoBanana) {
        // ✅ Nano Banana 계열 전부 → generateContent 직접 호출
        bytes = await geminiService.generateImageWithFlash(
          prompt: prompt,
          aspectRatio: _selectedRatio.ratioValue,
          model: _selectedModel.geminiModelId ?? 'gemini-3.1-flash-image-preview',
          imageSize: _selectedResolution,
        );
      } else if (_selectedModel.isImagen) {
        // ✅ Imagen 계열 → predict 직접 호출
        bytes = await geminiService.generateImage(
          prompt: prompt,
          aspectRatio: _selectedRatio.ratioValue,
          model: _selectedModel.imagenModelId ?? 'imagen-4.0-generate-001',
        );
      } else {
        bytes = await geminiService.generateImage(
          prompt: prompt,
          aspectRatio: _selectedRatio.ratioValue,
          model: _selectedModel.imagenModelId ?? 'imagen-3.0-generate-002',
        );
      }

      scene.imageBytes = bytes;
      scene.isGenerated = true;
      scene.imagePath = 'generated_${scene.id}.jpg';
      return true;
    } catch (e) {
      _errorScenes.add(i);
      final errStr = e.toString().replaceAll('Exception: ', '');
      _errorMessages[i] = errStr;
      if (kDebugMode) debugPrint('[Image] 장면 ${i+1} 오류: $e');
      return false;
    }
  }

  /// 로컬 Stable Diffusion WebUI API 호출
  Future<Uint8List> _generateWithLocalSd({required String prompt}) async {
    const url = 'http://127.0.0.1:7860/sdapi/v1/txt2img';
    final body = {
      'prompt': prompt,
      'negative_prompt': 'blurry, low quality, watermark',
      'steps': 20,
      'width': _selectedRatio == ImageRatio.ratio9x16 ? 512 : 768,
      'height': _selectedRatio == ImageRatio.ratio9x16 ? 768 : 512,
      'cfg_scale': 7,
      'sampler_name': 'DPM++ 2M Karras',
    };
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(minutes: 5));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final b64 = data['images'][0] as String;
      return base64Decode(b64);
    }
    throw Exception('Stable Diffusion 오류 (${response.statusCode})');
  }

  Future<void> _generateSingleImage(int index) async {
    final apiKey = widget.provider.apiKeys.geminiApiKey;
    if (apiKey.isEmpty && !_selectedModel.isLocal) {
      _showSnack('설정에서 API 키를 입력해주세요.');
      return;
    }

    setState(() => _statusMsg = '장면 ${index + 1} 이미지 재생성 중...');

    final scene = widget.project.scenes[index];
    try {
      final rawPrompt = scene.imagePrompt.isNotEmpty
          ? scene.imagePrompt
          : 'Cinematic scene: ${scene.scriptText.substring(0, scene.scriptText.length.clamp(0, 150))}';
      final prompt = _buildPrompt(rawPrompt);

      Uint8List bytes;
      if (_selectedModel.isLocal) {
        bytes = await _generateWithLocalSd(prompt: prompt);
      } else if (_selectedModel.isNanoBanana) {
        // ✅ Nano Banana 계열 → generateContent 직접 호출
        bytes = await GeminiService(apiKey).generateImageWithFlash(
          prompt: prompt,
          aspectRatio: _selectedRatio.ratioValue,
          model: _selectedModel.geminiModelId ?? 'gemini-3.1-flash-image-preview',
          imageSize: _selectedResolution,
        );
      } else if (_selectedModel.isImagen) {
        // ✅ Imagen 계열 → predict 직접 호출
        bytes = await GeminiService(apiKey).generateImage(
          prompt: prompt,
          aspectRatio: _selectedRatio.ratioValue,
          model: _selectedModel.imagenModelId ?? 'imagen-4.0-generate-001',
        );
      } else {
        bytes = await GeminiService(apiKey).generateImage(
          prompt: prompt,
          aspectRatio: _selectedRatio.ratioValue,
          model: 'imagen-3.0-generate-002',
        );
      }

      scene.imageBytes = bytes;
      scene.isGenerated = true;
      scene.imagePath = 'generated_${scene.id}.jpg';
      _errorScenes.remove(index);
      _errorMessages.remove(index);
      setState(() => _statusMsg = '✅ 장면 ${index + 1} 이미지 생성 완료!');
      widget.provider.updateProject(widget.project);
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _statusMsg = '❌ 장면 ${index + 1} 실패: $errStr';
        if (!_errorScenes.contains(index)) _errorScenes.add(index);
        _errorMessages[index] = errStr;
      });
      _showSnack('이미지 생성 실패: $errStr');
    }
  }

  /// 단일 장면 영상 재생성
  Future<void> _regenerateSingleVideo(int index) async {
    if (_isVideoGenerating || _isGenerating) {
      _showSnack('다른 생성 작업이 진행 중입니다.');
      return;
    }
    final scene = widget.project.scenes[index];
    if (scene.imageBytes == null) {
      _showSnack('이미지가 없습니다. 먼저 이미지를 생성해주세요.');
      return;
    }

    final channel = widget.provider.channels
        .where((c) => c.id == widget.project.channelId).firstOrNull;
    final videoService = VideoGenerationService(
      falApiKey: widget.provider.apiKeys.falApiKey,
      openAiApiKey: widget.provider.apiKeys.openAiApiKey,
      a1111Url: channel?.videoSettings.localSdUrl ?? 'http://127.0.0.1:7860',
      comfyUrl: channel?.videoSettings.localComfyUrl ?? 'http://127.0.0.1:8188',
      wanUnetName: channel?.videoSettings.wanUnetName ?? 'Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors',
      wanClipName: channel?.videoSettings.wanClipName ?? 'umt5_xxl_fp8_e4m3fn_scaled.safetensors',
      wanVaeName: channel?.videoSettings.wanVaeName ?? 'Wan2.1_VAE.pth',
      wanClipVisionName: channel?.videoSettings.wanClipVisionName ?? 'clip_vision_h.safetensors',
    );

    setState(() {
      _isVideoGenerating = true;
      _isVideoCancelled = false;
      _generatingVideoScene = index;
      _videoSceneProgress = 0.0;
      _videoSceneProgressText = '시작 중...';
      _statusMsg = '장면 ${index + 1} 영상 재생성 중...';
    });

    try {
      final videoBytes = await videoService.generateVideo(
        model: _videoModel,
        imageBytes: scene.imageBytes!,
        prompt: scene.imagePrompt.isNotEmpty
            ? scene.imagePrompt
            : 'Smooth cinematic motion based on the scene',
        aspectRatio: _videoRatio,
        duration: _videoDuration,
        hd: _videoHd,
        onProgress: (status, progress) {
          if (mounted && !_isVideoCancelled) {
            setState(() {
              _videoSceneProgress = progress;
              _videoSceneProgressText = status;
              _statusMsg = '장면 ${index + 1} 영상 생성 중... $status (${(progress * 100).toInt()}%)';
            });
          }
        },
      );

      if (!_isVideoCancelled) {
        scene.videoBytes = videoBytes;
        // WEBP/MP4 자동 감지
        final isWebp = videoBytes.length > 4 &&
            videoBytes[0] == 0x52 && videoBytes[1] == 0x49 &&
            videoBytes[2] == 0x46 && videoBytes[3] == 0x46;
        scene.videoPath = 'aivideo_${scene.id}.${isWebp ? 'webp' : 'mp4'}';
        setState(() => _statusMsg = '✅ 장면 ${index + 1} 영상 재생성 완료!');
        widget.provider.updateProject(widget.project);
      }
    } catch (e) {
      if (!_isVideoCancelled) {
        final errStr = e.toString().replaceAll('Exception: ', '');
        setState(() => _statusMsg = '❌ 장면 ${index + 1} 영상 실패: $errStr');
        _showSnack('영상 생성 실패: $errStr');
      }
    } finally {
      setState(() {
        _isVideoGenerating = false;
        _generatingVideoScene = -1;
        _videoSceneProgress = 0.0;
        _videoSceneProgressText = '';
      });
    }
  }

  /// 영상 생성 취소 (전체 또는 단독)
  void _cancelVideoGeneration() {
    setState(() {
      _isCancelled = true;
      _isVideoCancelled = true;
      // 취소 즉시 생성 중 표시 해제 (타임아웃 전에 UI 업데이트)
      _generatingVideoScene = -1;
      _videoSceneProgress = 0.0;
      _videoSceneProgressText = '';
      _isVideoGenerating = false;
      _statusMsg = '⏹ 영상 생성이 취소되었습니다. (ComfyUI 작업은 백그라운드에서 중단됩니다)';
    });
    _showSnack('⏹ 영상 생성을 취소했습니다.');
  }

  /// 실패한 장면만 재시도
  Future<void> _retryFailedScenes() async {
    final failedIndices = List<int>.from(_errorScenes);
    setState(() {
      _isGenerating = true;
      _statusMsg = '실패한 ${failedIndices.length}개 장면 재시도 중...';
    });

    int successCount = 0;
    for (final idx in failedIndices) {
      if (!mounted) break;
      setState(() {
        _currentScene = idx + 1;
        _statusMsg = '장면 ${idx + 1} 재시도 중...';
      });
      final beforeError = _errorScenes.contains(idx);
      await _generateSingleImage(idx);
      if (beforeError && !_errorScenes.contains(idx)) successCount++;
    }

    setState(() {
      _isGenerating = false;
      _statusMsg = successCount == failedIndices.length
          ? '✅ 모든 실패 장면 재시도 완료! ($successCount개)'
          : '⚠️ $successCount/${failedIndices.length}개 재시도 성공';
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.notoSansKr()),
        backgroundColor: AppTheme.bgElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수 호출
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 왼쪽: 설정 패널
        Container(
          width: 300,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppTheme.border)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('🖼️ 이미지 설정'),
                const SizedBox(height: 12),
                _label('이미지 생성 모델'),
                const SizedBox(height: 6),
                _buildModelDropdown(),
                const SizedBox(height: 8),
                _buildModelGuide(),
                const SizedBox(height: 8),
                if (_selectedModel.isLocal) _buildLocalSdSettings(),
                _label('이미지 비율'),
                const SizedBox(height: 6),
                _buildRatioSelector(),
                const SizedBox(height: 16),
                _label('해상도'),
                const SizedBox(height: 6),
                _buildResolutionDropdown(),
                const SizedBox(height: 20),
                const Divider(),
                // ── 이미지 스타일 선택 ──
                _sectionTitle('🎨 이미지 스타일'),
                const SizedBox(height: 8),
                _buildStyleSelector(),
                const SizedBox(height: 20),
                const Divider(),
                // ── 캐릭터 참조 ──
                _sectionTitle('👤 캐릭터 참조'),
                const SizedBox(height: 4),
                Text(
                  '마스코트·졸라맨 등 캐릭터를 등록하면\n이미지 생성 프롬프트에 자동 반영됩니다.',
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.textSecondary, fontSize: 10, height: 1.5),
                ),
                const SizedBox(height: 8),
                _buildCharacterSection(),
                const SizedBox(height: 20),
                const Divider(),
                _sectionTitle('🎬 AI 영상 설정'),
                const SizedBox(height: 12),
                _buildAiVideoSection(),
                const SizedBox(height: 16),
                const Divider(),
                _sectionTitle('⚡ 병렬 생성 설정'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _label('동시 생성 수'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$_concurrency장 동시',
                          style: GoogleFonts.notoSansKr(
                              color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Slider(
                  value: _concurrency.toDouble(),
                  min: 1, max: 10, divisions: 9,
                  activeColor: AppTheme.primary,
                  inactiveColor: AppTheme.border,
                  onChanged: (v) => setState(() => _concurrency = v.toInt()),
                ),
                Text(
                  _concurrency <= 3
                      ? '✅ 안전 (무료 티어 권장: 1~3개)'
                      : _concurrency <= 6
                          ? '⚠️ 보통 (Rate Limit 주의)'
                          : '🚨 빠름 (유료 API 전용 권장)',
                  style: GoogleFonts.notoSansKr(
                      color: _concurrency <= 3 ? AppTheme.success
                          : _concurrency <= 6 ? AppTheme.warning : AppTheme.error,
                      fontSize: 10),
                ),
                const SizedBox(height: 20),
                // 생성 버튼 + 취소 버튼
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateAllImages,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                          _isGenerating ? '생성 중...' : '전체 이미지 생성',
                          style: GoogleFonts.notoSansKr(fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (_isGenerating) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => setState(() => _isCancelled = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        minimumSize: Size.zero,
                      ),
                      child: const Icon(Icons.stop_rounded, size: 18, color: Colors.white),
                    ),
                  ],
                ]),
                if (_isGenerating) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: AppTheme.border,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusMsg,
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
                if (!_isGenerating && _statusMsg.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _statusMsg,
                    style: GoogleFonts.notoSansKr(
                        color: _statusMsg.startsWith('❌') || _statusMsg.startsWith('⚠️')
                            ? AppTheme.error
                            : AppTheme.success,
                        fontSize: 12),
                  ),
                ],
                // 실패한 장면 요약 및 재시도
                if (!_isGenerating && _errorScenes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 14),
                          const SizedBox(width: 4),
                          Text('실패 장면: ${_errorScenes.length}개',
                              style: GoogleFonts.notoSansKr(
                                  color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 6),
                        if (_errorMessages.isNotEmpty)
                          Text(
                            _errorMessages.values.first,
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.textSecondary, fontSize: 10, height: 1.4),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isGenerating ? null : _retryFailedScenes,
                            icon: const Icon(Icons.refresh_rounded, size: 14),
                            label: Text('실패한 장면 재시도',
                                style: GoogleFonts.notoSansKr(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _buildCostEstimate(),
              ],
            ),
          ),
        ),
        // 오른쪽: 장면 목록
        Expanded(
          child: Column(
            children: [
              // 미디어 화면에서 대본 수정 안내 배너
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppTheme.textHint, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '이미지를 생성했더라도 대본 수정 후 장면 재분할 → 이미지 재생성이 가능합니다',
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.textHint, fontSize: 10),
                    ),
                    const Spacer(),
                    Consumer<AppProvider>(
                      builder: (ctx, prov, _) => TextButton.icon(
                        onPressed: () => prov.setNavIndex(3),
                        icon: const Icon(Icons.edit_note_rounded, size: 12),
                        label: Text('대본 화면',
                            style: GoogleFonts.notoSansKr(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: widget.project.scenes.isEmpty
                    ? _buildEmptyScenes()
                    : _buildSceneGrid(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModelDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButton<ImageModel>(
        value: _selectedModel,
        isExpanded: true,
        dropdownColor: AppTheme.bgElevated,
        underline: const SizedBox(),
        style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary, fontSize: 13),
        items: ImageModel.values.map((m) {
          return DropdownMenuItem(
            value: m,
            child: Row(
              children: [
                if (m.isFree)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('무료',
                        style: GoogleFonts.notoSansKr(
                            color: AppTheme.success, fontSize: 9)),
                  ),
                Text(m.displayName),
              ],
            ),
          );
        }).toList(),
        onChanged: (v) => setState(() => _selectedModel = v!),
      ),
    );
  }

  Widget _buildModelGuide() {
    // Gemini Free Tier 모델
    if (_selectedModel == ImageModel.geminiFlashImage) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 13),
              const SizedBox(width: 4),
              Text('Gemini Flash Image (무료)',
                  style: GoogleFonts.notoSansKr(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Text(
              '• Gemini API 키로 사용 가능\n'
              '• 설정 → API 키 → Gemini API Key 입력\n'
              '• https://aistudio.google.com/app/apikey\n'
              '• 일일 생성 한도 있음 (무료 티어)',
              style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 10, height: 1.5),
            ),
          ],
        ),
      );
    }

    // Imagen 3 (유료)
    if (_selectedModel == ImageModel.imagen3) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 13),
              const SizedBox(width: 4),
              Text('Imagen 3 (유료)',
                  style: GoogleFonts.notoSansKr(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Text(
              '• Gemini API 키 필요 (Google AI Studio)\n'
              '• 이미지 1장당 약 \$0.04~\$0.08 비용\n'
              '• 결제 수단 등록 필요\n'
              '• https://aistudio.google.com/app/apikey',
              style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 10, height: 1.5),
            ),
          ],
        ),
      );
    }

    // ✅ Nano Banana 계열 → 직접 Gemini API 호출 (외부 서버 불필요)
    if (_selectedModel.isNanoBanana) {
      final isFree = _selectedModel.isFree;
      final color = isFree ? AppTheme.success : AppTheme.primary;
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(isFree ? Icons.check_circle_outline_rounded : Icons.monetization_on_rounded,
                  color: color, size: 13),
              const SizedBox(width: 4),
              Text(isFree ? '✅ 직접 Gemini API 호출 (외부 서버 불필요)' : '💳 유료 모델 (Gemini API 직접 호출)',
                  style: GoogleFonts.notoSansKr(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Text(
              '• ${_selectedModel.description}\n'
              '• 설정에 입력한 Gemini API 키로 바로 사용\n'
              '• 모델 ID: ${_selectedModel.geminiModelId ?? "-"}',
              style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 10, height: 1.5),
            ),
            if (_selectedModel.requiresBilling) ...[
              const SizedBox(height: 4),
              Text(
                '⚠️ 유료 모델: aistudio.google.com에서 결제 활성화 필요',
                style: GoogleFonts.notoSansKr(color: AppTheme.warning, fontSize: 10),
              ),
            ],
          ],
        ),
      );
    }

    // ✅ Imagen 4 계열 안내
    if (_selectedModel == ImageModel.imagen4 || _selectedModel == ImageModel.imagen4Ultra) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.monetization_on_rounded, color: AppTheme.primary, size: 13),
              const SizedBox(width: 4),
              Text('${_selectedModel.displayName} (유료)',
                  style: GoogleFonts.notoSansKr(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Text(
              '• ${_selectedModel.description}\n'
              '• Gemini API 키 필요 + 결제 활성화 필요\n'
              '• https://aistudio.google.com/apikey',
              style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 10, height: 1.5),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildLocalSdSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('로컬 Stable Diffusion 설정',
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.success,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                '• Automatic1111 WebUI 실행 중이어야 합니다\n'
                '• 기본 주소: http://127.0.0.1:7860\n'
                '• 완전 무료로 로컬에서 이미지 생성',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textSecondary, fontSize: 11, height: 1.5),
              ),
            ],
          ),
        ),
        _label('WebUI 주소'),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(
              text: 'http://127.0.0.1:7860'),
          style: GoogleFonts.notoSansKr(fontSize: 12),
          decoration: const InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRatioSelector() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: ImageRatio.values.map((r) {
        final selected = _selectedRatio == r;
        return GestureDetector(
          onTap: () => setState(() => _selectedRatio = r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.2)
                  : AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.border),
            ),
            child: Text(r.displayName,
                style: GoogleFonts.notoSansKr(
                    color: selected ? AppTheme.primaryLight : AppTheme.textSecondary,
                    fontSize: 11)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResolutionDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButton<ImageResolution>(
        value: _selectedRes,
        isExpanded: true,
        dropdownColor: AppTheme.bgElevated,
        underline: const SizedBox(),
        style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary, fontSize: 13),
        items: ImageResolution.values
            .map((r) =>
                DropdownMenuItem(value: r, child: Text(r.displayName)))
            .toList(),
        onChanged: (v) => setState(() => _selectedRes = v!),
      ),
    );
  }

  Widget _buildAiVideoSceneSlider() {
    final total = widget.project.scenes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0장면',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textHint, fontSize: 11)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'AI 영상: $_aiVideoSceneCount장면 / 이미지: ${total - _aiVideoSceneCount}장면',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
            Text('$total장면',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textHint, fontSize: 11)),
          ],
        ),
        Slider(
          value: _aiVideoSceneCount.toDouble(),
          min: 0,
          max: total.toDouble().clamp(0, 50),
          divisions: total > 0 ? total : 1,
          activeColor: AppTheme.accent,
          inactiveColor: AppTheme.border,
          onChanged: (v) => setState(() => _aiVideoSceneCount = v.toInt()),
        ),
        Text(
          '처음 $_aiVideoSceneCount개 장면: AI 영상 생성 (고품질)\n나머지 ${total - _aiVideoSceneCount}개 장면: 이미지 슬라이드 (빠름)',
          style: GoogleFonts.notoSansKr(
              color: AppTheme.textHint, fontSize: 11, height: 1.5),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // AI 영상 설정 통합 섹션
  // ─────────────────────────────────────────────────
  Widget _buildAiVideoSection() {
    final total = widget.project.scenes.length;
    final supportedRatios = _videoModel.supportedRatios;
    final supportedDurations = _videoModel.supportedDurations;
    final needsFal = _videoModel.isFalAi && widget.provider.apiKeys.falApiKey.isEmpty;
    final needsOpenAi = _videoModel.isOpenAi && widget.provider.apiKeys.openAiApiKey.isEmpty;
    final isLocal = _videoModel.isLocal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // API 키 경고
        if (needsFal) ...[
          _apiWarningBanner(
            _videoModel == VideoModel.veo3 ||
            _videoModel == VideoModel.veo3Fast ||
            _videoModel == VideoModel.veo31 ||
            _videoModel == VideoModel.veo31Fast
              ? 'Veo는 구글이 개발한 모델이지만, 이 앱에서는 fal.ai API를 통해 사용합니다.\n'
                'Gemini API 키와는 별개입니다. 설정 → API 키 → fal.ai API Key를 입력해주세요.\n'
                '📌 fal.ai 키 발급: https://fal.ai/dashboard/keys'
              : 'fal.ai API 키가 필요합니다. 설정 → API 키 → fal.ai API Key를 입력해주세요.\n'
                '📌 fal.ai 키 발급: https://fal.ai/dashboard/keys',
          ),
        ],
        if (needsOpenAi)
          _apiWarningBanner('OpenAI API 키가 필요합니다. 설정 → API 키 → OpenAI API Key를 입력해주세요.'),
        if (isLocal)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.computer_rounded, color: AppTheme.success, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🖥️ 로컬 무료 모델 · API 키 불필요\n'
                    '${_videoModel.vramRequirement} · '
                    '${_videoModel.backend == VideoBackend.a1111 ? "Automatic1111 WebUI" : "ComfyUI"} 실행 필요',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.success, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

        // ── 장면 수 슬라이더 ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _label('AI 영상 장면 수 (앞부터)'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _aiVideoSceneCount == 0
                    ? '영상 없음 (이미지만)'
                    : '$_aiVideoSceneCount장면 영상 / ${total - _aiVideoSceneCount}장면 이미지',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        Slider(
          value: _aiVideoSceneCount.toDouble(),
          min: 0,
          max: total.toDouble().clamp(0, 50),
          divisions: total > 0 ? total : 1,
          activeColor: AppTheme.accent,
          inactiveColor: AppTheme.border,
          onChanged: (v) => setState(() => _aiVideoSceneCount = v.toInt()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0 (이미지만)', style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 10)),
            Text('$total장면 전부', style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 10)),
          ],
        ),

        if (_aiVideoSceneCount > 0) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // ── 영상 모델 선택 ──
          _label('영상 생성 모델'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppTheme.bgDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<VideoModel>(
                value: _videoModel,
                isExpanded: true,
                dropdownColor: AppTheme.bgElevated,
                style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary, fontSize: 12),
                items: VideoModel.values.map((m) {
                  return DropdownMenuItem<VideoModel>(
                    value: m,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(m.displayName, style: GoogleFonts.notoSansKr(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                        Text(m.description, style: GoogleFonts.notoSansKr(
                            fontSize: 10, color: AppTheme.textHint)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _videoModel = v;
                    // 선택 모델이 지원하지 않는 비율/길이이면 첫 번째로 리셋
                    if (!v.supportedRatios.contains(_videoRatio)) {
                      _videoRatio = v.supportedRatios.first;
                    }
                    if (!v.supportedDurations.contains(_videoDuration)) {
                      _videoDuration = v.supportedDurations.first;
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── 영상 비율 선택 ──
          _label('영상 비율'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: supportedRatios.map((r) {
              final selected = _videoRatio == r;
              return GestureDetector(
                onTap: () => setState(() => _videoRatio = r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppTheme.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    r == '9:16' ? '9:16 세로' : r == '16:9' ? '16:9 가로' : r,
                    style: GoogleFonts.notoSansKr(
                        color: selected ? AppTheme.primary : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // ── 영상 길이 선택 ──
          _label('영상 길이'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: supportedDurations.map((d) {
              final selected = _videoDuration == d;
              return GestureDetector(
                onTap: () => setState(() => _videoDuration = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.accent.withValues(alpha: 0.15)
                        : AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppTheme.accent : AppTheme.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    '${d}초',
                    style: GoogleFonts.notoSansKr(
                        color: selected ? AppTheme.accent : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // ── HD 토글 ──
          Row(
            children: [
              Switch(
                value: _videoHd,
                onChanged: (v) => setState(() => _videoHd = v),
                activeColor: AppTheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HD 품질 (1080p)',
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  Text('비용 약 2배 · Sora 2 Pro에서 가장 효과적',
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.textHint, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── 예상 비용 박스 ──
          _buildVideoCostEstimate(),
        ],
      ],
    );
  }

  Widget _buildVideoCostEstimate() {
    final imgCount = widget.project.scenes.length;
    final vidCount = _aiVideoSceneCount;
    final imgCost = imgCount * 0.01;
    final vidCost = vidCount * _videoModel.costPerClip * (_videoHd ? 2.0 : 1.0);
    final total = imgCost + vidCost;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.attach_money_rounded, color: AppTheme.warning, size: 14),
            const SizedBox(width: 4),
            Text('예상 비용',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          _costRow('이미지 생성 ($imgCount장)', '\$${imgCost.toStringAsFixed(2)}'),
          _costRow(
            '${_videoModel.displayName} 영상 ($vidCount클립${_videoHd ? ", HD" : ""})',
            '\$${vidCost.toStringAsFixed(2)}',
          ),
          const Divider(height: 12),
          _costRow('총 예상 비용', '\$${total.toStringAsFixed(2)}', bold: true),
          const SizedBox(height: 6),
          Text('※ 클립당 ${_videoDuration}초, 실제 비용은 모델/옵션에 따라 다를 수 있습니다.',
              style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 9)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 이미지 스타일 선택 UI
  // ─────────────────────────────────────────────────
  Widget _buildStyleSelector() {
    // 카테고리별 그룹핑
    final categories = <String, List<ImageStyle>>{};
    for (final s in ImageStyle.values) {
      categories.putIfAbsent(s.category, () => []).add(s);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 현재 선택된 스타일 표시
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _selectedStyle == ImageStyle.none
                ? AppTheme.bgSurface
                : AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _selectedStyle == ImageStyle.none
                  ? AppTheme.border
                  : AppTheme.primary.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Text(_selectedStyle.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedStyle == ImageStyle.none
                      ? '스타일 선택 안함'
                      : _selectedStyle.displayName,
                  style: GoogleFonts.notoSansKr(
                    color: _selectedStyle == ImageStyle.none
                        ? AppTheme.textSecondary
                        : AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_selectedStyle != ImageStyle.none)
                GestureDetector(
                  onTap: () {
                    setState(() => _selectedStyle = ImageStyle.none);
                    _saveSettingsToChannel();
                  },
                  child: const Icon(Icons.close, size: 14, color: AppTheme.textHint),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 카테고리별 스타일 그리드
        ...categories.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  entry.key,
                  style: GoogleFonts.notoSansKr(
                    color: AppTheme.textHint,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: entry.value.map((style) {
                  final isSelected = _selectedStyle == style;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedStyle = style);
                      _saveSettingsToChannel();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.15)
                            : AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(style.emoji, style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                          Text(
                            style.displayName,
                            style: GoogleFonts.notoSansKr(
                              color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 4),
            ],
          );
        }),
        if (_selectedStyle != ImageStyle.none) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              '💡 프롬프트 반영: ${_selectedStyle.promptSuffix.length > 80 ? '${_selectedStyle.promptSuffix.substring(0, 80)}...' : _selectedStyle.promptSuffix}',
              style: GoogleFonts.notoSansKr(
                color: AppTheme.textHint, fontSize: 9, height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // 캐릭터 참조 관리 UI
  // ─────────────────────────────────────────────────
  Widget _buildCharacterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 캐릭터 목록
        ..._characters.asMap().entries.map((entry) {
          final idx = entry.key;
          final char = entry.value;
          return _buildCharacterCard(char, idx);
        }),
        // 캐릭터 추가 버튼
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _showAddCharacterDialog,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline_rounded,
                    size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text('캐릭터 추가',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.primary, fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterCard(CharacterReference char, int idx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: char.isActive
            ? AppTheme.primary.withValues(alpha: 0.04)
            : AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: char.isActive ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // 참조 이미지 미리보기
                GestureDetector(
                  onTap: () => _pickCharacterImage(idx),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: char.imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.memory(
                              Uint8List.fromList(char.imageBytes!),
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined,
                            size: 20, color: AppTheme.textHint),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        char.name,
                        style: GoogleFonts.notoSansKr(
                          color: AppTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (char.description.isNotEmpty)
                        Text(
                          char.description,
                          style: GoogleFonts.notoSansKr(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // 활성화 토글
                Switch(
                  value: char.isActive,
                  onChanged: (v) {
                    setState(() => char.isActive = v);
                    _saveSettingsToChannel();
                  },
                  activeColor: AppTheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          // 편집/삭제 버튼
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showEditCharacterDialog(idx),
                    icon: const Icon(Icons.edit_outlined, size: 12),
                    label: Text('편집',
                        style: GoogleFonts.notoSansKr(fontSize: 10)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ),
                Container(width: 1, height: 24, color: AppTheme.border),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _characters.removeAt(idx));
                      _saveSettingsToChannel();
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 12),
                    label: Text('삭제',
                        style: GoogleFonts.notoSansKr(fontSize: 10)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCharacterImage(int idx) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.first.bytes != null) {
        setState(() {
          _characters[idx].imageBytes = result.files.first.bytes!.toList();
          _characters[idx].imagePath = result.files.first.name;
        });
        _saveSettingsToChannel();
      }
    } catch (e) {
      _showSnack('이미지 선택 실패: $e');
    }
  }

  void _showAddCharacterDialog() {
    _showCharacterDialog(null, -1);
  }

  void _showEditCharacterDialog(int idx) {
    _showCharacterDialog(_characters[idx], idx);
  }

  void _showCharacterDialog(CharacterReference? existing, int idx) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    List<int>? imageBytes = existing?.imageBytes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: Text(
            idx == -1 ? '캐릭터 추가' : '캐릭터 편집',
            style: GoogleFonts.notoSansKr(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이미지 업로드
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        withData: true,
                      );
                      if (result != null && result.files.first.bytes != null) {
                        setDialogState(() {
                          imageBytes = result.files.first.bytes!.toList();
                        });
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.memory(
                                Uint8List.fromList(imageBytes!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_photo_alternate_outlined,
                                    size: 24, color: AppTheme.textHint),
                                const SizedBox(height: 4),
                                Text('이미지 업로드',
                                    style: GoogleFonts.notoSansKr(
                                        color: AppTheme.textHint, fontSize: 9)),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('캐릭터 이름',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 4),
                TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '예: 경제 마스코트, 졸라맨 주인공',
                    hintStyle: GoogleFonts.notoSansKr(
                        color: AppTheme.textHint, fontSize: 11),
                    filled: true,
                    fillColor: AppTheme.bgSurface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text('캐릭터 설명 (외모·특징 → 프롬프트에 자동 삽입)',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 4),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.textPrimary, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: '예: A cute stick figure man with round head, wearing a blue tie, simple line drawing, friendly expression',
                    hintStyle: GoogleFonts.notoSansKr(
                        color: AppTheme.textHint, fontSize: 10),
                    filled: true,
                    fillColor: AppTheme.bgSurface,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '💡 설명은 영문으로 작성하면 이미지 생성 품질이 더 높습니다.\n'
                    '예시: "cute stick figure, round head, blue shirt, simple lines"',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.textHint, fontSize: 9, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('취소',
                  style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  if (idx == -1) {
                    _characters.add(CharacterReference(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      imageBytes: imageBytes,
                    ));
                  } else {
                    _characters[idx].name = nameCtrl.text.trim();
                    _characters[idx].description = descCtrl.text.trim();
                    _characters[idx].imageBytes = imageBytes;
                  }
                });
                _saveSettingsToChannel();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: Text(idx == -1 ? '추가' : '저장',
                  style: GoogleFonts.notoSansKr(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostEstimate() {
    final imageCount = widget.project.scenes.length - _aiVideoSceneCount;
    final videoCount = _aiVideoSceneCount;
    final imageCost = imageCount * 0.01;
    final videoCost = videoCount * 0.10;
    final total = imageCost + videoCost;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.attach_money_rounded,
                color: AppTheme.warning, size: 14),
            const SizedBox(width: 4),
            Text('예상 비용',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          _costRow('이미지 생성 ($imageCount장)', '\$${imageCost.toStringAsFixed(2)}'),
          _costRow('AI 영상 생성 ($videoCount장)', '\$${videoCost.toStringAsFixed(2)}'),
          const Divider(height: 12),
          _costRow('총 예상 비용', '\$${total.toStringAsFixed(2)}',
              bold: true),
        ],
      ),
    );
  }

  Widget _costRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textSecondary,
                  fontSize: 11)),
          Text(value,
              style: GoogleFonts.notoSansKr(
                  color: bold ? AppTheme.warning : AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildEmptyScenes() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 56, color: AppTheme.textHint),
          const SizedBox(height: 14),
          Text('장면이 없습니다',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 8),
          Text('대본 작성 화면에서 장면을 분할해주세요',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textHint, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSceneGrid() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.project.scenes.length,
      itemBuilder: (context, i) {
        final scene = widget.project.scenes[i];
        final isAiVideo = i < _aiVideoSceneCount;
        return _SceneCard(
          scene: scene,
          index: i,
          isAiVideo: isAiVideo,
          isGeneratingVideo: _generatingVideoScene == i,
          videoProgress: _generatingVideoScene == i ? _videoSceneProgress : 0.0,
          videoProgressText: _generatingVideoScene == i ? _videoSceneProgressText : null,
          errorMessage: _errorMessages[i],
          hasError: _errorScenes.contains(i),
          onRegenerate: () => _generateSingleImage(i),
          onPromptEdit: (newPrompt) {
            scene.imagePrompt = newPrompt;
            widget.provider.updateProject(widget.project);
          },
          onCancelVideo: (_generatingVideoScene == i)
              ? _cancelVideoGeneration
              : null,
          onRegenerateVideo: (isAiVideo && !_isGenerating && !_isVideoGenerating && scene.imageBytes != null)
              ? () => _regenerateSingleVideo(i)
              : null,
        );
      },
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.notoSansKr(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold));

  Widget _label(String t) => Text(t,
      style: GoogleFonts.notoSansKr(
          color: AppTheme.textSecondary, fontSize: 12));

  Widget _apiWarningBanner(String msg) => Container(
    padding: const EdgeInsets.all(10),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: AppTheme.warning.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg,
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.warning, fontSize: 11, height: 1.4)),
        ),
      ],
    ),
  );
}

// 장면 카드 위젯
class _SceneCard extends StatefulWidget {
  final SceneModel scene;
  final int index;
  final bool isAiVideo;
  final bool hasError;
  final bool isGeneratingVideo;
  final double videoProgress;
  final String? videoProgressText;
  final String? errorMessage;
  final VoidCallback onRegenerate;
  final ValueChanged<String> onPromptEdit;
  // ── 영상 관련 콜백 ──
  final VoidCallback? onCancelVideo;       // 영상 생성 취소
  final VoidCallback? onRegenerateVideo;  // 영상 재생성

  const _SceneCard({
    required this.scene,
    required this.index,
    required this.isAiVideo,
    this.hasError = false,
    this.isGeneratingVideo = false,
    this.videoProgress = 0.0,
    this.videoProgressText,
    this.errorMessage,
    required this.onRegenerate,
    required this.onPromptEdit,
    this.onCancelVideo,
    this.onRegenerateVideo,
  });

  @override
  State<_SceneCard> createState() => _SceneCardState();
}

class _SceneCardState extends State<_SceneCard> {
  bool _editingPrompt = false;
  late TextEditingController _promptCtrl;

  @override
  void initState() {
    super.initState();
    _promptCtrl = TextEditingController(text: widget.scene.imagePrompt);
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  void _saveVideo(BuildContext context) async {
    final bytes = widget.scene.videoBytes;
    if (bytes == null) return;
    try {
      // WEBP/MP4 자동 감지
      final isWebp = bytes.length > 4 &&
          bytes[0] == 0x52 && bytes[1] == 0x49 &&
          bytes[2] == 0x46 && bytes[3] == 0x46; // RIFF 헤더 = WEBP
      final ext = isWebp ? 'webp' : 'mp4';
      final fileName = 'scene_${widget.index + 1}_video.$ext';
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '영상 저장',
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
      );
      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('영상이 저장됐어요: $result'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  // 영상 임시 저장 후 기본 플레이어로 재생
  Future<void> _playVideo(BuildContext context) async {
    final bytes = widget.scene.videoBytes;
    if (bytes == null) return;
    try {
      final tmpDir = await getTemporaryDirectory();
      // WEBP/MP4 자동 감지 (RIFF 헤더 = WEBP 애니메이션)
      final isWebp = bytes.length > 4 &&
          bytes[0] == 0x52 && bytes[1] == 0x49 &&
          bytes[2] == 0x46 && bytes[3] == 0x46;
      final ext = isWebp ? 'webp' : 'mp4';
      final file = File('${tmpDir.path}/scene_${widget.index + 1}_preview.$ext');
      await file.writeAsBytes(bytes);
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // 파일 탐색기에서 열기 (폴더 경로)
        final folderUri = Uri.file(tmpDir.path);
        await launchUrl(folderUri, mode: LaunchMode.externalApplication);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('영상 위치: ${file.path}'),
              backgroundColor: AppTheme.accent,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('재생 실패: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showImagePreview(BuildContext context, Uint8List bytes) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
            Positioned(
              bottom: 8, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '장면 ${widget.index + 1}',
                    style: GoogleFonts.notoSansKr(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.hasError
              ? AppTheme.error.withValues(alpha: 0.5)
              : widget.scene.isGenerated
                  ? AppTheme.success.withValues(alpha: 0.4)
                  : AppTheme.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.isAiVideo
                        ? AppTheme.accent.withValues(alpha: 0.2)
                        : AppTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('${widget.index + 1}',
                        style: GoogleFonts.notoSansKr(
                            color: widget.isAiVideo
                                ? AppTheme.accent
                                : AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.isAiVideo
                        ? AppTheme.accent.withValues(alpha: 0.15)
                        : AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.isAiVideo ? '🎬 AI 영상' : '🖼️ 이미지',
                    style: GoogleFonts.notoSansKr(
                        color: widget.isAiVideo
                            ? AppTheme.accent
                            : AppTheme.primaryLight,
                        fontSize: 10),
                  ),
                ),
                const Spacer(),
                if (widget.hasError)
                  const Icon(Icons.error_rounded, color: AppTheme.error, size: 18)
                else if (widget.scene.isGenerated)
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.success, size: 18),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  color: AppTheme.textSecondary,
                  tooltip: '이 장면만 재생성',
                  onPressed: widget.onRegenerate,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 오류 메시지 표시
            if (widget.hasError && widget.errorMessage != null) ...[  
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppTheme.error, size: 13),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        widget.errorMessage!,
                        style: GoogleFonts.notoSansKr(
                            color: AppTheme.error, fontSize: 10, height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // 영상 생성 중 표시
            if (widget.isGeneratingVideo) ...[  // ← 취소 버튼 포함
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('🎬 AI 영상 생성 중...',
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.accent, fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 진행률 바
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.videoProgress > 0 ? widget.videoProgress : null,
                        backgroundColor: AppTheme.border,
                        color: AppTheme.accent,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.videoProgress > 0
                          ? '${(widget.videoProgress * 100).toInt()}% - ${widget.videoProgressText ?? '처리 중...'}'
                          : (widget.videoProgressText ?? '대기 중... (5~15분 소요)'),
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.textSecondary, fontSize: 10),
                    ),
                    // ── 취소 버튼 ──
                    if (widget.onCancelVideo != null) ...[  
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: widget.onCancelVideo,
                          icon: const Icon(Icons.stop_circle_rounded,
                              size: 14, color: Colors.red),
                          label: Text('영상 생성 취소',
                              style: GoogleFonts.notoSansKr(
                                  fontSize: 11, color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ] else if (widget.scene.videoBytes != null) ...[
              // 영상 생성 완료 - 재생 및 저장 버튼 표시
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_rounded, color: AppTheme.accent, size: 22),
                        const SizedBox(width: 6),
                        Text('🎬 AI 영상 생성 완료!',
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.accent, fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 영상 크기 표시
                    Text(
                      '크기: ${(widget.scene.videoBytes!.length / 1024 / 1024).toStringAsFixed(1)} MB',
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.textSecondary, fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 재생 버튼
                        ElevatedButton.icon(
                          onPressed: () => _playVideo(context),
                          icon: const Icon(Icons.play_circle_filled_rounded, size: 14),
                          label: Text('재생',
                              style: GoogleFonts.notoSansKr(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 재생성 버튼
                        if (widget.onRegenerateVideo != null)
                          ElevatedButton.icon(
                            onPressed: widget.onRegenerateVideo,
                            icon: const Icon(Icons.refresh_rounded, size: 14),
                            label: Text('재생성',
                                style: GoogleFonts.notoSansKr(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                            ),
                          ),
                        const SizedBox(width: 6),
                        // 저장 버튼
                        ElevatedButton.icon(
                          onPressed: () => _saveVideo(context),
                          icon: const Icon(Icons.download_rounded, size: 14),
                          label: Text('저장',
                              style: GoogleFonts.notoSansKr(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ] else if (widget.scene.imageBytes != null) ...[
              GestureDetector(
                onTap: () => _showImagePreview(context, widget.scene.imageBytes!),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        widget.scene.imageBytes!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 6, bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.zoom_in_rounded, color: Colors.white, size: 12),
                          SizedBox(width: 3),
                          Text('확대', style: TextStyle(color: Colors.white, fontSize: 10)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ] else if (widget.scene.isGenerated) ...[
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          color: AppTheme.success, size: 22),
                      const SizedBox(height: 4),
                      Text('생성 완료',
                          style: GoogleFonts.notoSansKr(
                              color: AppTheme.success, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // 대본 텍스트
            Text(
              widget.scene.scriptText,
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textPrimary, fontSize: 12, height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            // 이미지 프롬프트
            GestureDetector(
              onTap: () => setState(() => _editingPrompt = !_editingPrompt),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bgDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _editingPrompt
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextField(
                            controller: _promptCtrl,
                            style: GoogleFonts.notoSansKr(
                                fontSize: 11,
                                color: AppTheme.textSecondary),
                            maxLines: 3,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () {
                              widget.onPromptEdit(_promptCtrl.text);
                              setState(() => _editingPrompt = false);
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                            ),
                            child: Text('저장',
                                style: GoogleFonts.notoSansKr(
                                    color: AppTheme.primary,
                                    fontSize: 11)),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.scene.imagePrompt.isEmpty
                                  ? '이미지 프롬프트 없음 (탭하여 추가)'
                                  : widget.scene.imagePrompt,
                              style: GoogleFonts.notoSansKr(
                                  color: widget.scene.imagePrompt.isEmpty
                                      ? AppTheme.textHint
                                      : AppTheme.textSecondary,
                                  fontSize: 11,
                                  height: 1.4),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_rounded,
                              size: 12, color: AppTheme.textHint),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────
// 탭 2: TTS 음성 생성
// ───────────────────────────────────────
class _TtsTab extends StatefulWidget {
  final ProjectModel project;
  final AppProvider provider;
  const _TtsTab({required this.project, required this.provider});

  @override
  State<_TtsTab> createState() => _TtsTabState();
}

class _TtsTabState extends State<_TtsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 탭 전환 시에도 State 유지 (TTS 생성 중단 방지)
  TtsEngine _engine = TtsEngine.gemini;
  double _speed = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;
  bool _isGenerating = false;
  bool _isCancelled = false;
  bool _isSampling = false;      // 샘플 재생 중
  bool _scriptModified = false;  // 대본 수정 감지
  String _statusMsg = '';
  String _selectedGeminiVoice = 'Kore';
  String _elevenLabsVoiceId = '';
  String _clovaVoiceId = 'nara';

  // ── 샘플 캐시: "voiceId_lang" → WAV bytes ──
  // 같은 목소리를 반복 미리 듣기 할 때 동일한 오디오를 재사용
  final Map<String, Uint8List> _sampleCache = {};

  // 필터 상태
  String _geminiFilterGender = '전체';  // 전체, 여성, 남성
  String _geminiFilterLang = '전체';    // 전체, 한국어, 영어, 일본어, 다국어
  String _clovaFilterGender = '전체';
  String _clovaFilterLang = '전체';     // 전체, 한국어, 영어, 일본어, 대만어, 스페인어

  // ── ElevenLabs 목소리 ──
  // 내장 대표 목소리 (API 키 없어도 표시, 공개 Voice ID)
  static const _elevenLabsBuiltinVoices = [
    {'id': '21m00Tcm4TlvDq8ikWAM', 'name': 'Rachel',   'gender': '여성', 'age': '성인', 'desc': '차분하고 명확한 영어 여성 - 기본값', 'lang': '영어'},
    {'id': 'AZnzlk1XvdvUeBnXmlld', 'name': 'Domi',     'gender': '여성', 'age': '청년', 'desc': '강하고 자신감 있는 여성', 'lang': '영어'},
    {'id': 'EXAVITQu4vr4xnSDxMaL', 'name': 'Bella',    'gender': '여성', 'age': '청년', 'desc': '부드럽고 감성적인 여성', 'lang': '영어'},
    {'id': 'ErXwobaYiN019PkySvjV', 'name': 'Antoni',   'gender': '남성', 'age': '성인', 'desc': '부드럽고 전문적인 남성', 'lang': '영어'},
    {'id': 'MF3mGyEYCl7XYWbV9V6O', 'name': 'Elli',     'gender': '여성', 'age': '청년', 'desc': '감정적이고 젊은 여성', 'lang': '영어'},
    {'id': 'TxGEqnHWrfWFTfGW9XjX', 'name': 'Josh',     'gender': '남성', 'age': '청년', 'desc': '딥하고 감성적인 남성', 'lang': '영어'},
    {'id': 'VR6AewLTigWG4xSOukaG', 'name': 'Arnold',   'gender': '남성', 'age': '성인', 'desc': '강하고 중후한 나레이터 남성', 'lang': '영어'},
    {'id': 'pNInz6obpgDQGcFmaJgB', 'name': 'Adam',     'gender': '남성', 'age': '성인', 'desc': '딥하고 내레이션에 적합한 남성', 'lang': '영어'},
    {'id': 'yoZ06aMxZJJ28mfd3POQ', 'name': 'Sam',      'gender': '남성', 'age': '청년', 'desc': '이성적이고 활기찬 남성', 'lang': '영어'},
    {'id': 'jBpfuIE2acCO8z3wKNLl', 'name': 'Gigi',     'gender': '여성', 'age': '청년', 'desc': '경쾌하고 발랄한 여성', 'lang': '영어'},
    {'id': 'onwK4e9ZLuTAKqWW03F9', 'name': 'Daniel',   'gender': '남성', 'age': '성인', 'desc': '영국 영어 · 뉴스 앵커 스타일', 'lang': '영어'},
    {'id': 'XB0fDUnXU5powFXDhCwa', 'name': 'Charlotte', 'gender': '여성', 'age': '성인', 'desc': '영국 영어 · 우아하고 세련된', 'lang': '영어'},
  ];

  // API에서 불러온 목소리 (내 계정의 커스텀 목소리 포함)
  List<Map<String, String>> _elevenLabsApiVoices = [];
  bool _elevenLabsVoicesLoading = false;
  bool _elevenLabsVoicesLoaded = false;
  String _elevenLabsFilterGender = '전체';  // 전체, 여성, 남성
  // 현재 재생 중인 샘플 Voice ID
  String _elevenLabsPlayingId = '';

  // ─── Gemini TTS 전체 30개 목소리 ───
  // {id: {gender, age, personality, langs, desc_ko}}
  static const _geminiVoices = [
    // ── 한국어 최적화 ──
    {'id':'Kore',         'gender':'여성', 'age':'성인', 'personality':'차분·명료',   'langs':['한국어','다국어'], 'desc':'한국어 특화 · 안정적이고 명료한 발음'},
    {'id':'Aoede',        'gender':'여성', 'age':'성인', 'personality':'부드러움',    'langs':['한국어','다국어'], 'desc':'자연스럽고 따뜻한 여성 목소리'},
    {'id':'Charon',       'gender':'남성', 'age':'중년', 'personality':'중후·안정',   'langs':['한국어','다국어'], 'desc':'깊고 중후한 남성 내레이터'},
    {'id':'Fenrir',       'gender':'남성', 'age':'성인', 'personality':'강인·또렷',   'langs':['한국어','다국어'], 'desc':'힘있고 확실한 전달력'},
    {'id':'Puck',         'gender':'남성', 'age':'청년', 'personality':'활기·경쾌',   'langs':['한국어','다국어'], 'desc':'밝고 친근한 젊은 남성'},
    {'id':'Algenib',      'gender':'남성', 'age':'성인', 'personality':'따뜻·친근',   'langs':['한국어','다국어'], 'desc':'편안하고 신뢰감 있는 목소리'},
    {'id':'Orus',         'gender':'남성', 'age':'성인', 'personality':'전문·명확',   'langs':['한국어','다국어'], 'desc':'전문적이고 명확한 남성 목소리'},
    // ── 영어권 강세 ──
    {'id':'Zephyr',       'gender':'여성', 'age':'성인', 'personality':'밝음·경쾌',   'langs':['영어','다국어'],  'desc':'미국 영어 · 밝고 자신감 있는'},
    {'id':'Autonoe',      'gender':'여성', 'age':'성인', 'personality':'차분·신뢰',   'langs':['영어','다국어'],  'desc':'미국 영어 · 전문적이고 신뢰성'},
    {'id':'Leda',         'gender':'여성', 'age':'청년', 'personality':'상냥·온화',   'langs':['영어','다국어'],  'desc':'밝고 친절한 젊은 여성'},
    {'id':'Sulafat',      'gender':'여성', 'age':'성인', 'personality':'따뜻·포용',   'langs':['영어','다국어'],  'desc':'따뜻하고 포용력 있는 어조'},
    {'id':'Despina',      'gender':'여성', 'age':'성인', 'personality':'우아·세련',   'langs':['영어','다국어'],  'desc':'우아하고 세련된 영어 발음'},
    {'id':'Erinome',      'gender':'여성', 'age':'청년', 'personality':'활발·열정',   'langs':['영어','다국어'],  'desc':'열정적이고 활발한 젊은 목소리'},
    {'id':'Algieba',      'gender':'여성', 'age':'성인', 'personality':'우아·감성',   'langs':['영어','다국어'],  'desc':'우아하고 감성적인 여성 목소리'},
    {'id':'Callirrhoe',   'gender':'여성', 'age':'청년', 'personality':'경쾌·발랄',   'langs':['영어','다국어'],  'desc':'경쾌하고 발랄한 젊은 여성'},
    {'id':'Gacrux',       'gender':'남성', 'age':'성인', 'personality':'깊음·무게감', 'langs':['영어','다국어'],  'desc':'묵직하고 권위 있는 남성'},
    {'id':'Achird',       'gender':'남성', 'age':'청년', 'personality':'캐주얼·유쾌', 'langs':['영어','다국어'],  'desc':'친근하고 유쾌한 청년 목소리'},
    {'id':'Iapetus',      'gender':'남성', 'age':'중년', 'personality':'차분·지적',   'langs':['영어','다국어'],  'desc':'지적이고 신중한 중년 남성'},
    {'id':'Rasalgethi',   'gender':'남성', 'age':'성인', 'personality':'안정·명확',   'langs':['영어','다국어'],  'desc':'안정적이고 명확한 전달력'},
    {'id':'Alnilam',      'gender':'남성', 'age':'성인', 'personality':'힘있음·웅장', 'langs':['영어','다국어'],  'desc':'웅장하고 힘 있는 남성 목소리'},
    // ── 다국어 범용 ──
    {'id':'Schedar',      'gender':'여성', 'age':'성인', 'personality':'차분·명확',   'langs':['영어','일본어','다국어'], 'desc':'다국어 지원 · 차분하고 명확'},
    {'id':'Vindemiatrix', 'gender':'여성', 'age':'성인', 'personality':'전문·신뢰',   'langs':['영어','스페인어','다국어'], 'desc':'전문적이고 신뢰감 있는 여성'},
    {'id':'Pulcherrima',  'gender':'여성', 'age':'성인', 'personality':'우아·고급',   'langs':['영어','다국어'],  'desc':'우아하고 고급스러운 발음'},
    {'id':'Umbriel',      'gender':'남성', 'age':'성인', 'personality':'깊음·서정',   'langs':['영어','다국어'],  'desc':'서정적이고 표현력 풍부'},
    {'id':'Zubenelgenubi','gender':'남성', 'age':'중년', 'personality':'진중·무게',   'langs':['영어','스페인어','다국어'], 'desc':'진중하고 설득력 있는'},
    {'id':'Enceladus',    'gender':'남성', 'age':'청년', 'personality':'생동감·명쾌', 'langs':['영어','다국어'],  'desc':'명쾌하고 에너지 넘치는 청년'},
    {'id':'Achernar',     'gender':'남성', 'age':'성인', 'personality':'강인·명료',   'langs':['영어','다국어'],  'desc':'강인하고 명료한 남성'},
    {'id':'Sadaltager',   'gender':'남성', 'age':'성인', 'personality':'차분·신중',   'langs':['영어','다국어'],  'desc':'차분하고 신중한 남성 목소리'},
    // ── 일본어 강세 ──
    {'id':'Laomedeia',    'gender':'여성', 'age':'청년', 'personality':'밝음·귀여움', 'langs':['일본어','영어','다국어'], 'desc':'일본어 특화 · 밝고 귀여운'},
    {'id':'Sadachbia',    'gender':'남성', 'age':'성인', 'personality':'명랑·활발',   'langs':['일본어','영어','다국어'], 'desc':'일본어 자연스러운 남성'},
  ];

  // ─── CLOVA Voice 전체 목소리 ───
  static const _clovaVoicesAll = [
    // ── 한국어 여성 ──
    {'id':'nara',      'name':'나라',   'gender':'여성', 'age':'성인', 'personality':'표준·안정',   'lang':'한국어', 'desc':'CLOVA 기본 여성 · 명확하고 안정적'},
    {'id':'nminseo',   'name':'민서',   'gender':'여성', 'age':'청년', 'personality':'밝음·활발',   'lang':'한국어', 'desc':'밝고 활발한 젊은 여성'},
    {'id':'ntiffany',  'name':'티파니', 'gender':'여성', 'age':'청년', 'personality':'활기·생동감', 'lang':'한국어', 'desc':'활기차고 에너지 넘치는'},
    {'id':'nsunhee',   'name':'선희',   'gender':'여성', 'age':'성인', 'personality':'차분·신뢰',   'lang':'한국어', 'desc':'차분하고 신뢰감 있는 여성'},
    {'id':'nbora',     'name':'보라',   'gender':'여성', 'age':'성인', 'personality':'부드러움',    'lang':'한국어', 'desc':'부드럽고 따뜻한 목소리'},
    {'id':'njiyun',    'name':'지윤',   'gender':'여성', 'age':'청년', 'personality':'발랄·귀여움', 'lang':'한국어', 'desc':'발랄하고 귀여운 젊은 여성'},
    {'id':'nyujin',    'name':'유진',   'gender':'여성', 'age':'성인', 'personality':'우아·세련',   'lang':'한국어', 'desc':'우아하고 세련된 여성'},
    {'id':'njena',     'name':'제나',   'gender':'여성', 'age':'성인', 'personality':'전문·명쾌',   'lang':'한국어', 'desc':'전문적이고 명쾌한 발음'},
    {'id':'nihyun',    'name':'이현',   'gender':'여성', 'age':'중년', 'personality':'포근·안정',   'lang':'한국어', 'desc':'포근하고 안정감 있는 중년'},
    {'id':'nkyunglee', 'name':'경리',   'gender':'여성', 'age':'중년', 'personality':'신뢰·전문',   'lang':'한국어', 'desc':'신뢰감 있는 전문가 톤'},
    {'id':'nara_call', 'name':'나라(전화)','gender':'여성','age':'성인','personality':'명확·통화',  'lang':'한국어', 'desc':'전화 상담 특화 · 명확한 발음'},
    {'id':'nsabina',   'name':'사비나', 'gender':'여성', 'age':'성인', 'personality':'감성·풍부',   'lang':'한국어', 'desc':'감성적이고 표현이 풍부한'},
    // ── 한국어 남성 ──
    {'id':'njinho',    'name':'진호',   'gender':'남성', 'age':'성인', 'personality':'표준·안정',   'lang':'한국어', 'desc':'CLOVA 기본 남성 · 표준적이고 안정적'},
    {'id':'nhajun',    'name':'하준',   'gender':'남성', 'age':'성인', 'personality':'따뜻·친근',   'lang':'한국어', 'desc':'따뜻하고 친근한 남성'},
    {'id':'ndonghyun', 'name':'동현',   'gender':'남성', 'age':'중년', 'personality':'중후·권위',   'lang':'한국어', 'desc':'중후하고 권위 있는 중년'},
    {'id':'nsiyoon',   'name':'시윤',   'gender':'남성', 'age':'청년', 'personality':'활기·청량',   'lang':'한국어', 'desc':'활기차고 청량한 젊은 남성'},
    {'id':'njoonyoung','name':'준영',   'gender':'남성', 'age':'청년', 'personality':'유쾌·캐주얼', 'lang':'한국어', 'desc':'유쾌하고 캐주얼한 청년'},
    {'id':'ntaejin',   'name':'태진',   'gender':'남성', 'age':'중년', 'personality':'진중·무게',   'lang':'한국어', 'desc':'진중하고 무게감 있는 중년'},
    {'id':'nseungpyo', 'name':'승표',   'gender':'남성', 'age':'성인', 'personality':'전문·냉철',   'lang':'한국어', 'desc':'전문적이고 냉철한 목소리'},
    {'id':'nwontak',   'name':'원탁',   'gender':'남성', 'age':'성인', 'personality':'힘차·열정',   'lang':'한국어', 'desc':'힘차고 열정적인 발음'},
    {'id':'njinho_call','name':'진호(전화)','gender':'남성','age':'성인','personality':'명확·통화',  'lang':'한국어', 'desc':'전화 상담 특화 남성'},
    {'id':'ndaeseong', 'name':'대성',   'gender':'남성', 'age':'중년', 'personality':'안정·신뢰',   'lang':'한국어', 'desc':'안정적이고 신뢰감 있는'},
    // ── 한국어 어린이 ──
    {'id':'na_ck',     'name':'어린이(여)','gender':'여성','age':'어린이','personality':'귀여움·발랄','lang':'한국어','desc':'귀엽고 발랄한 어린이 여성'},
    {'id':'nb_ck',     'name':'어린이(남)','gender':'남성','age':'어린이','personality':'귀여움·활발','lang':'한국어','desc':'귀엽고 활발한 어린이 남성'},
    // ── 영어 ──
    {'id':'vara',      'name':'Vara',   'gender':'여성', 'age':'성인', 'personality':'미국영어·전문','lang':'영어',  'desc':'미국 영어 · 전문적인 여성'},
    {'id':'danna',     'name':'Danna',  'gender':'여성', 'age':'청년', 'personality':'미국영어·밝음','lang':'영어',  'desc':'미국 영어 · 밝고 친근한'},
    {'id':'binu',      'name':'Binu',   'gender':'여성', 'age':'성인', 'personality':'영국영어·우아','lang':'영어',  'desc':'영국 영어 · 우아한 여성'},
    {'id':'matt',      'name':'Matt',   'gender':'남성', 'age':'성인', 'personality':'미국영어·중후','lang':'영어',  'desc':'미국 영어 · 중후한 남성'},
    {'id':'meimei',    'name':'MeiMei', 'gender':'여성', 'age':'청년', 'personality':'영어·귀여움',  'lang':'영어',  'desc':'미국 영어 · 귀엽고 활발'},
    {'id':'shinji',    'name':'Shinji', 'gender':'남성', 'age':'성인', 'personality':'영어·안정',    'lang':'영어',  'desc':'미국 영어 · 안정적인 남성'},
    // ── 일본어 ──
    {'id':'nshasha',   'name':'사샤',   'gender':'여성', 'age':'청년', 'personality':'일본어·밝음', 'lang':'일본어', 'desc':'일본어 · 밝고 자연스러운 여성'},
    {'id':'nnaomi',    'name':'나오미',  'gender':'여성', 'age':'성인', 'personality':'일본어·차분', 'lang':'일본어', 'desc':'일본어 · 차분하고 신뢰감'},
    {'id':'ntaro',     'name':'타로',   'gender':'남성', 'age':'성인', 'personality':'일본어·표준', 'lang':'일본어', 'desc':'일본어 · 표준적인 남성'},
    {'id':'nkarin',    'name':'카린',   'gender':'여성', 'age':'청년', 'personality':'일본어·귀여움','lang':'일본어', 'desc':'일본어 · 귀엽고 활발한'},
    // ── 대만어(중국어) ──
    {'id':'nmeiying',  'name':'메이잉', 'gender':'여성', 'age':'성인', 'personality':'대만어·부드',  'lang':'대만어', 'desc':'대만 중국어 · 부드럽고 명확'},
    {'id':'nkwangtai', 'name':'광타이', 'gender':'남성', 'age':'성인', 'personality':'대만어·안정',  'lang':'대만어', 'desc':'대만 중국어 · 안정적인 남성'},
    // ── 스페인어 ──
    {'id':'nmia',      'name':'Mia',    'gender':'여성', 'age':'성인', 'personality':'스페인어·발랄','lang':'스페인어','desc':'스페인어 · 발랄하고 명확'},
    {'id':'nhero',     'name':'Hero',   'gender':'남성', 'age':'성인', 'personality':'스페인어·중후','lang':'스페인어','desc':'스페인어 · 중후한 남성'},
  ];

  // ─── TTS 오디오 길이 계산 (바이트 → 초) ───
  double _calcTtsDuration(Uint8List bytes) {
    if (WebAudioHelper.isWav(bytes)) {
      final pcmLen = bytes.length > 44 ? bytes.length - 44 : bytes.length;
      return pcmLen / (24000 * 2); // 16bit mono 24kHz
    } else if (WebAudioHelper.isMp3(bytes)) {
      return bytes.length / 16000; // 128kbps 기준
    } else {
      return bytes.length / (24000 * 2); // raw PCM
    }
  }

  Future<void> _generateTts() async {
    if (widget.project.scenes.isEmpty) {
      _showSnack('장면이 없습니다. 먼저 장면을 분할해주세요.');
      return;
    }

    final apiKey = _getApiKey();
    if (apiKey.isEmpty) {
      _showSnack('설정에서 ${_engine.displayName} API 키를 입력해주세요.');
      return;
    }

    if (_engine == TtsEngine.local) {
      setState(() {
        _isGenerating = false;
        _statusMsg = '⚠️ 로컬 TTS는 아래 "오디오 파일 선택" 버튼을 사용해주세요.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _isCancelled = false;
      _statusMsg = 'TTS 병렬 생성 준비 중...';
    });

    final scenes = widget.project.scenes;
    final totalCount = scenes.length;

    try {
      // ── 병렬 TTS 생성 ──
      // 동시 요청 수 제한: Gemini 3개, ElevenLabs 2개, Clova 2개
      final maxConcurrent = _engine == TtsEngine.gemini ? 3 : 2;

      // 완료된 장면 수 추적 (UI 업데이트용)
      int completedCount = 0;

      // 결과 저장 (순서 보장)
      final resultBytes = List<Uint8List?>.filled(totalCount, null);

      // 세마포어 역할: 동시 실행 중인 Future 수 제한
      final semaphore = _Semaphore(maxConcurrent);

      setState(() => _statusMsg = '⚡ $totalCount개 장면 병렬 TTS 생성 중... (동시 $maxConcurrent개)');

      // 각 장면에 대한 Future 생성
      final futures = List.generate(totalCount, (i) async {
        if (_isCancelled) return;
        final scene = scenes[i];
        final text = scene.scriptText.trim();

        if (text.isEmpty) {
          scene.duration = 0.5;
          completedCount++;
          if (mounted) setState(() => _statusMsg = '⚡ [$completedCount/$totalCount] 장면 ${i + 1} 건너뜀 (빈 텍스트)');
          return;
        }

        await semaphore.acquire();
        try {
          if (_isCancelled) return;

          Uint8List sceneBytes;
          switch (_engine) {
            case TtsEngine.gemini:
              final chunks = TtsChunkProcessor.splitTextIntoChunks(text, chunkSize: 2000);
              final chunkBytes = <Uint8List>[];
              for (int c = 0; c < chunks.length; c++) {
                if (_isCancelled) break;
                final b = await GeminiService(apiKey).generateTts(
                  text: chunks[c],
                  voiceName: _selectedGeminiVoice,
                  speakingRate: _speed,
                );
                chunkBytes.add(b);
              }
              sceneBytes = TtsChunkProcessor.combineAudioBytes(chunkBytes);
              break;

            case TtsEngine.elevenlabs:
              final truncated = text.length > 5000 ? text.substring(0, 5000) : text;
              sceneBytes = await ElevenLabsService(apiKey).generateTts(
                text: truncated,
                voiceId: _elevenLabsVoiceId.isNotEmpty ? _elevenLabsVoiceId : '21m00Tcm4TlvDq8ikWAM',
                speed: _speed,
              );
              break;

            case TtsEngine.clova:
              final clovaKeys = widget.provider.apiKeys;
              sceneBytes = await ClovaTtsService(
                clientId: clovaKeys.clovaApiKey,
                clientSecret: clovaKeys.clovaApiSecret,
              ).generateTts(
                text: text,
                speaker: _clovaVoiceId,
                speed: (_speed * 2 - 2).round().clamp(-5, 5),
              );
              break;

            default:
              return;
          }

          // 결과 저장 (인덱스 순서 보장)
          resultBytes[i] = sceneBytes;
          scene.sceneTtsBytes = sceneBytes;
          scene.duration = _calcTtsDuration(sceneBytes).clamp(0.5, 300.0);

          completedCount++;
          if (mounted) {
            setState(() => _statusMsg =
                '⚡ [$completedCount/$totalCount] 장면 ${i + 1} 완료 (${scene.duration.toStringAsFixed(1)}초)');
          }
        } finally {
          semaphore.release();
        }
      });

      // 모든 Future 동시 실행 대기
      await Future.wait(futures);

      if (_isCancelled) {
        setState(() {
          _isGenerating = false;
          _statusMsg = '⏹ TTS 생성이 취소되었습니다.';
        });
        return;
      }

      // 전체 합본 오디오 생성 (재생/다운로드용) - 순서 보장된 결과 사용
      final validBytes = resultBytes.whereType<Uint8List>().toList();
      final combined = TtsChunkProcessor.combineAudioBytes(validBytes);
      widget.project.ttsAudioPath = '${widget.project.id}_tts.wav';
      widget.project.ttsAudioBytes = combined;
      widget.provider.updateProject(widget.project);
      widget.provider.addNotification('🎙️ "${widget.project.title}" TTS 음성 생성 완료 (병렬 생성)');

      final totalSecs = scenes.fold<double>(0.0, (s, e) => s + e.duration);
      final m = totalSecs ~/ 60;
      final s = (totalSecs % 60).toInt();
      setState(() {
        _isGenerating = false;
        _statusMsg = '✅ TTS 병렬 생성 완료! 총 ${m}분 ${s}초 | ${scenes.length}개 장면 | ${(combined.length / 1024).toStringAsFixed(0)}KB';
      });
      _showSnack('✅ TTS 완료! 총 ${m}분 ${s}초 (병렬 생성 완료)');
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _isGenerating = false;
        _statusMsg = '❌ TTS 실패: $errStr';
      });
      _showSnack('TTS 생성 실패: $errStr');
    }
  }

  // Gemini 음성 샘플 미리듣기 (voiceName, lang 매개변수 추가)
  Future<void> _previewVoice(String voiceName, {String lang = '한국어'}) async {
    final apiKey = widget.provider.apiKeys.geminiApiKey;
    if (apiKey.isEmpty) {
      _showSnack('Gemini API 키를 먼저 설정해주세요.');
      return;
    }

    // ── 캐시 히트: 동일 목소리+언어는 저장된 오디오를 재사용 ──
    final cacheKey = '${voiceName}_$lang';
    if (_sampleCache.containsKey(cacheKey)) {
      setState(() => _isSampling = true);
      try {
        await WebAudioHelper.playAutoAsync(_sampleCache[cacheKey]!, sampleRate: 24000);
        _showSnack('🔊 $voiceName 샘플 재생 중...');
        Future.delayed(const Duration(seconds: 6), () {
          if (mounted && _isSampling) setState(() => _isSampling = false);
        });
      } catch (e) {
        _showSnack('재생 실패: $e');
        if (mounted) setState(() => _isSampling = false);
      }
      return;
    }

    setState(() => _isSampling = true);
    try {
      final sampleText = _getSampleText(lang);
      final bytes = await GeminiService(apiKey).generateTts(
        text: sampleText,
        voiceName: voiceName,
      );

      // ── 캐시에 저장 (같은 목소리 반복 시 일관된 소리) ──
      _sampleCache[cacheKey] = bytes;

      await WebAudioHelper.playAutoAsync(bytes, sampleRate: 24000);
      _showSnack('🔊 $voiceName 샘플 재생 중...');
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && _isSampling) setState(() => _isSampling = false);
      });
    } catch (e) {
      final errMsg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        // 오류 내용을 다이얼로그로 표시 (스낵바는 너무 짧아서 잘림)
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.bgCard,
            title: Text('🔊 미리듣기 실패',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.error, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Text(
                errMsg,
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textPrimary, fontSize: 13),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('확인',
                    style: GoogleFonts.notoSansKr(color: AppTheme.accent)),
              ),
            ],
          ),
        );
        setState(() => _isSampling = false);
      }
    }
  }

  // 언어별 샘플 텍스트 (목소리 이름 제외 → 동일한 텍스트로 캐싱 가능하게)
  String _getSampleText(String lang) {
    switch (lang) {
      case '영어':  return 'Hello! This is a voice sample. How does this sound to you? I hope you like it.';
      case '일본어': return 'こんにちは。これは音声サンプルです。聞こえはいかがでしょうか。';
      case '대만어': return '你好！這是語音示例。聽起來怎麼樣？希望您喜歡。';
      case '스페인어': return '¡Hola! Esta es una muestra de voz. ¿Cómo suena? Espero que te guste.';
      default: return '안녕하세요. 이것은 목소리 샘플입니다. 자연스럽게 들리시나요? 이 목소리가 마음에 드시길 바랍니다.';
    }
  }

  void _dismissScriptModified() {
    setState(() => _scriptModified = false);
  }

  void _showScriptChangedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('대본이 수정되었습니다',
            style: GoogleFonts.notoSansKr(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          '수정된 대본으로 어떤 항목을 재생성하시겠습니까?',
          style: GoogleFonts.notoSansKr(
              color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: GoogleFonts.notoSansKr(
                color: AppTheme.textSecondary)),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _scriptModified = false);
              // 자막 재생성은 자막 탭으로 안내
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('자막 탭에서 "자막 자동 생성" 버튼을 눌러주세요.',
                      style: GoogleFonts.notoSansKr()),
                  backgroundColor: AppTheme.bgElevated,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.subtitles_rounded, size: 16),
            label: Text('자막 재생성', style: GoogleFonts.notoSansKr(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _scriptModified = false;
                _statusMsg = '';
              });
              _generateTts();
            },
            icon: const Icon(Icons.record_voice_over_rounded, size: 16),
            label: Text('TTS 재생성', style: GoogleFonts.notoSansKr(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }

  String _getApiKey() {
    final keys = widget.provider.apiKeys;
    switch (_engine) {
      case TtsEngine.gemini: return keys.geminiApiKey;
      case TtsEngine.elevenlabs: return keys.elevenLabsApiKey;
      case TtsEngine.clova: return keys.clovaApiKey;
      case TtsEngine.local: return 'local';
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.notoSansKr()),
        backgroundColor: AppTheme.bgElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수 호출
    return Row(
      children: [
        // 왼쪽: TTS 설정
        Container(
          width: 340,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppTheme.border)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('🎙️ TTS 엔진 선택'),
                const SizedBox(height: 12),
                ..._buildEngineCards(),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                _buildEngineSpecificSettings(),
                const SizedBox(height: 16),
                _sectionTitle('🎚️ 음성 파라미터'),
                const SizedBox(height: 12),
                _buildSlider('속도', _speed, 0.5, 2.0, (v) => setState(() => _speed = v)),
                _buildSlider('음정', _pitch, 0.5, 2.0, (v) => setState(() => _pitch = v)),
                _buildSlider('볼륨', _volume, 0.1, 1.0, (v) => setState(() => _volume = v)),
                const SizedBox(height: 20),
                // 생성 + 취소 버튼
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateTts,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.record_voice_over_rounded, size: 18),
                      label: Text(_isGenerating ? 'TTS 생성 중...' : 'TTS 음성 생성',
                          style: GoogleFonts.notoSansKr(fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (_isGenerating) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => setState(() => _isCancelled = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        minimumSize: Size.zero,
                      ),
                      child: const Icon(Icons.stop_rounded, size: 18, color: Colors.white),
                    ),
                  ],
                ]),
                if (_statusMsg.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_statusMsg,
                      style: GoogleFonts.notoSansKr(
                          color: _statusMsg.startsWith('✅')
                              ? AppTheme.success
                              : _statusMsg.startsWith('⏹')
                                  ? AppTheme.warning
                                  : AppTheme.error,
                          fontSize: 12)),
                ],
                const SizedBox(height: 16),
                // 직접 녹음 옵션
                if (_engine == TtsEngine.local) _buildRecordingSection(),
              ],
            ),
          ),
        ),
        // 오른쪽: 장면별 대본 편집 + 오디오 플레이어
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    Text('장면별 대본 편집',
                        style: GoogleFonts.notoSansKr(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('✏️ 탭하여 수정',
                          style: GoogleFonts.notoSansKr(
                              color: AppTheme.primaryLight, fontSize: 10)),
                    ),
                    const Spacer(),
                    if (widget.project.ttsAudioPath.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppTheme.success, size: 14),
                          const SizedBox(width: 4),
                          Text('음성 생성 완료',
                              style: GoogleFonts.notoSansKr(
                                  color: AppTheme.success, fontSize: 11)),
                        ]),
                      ),
                  ],
                ),
              ),
              // 대본 변경 감지 배너
              if (_scriptModified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.warning, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '대본이 수정되었습니다. TTS, 자막, 이미지를 다시 생성하시겠습니까?',
                          style: GoogleFonts.notoSansKr(
                              color: AppTheme.warning, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _dismissScriptModified,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                        child: Text('무시', style: GoogleFonts.notoSansKr(
                            color: AppTheme.textHint, fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: _showScriptChangedDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.warning,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: Text('재생성 선택', style: GoogleFonts.notoSansKr(
                            color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              // 오디오 플레이어 (생성된 경우)
              if (widget.project.ttsAudioBytes != null)
                _AudioPlayer(audioBytes: widget.project.ttsAudioBytes!),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: widget.project.scenes.length,
                  itemBuilder: (ctx, i) {
                    final scene = widget.project.scenes[i];
                    return _TtsSceneEditCard(
                      scene: scene,
                      index: i,
                      onScriptChanged: (newText) {
                        scene.scriptText = newText;
                        widget.provider.updateProject(widget.project);
                        setState(() => _scriptModified = true);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildEngineCards() {
    return TtsEngine.values.map((engine) {
      final selected = _engine == engine;
      final descriptions = {
        TtsEngine.gemini: 'Google AI 음성 | 한국어 최적화 | Gemini API 사용',
        TtsEngine.elevenlabs: '가장 자연스러운 음성 | 감정 표현 우수 | 유료',
        TtsEngine.clova: '네이버 한국어 특화 | 다양한 목소리 | 저렴',
        TtsEngine.local: '직접 녹음한 음성 사용 | 무료 | 파일 업로드',
      };
      return GestureDetector(
        onTap: () => setState(() => _engine = engine),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.1)
                : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected
                    ? AppTheme.accent.withValues(alpha: 0.6)
                    : AppTheme.border),
          ),
          child: Row(
            children: [
              Radio<TtsEngine>(
                value: engine,
                groupValue: _engine,
                onChanged: (v) => setState(() => _engine = v!),
                activeColor: AppTheme.accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(engine.displayName,
                        style: GoogleFonts.notoSansKr(
                            color: selected
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal)),
                    Text(descriptions[engine]!,
                        style: GoogleFonts.notoSansKr(
                            color: AppTheme.textHint, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildEngineSpecificSettings() {
    switch (_engine) {
      case TtsEngine.gemini:
        return _buildGeminiVoiceSettings();
      case TtsEngine.elevenlabs:
        return _buildElevenLabsSettings();
      case TtsEngine.clova:
        return _buildClovaSettings();
      case TtsEngine.local:
        return const SizedBox();
    }
  }

  Widget _buildGeminiVoiceSettings() {
    // 필터 적용
    final filtered = _geminiVoices.where((v) {
      final genderOk = _geminiFilterGender == '전체' || v['gender'] == _geminiFilterGender;
      final langs = v['langs'] as List;
      final langOk = _geminiFilterLang == '전체' || langs.contains(_geminiFilterLang);
      return genderOk && langOk;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _sectionTitle('🎙️ Gemini 음성 (${filtered.length}/${_geminiVoices.length})'),
          const Spacer(),
          if (_isSampling) ...[
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                WebAudioHelper.stopAll();
                setState(() => _isSampling = false);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stop_rounded, size: 12, color: Colors.red),
                    const SizedBox(width: 3),
                    Text('정지', style: GoogleFonts.notoSansKr(color: Colors.red, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Text('▶ 버튼으로 샘플 음성을 미리 들어보세요',
            style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 10)),
        const SizedBox(height: 10),
        _buildFilterRow(
          label: '성별',
          options: ['전체', '여성', '남성'],
          selected: _geminiFilterGender,
          onSelect: (v) => setState(() => _geminiFilterGender = v),
        ),
        const SizedBox(height: 6),
        _buildFilterRow(
          label: '언어',
          options: ['전체', '한국어', '영어', '일본어', '대만어', '다국어'],
          selected: _geminiFilterLang,
          onSelect: (v) => setState(() => _geminiFilterLang = v),
          scrollable: true,
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('필터 조건에 맞는 목소리가 없습니다.',
                  style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 12)),
            ),
          )
        else
          ...filtered.map((voice) {
            final vId = voice['id'] as String;
            final gender = voice['gender'] as String;
            final age = voice['age'] as String;
            final personality = voice['personality'] as String;
            final desc = voice['desc'] as String;
            final langs = (voice['langs'] as List).join(', ');
            final selected = _selectedGeminiVoice == vId;
            return GestureDetector(
              onTap: () => setState(() => _selectedGeminiVoice = vId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.accent.withValues(alpha: 0.12)
                      : AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected ? AppTheme.accent : AppTheme.border),
                ),
                child: Row(
                  children: [
                    if (selected)
                      const Icon(Icons.radio_button_checked_rounded,
                          color: AppTheme.accent, size: 16)
                    else
                      const Icon(Icons.radio_button_unchecked_rounded,
                          color: AppTheme.textHint, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(vId,
                                style: GoogleFonts.notoSansKr(
                                    color: selected ? AppTheme.accent : AppTheme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            _voiceBadge(gender == '여성' ? '♀' : '♂',
                                gender == '여성' ? Colors.pink.shade300 : Colors.blue.shade300),
                            const SizedBox(width: 4),
                            _voiceBadge(age, AppTheme.primary.withValues(alpha: 0.8)),
                          ]),
                          const SizedBox(height: 2),
                          Text(desc,
                              style: GoogleFonts.notoSansKr(
                                  color: AppTheme.textHint, fontSize: 10)),
                          const SizedBox(height: 2),
                          Row(children: [
                            Icon(Icons.translate_rounded, size: 10, color: AppTheme.textHint),
                            const SizedBox(width: 3),
                            Text(langs,
                                style: GoogleFonts.notoSansKr(
                                    color: AppTheme.textHint, fontSize: 9)),
                            const SizedBox(width: 8),
                            Text('성격: $personality',
                                style: GoogleFonts.notoSansKr(
                                    color: AppTheme.textHint, fontSize: 9)),
                          ]),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _isSampling ? null : () {
                        final langList = voice['langs'] as List;
                        final lang = langList.first as String;
                        _previewVoice(vId, lang: lang);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _isSampling
                              ? AppTheme.border
                              : AppTheme.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: _isSampling ? AppTheme.textHint : AppTheme.accent,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildElevenLabsSettings() {
    // 표시할 목소리 목록: API 불러온 것 + 내장 기본 목소리 병합
    final allVoices = <Map<String, String>>[];
    // API 목소리 먼저 (내 계정 커스텀 포함)
    allVoices.addAll(_elevenLabsApiVoices);
    // 내장 목소리 중 API에 없는 것만 추가
    for (final v in _elevenLabsBuiltinVoices) {
      if (!allVoices.any((a) => a['id'] == v['id'])) {
        allVoices.add(Map<String, String>.from(v));
      }
    }

    // 성별 필터
    final filtered = allVoices.where((v) {
      if (_elevenLabsFilterGender == '전체') return true;
      return v['gender'] == _elevenLabsFilterGender;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 헤더 ──
        Row(children: [
          _sectionTitle('🎤 ElevenLabs 음성 (${filtered.length})'),
          const Spacer(),
          if (_isSampling) ...[
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                WebAudioHelper.stopAll();
                setState(() { _isSampling = false; _elevenLabsPlayingId = ''; });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Text('■ 정지',
                    style: GoogleFonts.notoSansKr(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 8),

        // ── 필터 행 ──
        Row(children: [
          // 성별 필터
          ...['전체', '여성', '남성'].map((g) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _elevenLabsFilterGender = g),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _elevenLabsFilterGender == g
                      ? AppTheme.accent.withValues(alpha: 0.15)
                      : AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _elevenLabsFilterGender == g
                        ? AppTheme.accent
                        : AppTheme.border,
                  ),
                ),
                child: Text(g,
                    style: GoogleFonts.notoSansKr(
                        fontSize: 11,
                        color: _elevenLabsFilterGender == g ? AppTheme.accent : AppTheme.textSecondary,
                        fontWeight: _elevenLabsFilterGender == g ? FontWeight.w600 : FontWeight.normal)),
              ),
            ),
          )),
          const Spacer(),
          // API 불러오기 버튼
          GestureDetector(
            onTap: _loadElevenLabsVoices,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: _elevenLabsVoicesLoading
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_elevenLabsVoicesLoaded ? '🔄 새로고침' : '📋 내 목소리 불러오기',
                      style: GoogleFonts.notoSansKr(fontSize: 11, color: AppTheme.textSecondary)),
            ),
          ),
        ]),
        const SizedBox(height: 10),

        // ── 목소리 카드 목록 ──
        ...filtered.map((voice) {
          final vid = voice['id'] ?? '';
          final vname = voice['name'] ?? '';
          final vgender = voice['gender'] ?? '';
          final vdesc = voice['desc'] ?? voice['description'] ?? '';
          final vlang = voice['lang'] ?? voice['labels'] ?? '';
          final isSelected = _elevenLabsVoiceId == vid;
          final isPlaying = _elevenLabsPlayingId == vid && _isSampling;

          return GestureDetector(
            onTap: () => setState(() => _elevenLabsVoiceId = vid),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accent.withValues(alpha: 0.08)
                    : AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppTheme.accent : AppTheme.border,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(children: [
                // 선택 라디오
                Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppTheme.accent : AppTheme.border,
                      width: isSelected ? 5.0 : 1.5,
                    ),
                    color: isSelected ? AppTheme.accent : Colors.transparent,
                  ),
                ),
                const SizedBox(width: 10),
                // 정보
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(vname,
                          style: GoogleFonts.notoSansKr(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? AppTheme.accent : AppTheme.textPrimary)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: vgender == '여성'
                              ? Colors.pink.withValues(alpha: 0.15)
                              : Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(vgender.isNotEmpty ? vgender : '?',
                            style: GoogleFonts.notoSansKr(
                                fontSize: 10,
                                color: vgender == '여성' ? Colors.pink : Colors.blue)),
                      ),
                      if (vlang.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(vlang,
                              style: GoogleFonts.notoSansKr(
                                  fontSize: 10, color: AppTheme.textSecondary)),
                        ),
                      ],
                    ]),
                    if (vdesc.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(vdesc,
                            style: GoogleFonts.notoSansKr(
                                fontSize: 11, color: AppTheme.textSecondary)),
                      ),
                  ],
                )),
                // 미리듣기 버튼
                GestureDetector(
                  onTap: () => _previewElevenLabsVoice(vid, vname),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? AppTheme.accent.withValues(alpha: 0.15)
                          : AppTheme.bgDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPlaying ? AppTheme.accent : AppTheme.border,
                      ),
                    ),
                    child: isPlaying
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            const SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                            ),
                            const SizedBox(width: 4),
                            Text('재생 중',
                                style: GoogleFonts.notoSansKr(
                                    fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.w600)),
                          ])
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.play_arrow, size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 3),
                            Text('미리듣기',
                                style: GoogleFonts.notoSansKr(
                                    fontSize: 11, color: AppTheme.textSecondary)),
                          ]),
                  ),
                ),
              ]),
            ),
          );
        }),

        const SizedBox(height: 8),
        // 직접 입력 필드 (고급 사용자용)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('🔧 Voice ID 직접 입력 (고급)',
              style: GoogleFonts.notoSansKr(fontSize: 12, color: AppTheme.textSecondary)),
          children: [
            TextField(
              controller: TextEditingController(text: _elevenLabsVoiceId),
              onChanged: (v) => setState(() => _elevenLabsVoiceId = v),
              style: GoogleFonts.notoSansKr(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'ElevenLabs Voice ID',
                hintStyle: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 12),
                suffixText: _elevenLabsVoiceId.isNotEmpty ? '✓' : '',
              ),
            ),
            const SizedBox(height: 4),
            Text('ElevenLabs Voice Library에서 원하는 Voice ID를 복사해 입력하세요.',
                style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// ElevenLabs API에서 목소리 목록 불러오기
  Future<void> _loadElevenLabsVoices() async {
    final apiKey = widget.provider.apiKeys.elevenLabsApiKey;
    if (apiKey.isEmpty) {
      _showSnack('설정에서 ElevenLabs API 키를 먼저 입력해주세요.');
      return;
    }
    setState(() => _elevenLabsVoicesLoading = true);
    try {
      final voices = await ElevenLabsService(apiKey).getVoices();
      setState(() {
        _elevenLabsApiVoices = voices;
        _elevenLabsVoicesLoaded = true;
        _elevenLabsVoicesLoading = false;
      });
      _showSnack('✅ 내 목소리 ${voices.length}개를 불러왔습니다.');
    } catch (e) {
      setState(() => _elevenLabsVoicesLoading = false);
      _showSnack('불러오기 실패: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// ElevenLabs 목소리 미리듣기 (캐시 포함)
  Future<void> _previewElevenLabsVoice(String voiceId, String voiceName) async {
    final apiKey = widget.provider.apiKeys.elevenLabsApiKey;
    if (apiKey.isEmpty) {
      _showSnack('설정에서 ElevenLabs API 키를 먼저 입력해주세요.');
      return;
    }

    // 이미 재생 중이면 정지
    if (_elevenLabsPlayingId == voiceId && _isSampling) {
      WebAudioHelper.stopAll();
      setState(() { _isSampling = false; _elevenLabsPlayingId = ''; });
      return;
    }

    // 캐시 확인
    final cacheKey = 'elevenlabs_$voiceId';
    if (_sampleCache.containsKey(cacheKey)) {
      setState(() { _isSampling = true; _elevenLabsPlayingId = voiceId; });
      try {
        await WebAudioHelper.playAutoAsync(_sampleCache[cacheKey]!);
        _showSnack('🔊 $voiceName 재생 중...');
        Future.delayed(const Duration(seconds: 6), () {
          if (mounted && _elevenLabsPlayingId == voiceId) {
            setState(() { _isSampling = false; _elevenLabsPlayingId = ''; });
          }
        });
      } catch (e) {
        setState(() { _isSampling = false; _elevenLabsPlayingId = ''; });
        _showSnack('재생 실패: $e');
      }
      return;
    }

    setState(() { _isSampling = true; _elevenLabsPlayingId = voiceId; });
    try {
      final bytes = await ElevenLabsService(apiKey).previewVoice(voiceId: voiceId);
      _sampleCache[cacheKey] = bytes;
      await WebAudioHelper.playAutoAsync(bytes);
      _showSnack('🔊 $voiceName 재생 중...');
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && _elevenLabsPlayingId == voiceId) {
          setState(() { _isSampling = false; _elevenLabsPlayingId = ''; });
        }
      });
    } catch (e) {
      setState(() { _isSampling = false; _elevenLabsPlayingId = ''; });
      _showSnack('미리듣기 실패: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _previewClovaVoice(String speakerId, String speakerName, String lang) async {
    final keys = widget.provider.apiKeys;
    if (keys.clovaApiKey.isEmpty || keys.clovaApiSecret.isEmpty) {
      _showSnack('설정에서 CLOVA Client ID / Secret을 먼저 입력해주세요.');
      return;
    }

    // ── 캐시 히트 ──
    final cacheKey = 'clova_${speakerId}_$lang';
    if (_sampleCache.containsKey(cacheKey)) {
      setState(() => _isSampling = true);
      try {
        await WebAudioHelper.playAutoAsync(_sampleCache[cacheKey]!);
        _showSnack('🔊 $speakerName 샘플 재생 중...');
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _isSampling) setState(() => _isSampling = false);
        });
      } catch (e) {
        _showSnack('재생 실패: $e');
        if (mounted) setState(() => _isSampling = false);
      }
      return;
    }

    setState(() => _isSampling = true);
    try {
      final sampleText = _getSampleText(lang);
      final bytes = await ClovaTtsService(
        clientId: keys.clovaApiKey,
        clientSecret: keys.clovaApiSecret,
      ).generateTts(
        text: sampleText,
        speaker: speakerId,
        format: 'mp3',
      );

      // ── 캐시에 저장 ──
      _sampleCache[cacheKey] = bytes;

      await WebAudioHelper.playAutoAsync(bytes);
      _showSnack('🔊 $speakerName 샘플 재생 중...');
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _isSampling) setState(() => _isSampling = false);
      });
    } catch (e) {
      _showSnack('샘플 재생 실패: ${e.toString().replaceAll('Exception: ', '')}');
      if (mounted) setState(() => _isSampling = false);
    }
  }

  Widget _buildClovaSettings() {
    // 필터 적용
    final filtered = _clovaVoicesAll.where((v) {
      final genderOk = _clovaFilterGender == '전체' || v['gender'] == _clovaFilterGender;
      final langOk = _clovaFilterLang == '전체' || v['lang'] == _clovaFilterLang;
      return genderOk && langOk;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _sectionTitle('🎙️ CLOVA 음성 (${filtered.length}/${_clovaVoicesAll.length})'),
          const Spacer(),
          if (_isSampling) ...[
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                WebAudioHelper.stopAll();
                setState(() => _isSampling = false);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stop_rounded, size: 12, color: Colors.red),
                    const SizedBox(width: 3),
                    Text('정지', style: GoogleFonts.notoSansKr(color: Colors.red, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Text('▶ 버튼으로 샘플 음성을 미리 들어보세요 (API 키 필요)',
            style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 10)),
        const SizedBox(height: 10),
        // 필터
        _buildFilterRow(
          label: '성별',
          options: ['전체', '여성', '남성'],
          selected: _clovaFilterGender,
          onSelect: (v) => setState(() => _clovaFilterGender = v),
        ),
        const SizedBox(height: 6),
        _buildFilterRow(
          label: '언어',
          options: ['전체', '한국어', '영어', '일본어', '대만어', '스페인어'],
          selected: _clovaFilterLang,
          onSelect: (v) => setState(() => _clovaFilterLang = v),
          scrollable: true,
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('필터 조건에 맞는 목소리가 없습니다.',
                  style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 12)),
            ),
          )
        else
          ...filtered.map((voice) {
            final speakerId = voice['id'] as String;
            final speakerName = voice['name'] as String;
            final gender = voice['gender'] as String;
            final age = voice['age'] as String;
            final personality = voice['personality'] as String;
            final lang = voice['lang'] as String;
            final desc = voice['desc'] as String;
            final selected = _clovaVoiceId == speakerId;
            return GestureDetector(
              onTap: () => setState(() => _clovaVoiceId = speakerId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.accent.withValues(alpha: 0.12)
                      : AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected ? AppTheme.accent : AppTheme.border),
                ),
                child: Row(
                  children: [
                    if (selected)
                      const Icon(Icons.radio_button_checked_rounded,
                          color: AppTheme.accent, size: 16)
                    else
                      const Icon(Icons.radio_button_unchecked_rounded,
                          color: AppTheme.textHint, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(speakerName,
                                style: GoogleFonts.notoSansKr(
                                    color: selected ? AppTheme.accent : AppTheme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            _voiceBadge(gender == '여성' ? '♀' : '♂',
                                gender == '여성' ? Colors.pink.shade300 : Colors.blue.shade300),
                            const SizedBox(width: 4),
                            _voiceBadge(age, AppTheme.primary.withValues(alpha: 0.8)),
                            const SizedBox(width: 4),
                            _voiceBadge(lang, Colors.teal.shade300),
                          ]),
                          const SizedBox(height: 2),
                          Text(desc,
                              style: GoogleFonts.notoSansKr(
                                  color: AppTheme.textHint, fontSize: 10)),
                          const SizedBox(height: 2),
                          Text('성격: $personality',
                              style: GoogleFonts.notoSansKr(
                                  color: AppTheme.textHint, fontSize: 9)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _isSampling
                          ? null
                          : () => _previewClovaVoice(speakerId, speakerName, lang),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _isSampling
                              ? AppTheme.border
                              : AppTheme.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: _isSampling ? AppTheme.textHint : AppTheme.accent,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
        // API 키 미설정 안내
        if (widget.provider.apiKeys.clovaApiKey.isEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Text(
              '⚠️ 설정 → API 키에서 CLOVA Client ID와 Client Secret을 입력해야 샘플 재생 및 TTS 생성이 가능합니다.',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.warning, fontSize: 10, height: 1.5),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRecordingSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('직접 녹음 파일 업로드',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('MP3, WAV, M4A 파일을 업로드하세요',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textHint, fontSize: 11)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.audio,
              );
              if (result != null && result.files.isNotEmpty) {
                final path = result.files.first.path ?? '';
                widget.project.ttsAudioPath = path;
                widget.provider.updateProject(widget.project);
                setState(() => _statusMsg = '✅ 녹음 파일이 설정되었습니다!');
              }
            },
            icon: const Icon(Icons.upload_file_rounded, size: 16),
            label: Text('오디오 파일 선택', style: GoogleFonts.notoSansKr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.bgElevated,
              foregroundColor: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.textSecondary, fontSize: 12)),
              Text(value.toStringAsFixed(1),
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: AppTheme.accent,
            inactiveColor: AppTheme.border,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // 음성 배지 위젯
  Widget _voiceBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: GoogleFonts.notoSansKr(
              color: color, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }

  // 필터 행 위젯
  Widget _buildFilterRow({
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
    bool scrollable = false,
  }) {
    final chips = options.map((opt) {
      final isSelected = selected == opt;
      return GestureDetector(
        onTap: () => onSelect(opt),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isSelected ? AppTheme.accent : AppTheme.border),
          ),
          child: Text(opt,
              style: GoogleFonts.notoSansKr(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ),
      );
    }).toList();

    return Row(
      children: [
        Text('$label: ',
            style: GoogleFonts.notoSansKr(
                color: AppTheme.textHint, fontSize: 10)),
        scrollable
            ? Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: chips),
                ),
              )
            : Row(children: chips),
      ],
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.notoSansKr(
          color: AppTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.bold));
}

// ───────────────────────────────────────
// 탭 3: 자막 편집
// ───────────────────────────────────────
class _SubtitleTab extends StatefulWidget {
  final ProjectModel project;
  final AppProvider provider;
  const _SubtitleTab({required this.project, required this.provider});

  @override
  State<_SubtitleTab> createState() => _SubtitleTabState();
}

class _SubtitleTabState extends State<_SubtitleTab> {
  bool _isGenerating = false;
  bool _isCancelled = false;  // 취소 플래그
  String _statusMsg = '';

  Future<void> _generateSubtitles() async {
    if (widget.project.scenes.isEmpty) {
      _showSnack('장면이 없습니다. 먼저 장면을 분할해주세요.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _isCancelled = false;
      _statusMsg = '자막 생성 중...';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (_isCancelled) {
      setState(() {
        _isGenerating = false;
        _statusMsg = '⏹ 자막 생성이 취소되었습니다.';
      });
      return;
    }

    // 장면에서 자막 생성
    double currentTime = 0.0;
    widget.project.subtitles.clear();

    for (int i = 0; i < widget.project.scenes.length; i++) {
      final scene = widget.project.scenes[i];
      final duration = (scene.scriptText.length / 5).clamp(2.0, 30.0);

      widget.project.subtitles.add(SubtitleEntry(
        id: '${widget.project.id}_sub_$i',
        startTime: currentTime,
        endTime: currentTime + duration,
        text: scene.scriptText,
      ));

      currentTime += duration + 0.1;
    }

    widget.provider.updateProject(widget.project);

    setState(() {
      _isGenerating = false;
      _statusMsg = '✅ 자막 생성 완료! ${widget.project.subtitles.length}개';
    });
    _showSnack('자막이 생성되었습니다!');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.notoSansKr()),
        backgroundColor: AppTheme.bgElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _exportSrt() {
    final buffer = StringBuffer();
    for (int i = 0; i < widget.project.subtitles.length; i++) {
      buffer.write(widget.project.subtitles[i].toSrt(i + 1));
      buffer.write('\n');
    }
    return buffer.toString();
  }

  void _downloadSrtWeb(String content, String filename) {
    // 웹 환경에서 파일 다운로드
    final bytes = utf8.encode(content);
    final blob = bytes;
    // base64 data URI로 다운로드 트리거
    final b64 = base64Encode(blob);
    final dataUri = 'data:text/plain;charset=utf-8;base64,$b64';
    // 클립보드에 data URI 복사 (웹 직접 다운로드 대안)
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('SRT 내용이 클립보드에 복사되었습니다. 텍스트 편집기에 붙여넣기 후 .srt로 저장하세요.',
            style: GoogleFonts.notoSansKr()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
    debugPrint('SRT data URI (length: ${dataUri.length}): $filename');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상단 액션바
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateSubtitles,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(_isGenerating ? '생성 중...' : '자막 자동 생성',
                    style: GoogleFonts.notoSansKr(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary),
              ),
              if (_isGenerating) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _isCancelled = true),
                  icon: const Icon(Icons.stop_rounded, size: 14, color: Colors.white),
                  label: Text('취소', style: GoogleFonts.notoSansKr(
                      color: Colors.white, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: widget.project.subtitles.isEmpty
                    ? null
                    : () {
                        final srtContent = _exportSrt();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppTheme.bgCard,
                            title: Text('SRT 자막 파일',
                                style: GoogleFonts.notoSansKr(
                                    color: AppTheme.textPrimary)),
                            content: SingleChildScrollView(
                              child: Container(
                                width: 600,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgDark,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SelectableText(
                                  srtContent,
                                  style: GoogleFonts.sourceCodePro(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12),
                                ),
                              ),
                            ),
                            actions: [
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: srtContent));
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text('클립보드에 복사되었습니다.',
                                          style: GoogleFonts.notoSansKr()),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 14),
                                label: Text('복사', style: GoogleFonts.notoSansKr()),
                              ),
                              if (kIsWeb)
                                TextButton.icon(
                                  onPressed: () {
                                    _downloadSrtWeb(srtContent,
                                        '${widget.project.title}.srt');
                                    Navigator.pop(ctx);
                                  },
                                  icon: const Icon(Icons.download_rounded, size: 14),
                                  label: Text('다운로드', style: GoogleFonts.notoSansKr()),
                                ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('닫기', style: GoogleFonts.notoSansKr()),
                              ),
                            ],
                          ),
                        );
                      },
                icon: const Icon(Icons.subtitles_rounded, size: 16),
                label: Text('SRT 내보내기', style: GoogleFonts.notoSansKr(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.border)),
              ),
              const Spacer(),
              if (widget.project.subtitles.isNotEmpty)
                Text('${widget.project.subtitles.length}개 자막',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.textHint, fontSize: 12)),
              if (_statusMsg.isNotEmpty) ...[
                const SizedBox(width: 16),
                Text(_statusMsg,
                    style: GoogleFonts.notoSansKr(
                        color: _statusMsg.startsWith('✅')
                            ? AppTheme.success
                            : AppTheme.textSecondary,
                        fontSize: 12)),
              ],
            ],
          ),
        ),
        // 자막 목록
        Expanded(
          child: widget.project.subtitles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.subtitles_outlined,
                          size: 56, color: AppTheme.textHint),
                      const SizedBox(height: 14),
                      Text('자막이 없습니다',
                          style: GoogleFonts.notoSansKr(
                              color: AppTheme.textSecondary, fontSize: 15)),
                      const SizedBox(height: 8),
                      Text('"자막 자동 생성" 버튼을 눌러 자막을 생성하세요',
                          style: GoogleFonts.notoSansKr(
                              color: AppTheme.textHint, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.project.subtitles.length,
                  itemBuilder: (ctx, i) {
                    return _SubtitleEditor(
                      entry: widget.project.subtitles[i],
                      index: i,
                      onChanged: () {
                        widget.provider.updateProject(widget.project);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// 자막 편집 위젯
class _SubtitleEditor extends StatefulWidget {
  final SubtitleEntry entry;
  final int index;
  final VoidCallback onChanged;

  const _SubtitleEditor({
    required this.entry,
    required this.index,
    required this.onChanged,
  });

  @override
  State<_SubtitleEditor> createState() => _SubtitleEditorState();
}

class _SubtitleEditorState extends State<_SubtitleEditor> {
  late TextEditingController _textCtrl;
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.entry.text);
    _startCtrl =
        TextEditingController(text: widget.entry.startTime.toStringAsFixed(2));
    _endCtrl =
        TextEditingController(text: widget.entry.endTime.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  String _formatTime(double s) {
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toStringAsFixed(1).padLeft(4, '0');
    return '$h:$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: widget.entry.isEdited
            ? AppTheme.warning.withValues(alpha: 0.05)
            : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.entry.isEdited
              ? AppTheme.warning.withValues(alpha: 0.3)
              : AppTheme.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text('${widget.index + 1}',
                        style: GoogleFonts.notoSansKr(
                            color: AppTheme.primaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_formatTime(widget.entry.startTime)} → ${_formatTime(widget.entry.endTime)}',
                  style: GoogleFonts.sourceCodePro(
                      color: AppTheme.textHint, fontSize: 11),
                ),
                const Spacer(),
                if (widget.entry.isEdited)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('수정됨',
                        style: GoogleFonts.notoSansKr(
                            color: AppTheme.warning, fontSize: 9)),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(_editing ? Icons.check_rounded : Icons.edit_rounded,
                      size: 16),
                  color: _editing ? AppTheme.success : AppTheme.textHint,
                  onPressed: () {
                    if (_editing) {
                      widget.entry.text = _textCtrl.text;
                      widget.entry.startTime =
                          double.tryParse(_startCtrl.text) ??
                              widget.entry.startTime;
                      widget.entry.endTime =
                          double.tryParse(_endCtrl.text) ??
                              widget.entry.endTime;
                      widget.entry.isEdited = true;
                      widget.onChanged();
                    }
                    setState(() => _editing = !_editing);
                  },
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_editing)
              TextField(
                controller: _textCtrl,
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textPrimary, fontSize: 13),
                maxLines: 2,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
              )
            else
              Text(
                widget.entry.text,
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    height: 1.5),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TTS 탭 장면 카드 (대본 인라인 편집)
// ─────────────────────────────────────────────
class _TtsSceneEditCard extends StatefulWidget {
  final SceneModel scene;
  final int index;
  final ValueChanged<String> onScriptChanged;

  const _TtsSceneEditCard({
    required this.scene,
    required this.index,
    required this.onScriptChanged,
  });

  @override
  State<_TtsSceneEditCard> createState() => _TtsSceneEditCardState();
}

class _TtsSceneEditCardState extends State<_TtsSceneEditCard> {
  bool _editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.scene.scriptText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _editing
            ? AppTheme.primary.withValues(alpha: 0.04)
            : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _editing ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('${widget.index + 1}',
                        style: GoogleFonts.notoSansKr(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '~${(widget.scene.scriptText.length / 5).round()}초',
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.textHint, fontSize: 11),
                ),
                const Spacer(),
                if (_editing) ...[
                  TextButton(
                    onPressed: () {
                      setState(() => _editing = false);
                      _ctrl.text = widget.scene.scriptText; // 취소 시 원복
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: Text('취소', style: GoogleFonts.notoSansKr(
                        color: AppTheme.textSecondary, fontSize: 11)),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: () {
                      widget.onScriptChanged(_ctrl.text);
                      setState(() => _editing = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: Text('저장', style: GoogleFonts.notoSansKr(
                        color: Colors.white, fontSize: 11)),
                  ),
                ] else
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    color: AppTheme.textHint,
                    tooltip: '대본 수정',
                    onPressed: () => setState(() => _editing = true),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_editing)
              TextField(
                controller: _ctrl,
                maxLines: null,
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textPrimary, fontSize: 13, height: 1.6),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                        color: AppTheme.primary.withValues(alpha: 0.5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                        color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                  isDense: true,
                ),
              )
            else
              Text(
                widget.scene.scriptText,
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textPrimary, fontSize: 13, height: 1.6),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 오디오 플레이어 위젯
// ─────────────────────────────────────────────
class _AudioPlayer extends StatefulWidget {
  final Uint8List audioBytes;
  const _AudioPlayer({required this.audioBytes});

  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer>
    with SingleTickerProviderStateMixin {
  bool _playing = false;
  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    // 위젯 제거 시 재생 중이면 정지
    if (_playing) WebAudioHelper.stopAll();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.notoSansKr()),
        backgroundColor: AppTheme.bgElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 오디오 재생 (Web/Desktop 통합)
  void _playAudio() async {
    try {
      setState(() => _playing = true);
      _waveCtrl.repeat(reverse: true);

      await WebAudioHelper.playAutoAsync(widget.audioBytes, sampleRate: 24000);

      // 재생 시간 추정
      int estimatedSecs;
      final bytes = widget.audioBytes;
      if (WebAudioHelper.isWav(bytes)) {
        // WAV 헤더(44바이트) 제외한 PCM 길이로 계산 (16bit mono 24kHz)
        final pcmLen = bytes.length > 44 ? bytes.length - 44 : bytes.length;
        estimatedSecs = (pcmLen ~/ (24000 * 1 * 2)).clamp(2, 600);
      } else if (WebAudioHelper.isMp3(bytes)) {
        // MP3: 128kbps 기준 추정 (16000 bytes/sec)
        // ElevenLabs 반환 MP3도 포함
        estimatedSecs = (bytes.length ~/ 16000).clamp(3, 600);
      } else {
        // raw PCM (Gemini TTS): 16bit mono 24kHz
        estimatedSecs = (bytes.length ~/ (24000 * 2)).clamp(2, 600);
      }
      Future.delayed(Duration(seconds: estimatedSecs + 1), () {
        if (mounted) {
          setState(() => _playing = false);
          _waveCtrl.stop();
        }
      });
    } catch (e) {
      _showSnack('재생 오류: $e');
      if (mounted) {
        setState(() => _playing = false);
        _waveCtrl.stop();
      }
    }
  }

  /// 재생 중인 오디오 정지
  void _stopAudio() {
    if (!_playing) return;
    WebAudioHelper.stopAll();
    if (mounted) {
      setState(() => _playing = false);
      _waveCtrl.stop();
      _waveCtrl.reset();
    }
  }


  /// 오디오 파일 저장 (Web: Blob 다운로드 / Desktop: FilePicker 저장)
  void _downloadAudio() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      if (kIsWeb) {
        // 웹: JS Blob URL 다운로드
        WebAudioHelper.downloadAuto(
          widget.audioBytes,
          fileName: 'tts_audio_$timestamp',
          sampleRate: 24000,
        );
        _showSnack('🎵 오디오 파일 다운로드 시작!');
      } else {
        // Windows/Desktop: FilePicker로 저장 경로 선택 후 파일 저장
        final savedPath = await WebAudioHelper.saveDesktopAudio(
          widget.audioBytes,
          defaultName: 'tts_audio_$timestamp',
          sampleRate: 24000,
        );
        if (savedPath != null) {
          _showSnack('💾 저장 완료: $savedPath');
        } else {
          // 사용자가 취소한 경우
          _showSnack('저장이 취소되었습니다.');
        }
      }
    } catch (e) {
      _showSnack('다운로드 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizeStr = _formatBytes(widget.audioBytes.length);
    final estSecs = widget.audioBytes.length ~/ 48000;
    final estMin = estSecs ~/ 60;
    final estSec = estSecs % 60;
    final estDuration = '$estMin:${estSec.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.headphones_rounded, color: AppTheme.accent, size: 16),
            const SizedBox(width: 6),
            Text('생성된 음성',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('$sizeStr · 약 $estDuration',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textHint, fontSize: 11)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // 재생 / 정지 버튼
                GestureDetector(
                  onTap: _playing ? _stopAudio : _playAudio,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _playing
                          ? Colors.red.withValues(alpha: 0.85)
                          : AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _playing
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _playing ? '재생 중... (탭하면 정지)' : '▶ 재생   ⏹ 정지   ⬇ 다운로드',
                        style: GoogleFonts.notoSansKr(
                            color: _playing ? AppTheme.accent : AppTheme.textPrimary,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      // 파형 시각화 (재생 중 애니메이션)
                      AnimatedBuilder(
                        animation: _waveCtrl,
                        builder: (context, _) {
                          return Row(
                            children: List.generate(30, (i) {
                              final base = (4 + (i * 7 + 3) % 16).toDouble();
                              final animated = _playing
                                  ? base + (_waveCtrl.value * base * 0.8 *
                                      ((i % 3 == 0) ? 1.0 : (i % 3 == 1) ? 0.6 : 0.4))
                                  : base;
                              return Container(
                                width: 3,
                                height: animated,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: _playing
                                      ? AppTheme.accent
                                      : AppTheme.textHint.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 다운로드 버튼
                IconButton(
                  icon: const Icon(Icons.download_rounded,
                      color: AppTheme.textSecondary, size: 22),
                  onPressed: _downloadAudio,
                  tooltip: 'WAV 파일 다운로드',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            kIsWeb
                ? '▶ 재생 · ⏹ 재생 중 탭하면 정지 · ⬇ 다운로드'
                : '⬇ 다운로드 버튼으로 WAV 파일을 저장하세요',
            style: GoogleFonts.notoSansKr(
                color: AppTheme.textHint, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── 세마포어: 동시 실행 Future 수 제한 ──
class _Semaphore {
  final int maxConcurrent;
  int _current = 0;
  final _queue = <void Function()>[];

  _Semaphore(this.maxConcurrent);

  Future<void> acquire() async {
    if (_current < maxConcurrent) {
      _current++;
      return;
    }
    final completer = Completer<void>();
    _queue.add(() {
      _current++;
      completer.complete();
    });
    await completer.future;
  }

  void release() {
    _current--;
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      next();
    }
  }
}
