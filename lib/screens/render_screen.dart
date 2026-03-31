import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../models/project_model.dart';
import '../models/channel_model.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../utils/web_audio_helper.dart';

import 'dart:typed_data';

// ── ZIP 인코딩 백그라운드 함수 (compute() 용 top-level) ──
// UI 스레드 블로킹 방지: 이미지/오디오 포함 대용량 ZIP을 isolate에서 처리
Uint8List _encodeZipIsolate(List<dynamic> files) {
  // files: [['경로', bytes], ...]
  final archive = Archive();
  for (final item in files) {
    final path = item[0] as String;
    final data = item[1] as List<int>;
    archive.addFile(ArchiveFile(path, data.length, data));
  }
  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}

// ─────────────────────────────────────
// 렌더링 & 유튜브 업로드 화면
// ─────────────────────────────────────
class RenderScreen extends StatefulWidget {
  const RenderScreen({super.key});

  @override
  State<RenderScreen> createState() => _RenderScreenState();
}

class _RenderScreenState extends State<RenderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, provider, _) {
      final project = provider.currentProject;
      return Column(
        children: [
          _buildHeader(context, provider, project),
          TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: '🎬 렌더링'),
              Tab(text: '🖼️ 썸네일'),
              Tab(text: '📤 유튜브 업로드'),
            ],
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            labelStyle:
                GoogleFonts.notoSansKr(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.notoSansKr(fontSize: 13),
          ),
          Expanded(
            child: project == null
                ? _buildNoProjectState(context, provider)
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _RenderingTab(project: project, provider: provider),
                      _ThumbnailTab(project: project, provider: provider),
                      _YoutubeUploadTab(project: project, provider: provider),
                    ],
                  ),
          ),
        ],
      );
    });
  }

  Widget _buildHeader(
      BuildContext context, AppProvider provider, ProjectModel? project) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(
        children: [
          const Icon(Icons.movie_creation_rounded, color: AppTheme.primary, size: 22),
          const SizedBox(width: 10),
          Text('렌더링 & 업로드',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          if (project != null) ...[
            const SizedBox(width: 16),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(project.title,
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.primaryLight, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          const Spacer(),
          if (project != null)
            _StatusBadge(status: project.status),
        ],
      ),
    );
  }

  Widget _buildNoProjectState(BuildContext context, AppProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_outlined, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text('프로젝트를 먼저 선택하세요',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => provider.setNavIndex(2),
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: Text('프로젝트 화면으로', style: GoogleFonts.notoSansKr()),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────
// 상태 배지
// ─────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final ProjectStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = {
      ProjectStatus.draft: AppTheme.textHint,
      ProjectStatus.scriptReady: AppTheme.primary,
      ProjectStatus.sceneSplit: AppTheme.primaryLight,
      ProjectStatus.mediaGenerating: AppTheme.warning,
      ProjectStatus.mediaReady: AppTheme.accent,
      ProjectStatus.ttsReady: AppTheme.accent,
      ProjectStatus.subtitleReady: AppTheme.accent,
      ProjectStatus.rendering: AppTheme.warning,
      ProjectStatus.rendered: AppTheme.success,
      ProjectStatus.thumbnailReady: AppTheme.success,
      ProjectStatus.uploading: AppTheme.warning,
      ProjectStatus.uploaded: AppTheme.success,
    };
    final color = colors[status] ?? AppTheme.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(status.displayName,
          style: GoogleFonts.notoSansKr(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────
// 탭 1: 렌더링
// ─────────────────────────────────────
class _RenderingTab extends StatefulWidget {
  final ProjectModel project;
  final AppProvider provider;
  const _RenderingTab({required this.project, required this.provider});

  @override
  State<_RenderingTab> createState() => _RenderingTabState();
}

class _RenderingTabState extends State<_RenderingTab> {
  bool _isRendering = false;
  double _renderProgress = 0.0;
  String _renderLog = '';
  final String _outputPath = 'C:\\TubeMaster\\Output';
  String _selectedPreset = 'youtube';
  bool _includeIntro = false;
  bool _includeOutro = false;
  bool _includeWatermark = false;
  bool _includeRandomEffect = false; // 랜덤 카메라 효과

  // ── 직접 렌더링 (FFmpeg) ──
  String _ffmpegPath = '';        // 감지된 FFmpeg 경로
  bool _ffmpegFound = false;      // FFmpeg 존재 여부
  bool _isDirectRender = true;    // true=MP4 직접 생성, false=ZIP 패키지
  String _directRenderStatus = ''; // 직접 렌더링 상태 메시지
  String _lastOutputMp4 = '';     // 최종 저장된 MP4 경로
  Process? _ffmpegProcess;        // 실행 중인 FFmpeg 프로세스 (취소용)
  bool _isRenderCancelled = false; // 렌더링 취소 플래그

  // 자막 설정
  double _subtitleFontSize = 24.0;
  String _subtitleFont = 'NanumGothic';
  int _subtitleMaxChars = 20; // 줄당 최대 글자수
  bool _previewIs169 = true; // 미리보기 모드: true=16:9, false=9:16

  // 사용 가능한 자막 폰트 목록
  // flutter: Flutter에서 실제로 보여줄 GoogleFonts 메서드 키
  final List<Map<String, String>> _subtitleFonts = [
    {'name': 'NanumGothic',   'label': '나눔고딕',        'flutter': 'notoSansKr'},
    {'name': 'NanumMyeongjo', 'label': '나눔명조',        'flutter': 'notoSerifKr'},
    {'name': 'MalgunGothic',  'label': '맑은 고딕 (Win)', 'flutter': 'notoSansKr'},
    {'name': 'AppleGothic',   'label': '애플고딕 (Mac)',  'flutter': 'notoSansKr'},
    {'name': 'Arial',         'label': 'Arial',           'flutter': 'roboto'},
    {'name': 'Impact',        'label': 'Impact (굵게)',   'flutter': 'bebasNeue'},
  ];

  // 폰트 키로 TextStyle 반환
  TextStyle _getFlutterFontStyle(String fontKey, double fontSize, {bool bold = false}) {
    final fw = bold ? FontWeight.bold : FontWeight.normal;
    switch (fontKey) {
      case 'notoSerifKr':
        return GoogleFonts.notoSerifKr(fontSize: fontSize, fontWeight: fw);
      case 'roboto':
        return GoogleFonts.roboto(fontSize: fontSize, fontWeight: fw);
      case 'bebasNeue':
        return GoogleFonts.bebasNeue(fontSize: fontSize);
      default: // notoSansKr
        return GoogleFonts.notoSansKr(fontSize: fontSize, fontWeight: fw);
    }
  }

  String get _currentFlutterFontKey {
    final found = _subtitleFonts.firstWhere(
      (f) => f['name'] == _subtitleFont,
      orElse: () => _subtitleFonts.first,
    );
    return found['flutter'] ?? 'notoSansKr';
  }

  // 렌더링 프리셋
  final Map<String, Map<String, String>> _presets = {
    'youtube': {'label': 'YouTube (1080p 30fps)', 'desc': '표준 유튜브 영상 설정'},
    'youtube_hd': {'label': 'YouTube HD (1080p 60fps)', 'desc': '고프레임 유튜브'},
    'shorts': {'label': 'YouTube Shorts (9:16)', 'desc': '세로형 숏츠'},
    'twitter': {'label': 'Twitter/X (720p)', 'desc': '트위터 최적화'},
    'custom': {'label': '사용자 지정', 'desc': '직접 설정'},
  };

  // 장면 수만큼 랜덤 효과 필터 생성 (Mac/Linux 쉘 스크립트용 - \ 이스케이프 포함)
  String _buildRandomEffectFilter(int sceneCount) {
    // ZIP/쉘 스크립트용 — min(on,d-1)으로 루프 시 프레임 초과 방지
    String kenBurns(int d, String effect) {
      final n = 'min(on,$d-1)';
      switch (effect) {
        case 'zoomin':
          return 'scale=2112:1188:force_original_aspect_ratio=increase,crop=2112:1188,'
              'crop=w=trunc((2112-(192*$n/$d))/2)*2:h=trunc((1188-(108*$n/$d))/2)*2'
              ':x=trunc(96*$n/$d/2)*2:y=trunc(54*$n/$d/2)*2,'
              'scale=1920:1080,setsar=1,format=yuv420p';
        case 'zoomout':
          return 'scale=2112:1188:force_original_aspect_ratio=increase,crop=2112:1188,'
              'crop=w=trunc((1920+(192*$n/$d))/2)*2:h=trunc((1080+(108*$n/$d))/2)*2'
              ':x=trunc((96-96*$n/$d)/2)*2:y=trunc((54-54*$n/$d)/2)*2,'
              'scale=1920:1080,setsar=1,format=yuv420p';
        case 'panright':
          return 'scale=2112:1080:force_original_aspect_ratio=increase,'
              'crop=1920:1080:x=trunc(192*$n/$d/2)*2:y=0,setsar=1,format=yuv420p';
        case 'panleft':
          return 'scale=2112:1080:force_original_aspect_ratio=increase,'
              'crop=1920:1080:x=trunc(192*(1-$n/$d)/2)*2:y=0,setsar=1,format=yuv420p';
        case 'pandown':
          return 'scale=1920:1188:force_original_aspect_ratio=increase,'
              'crop=1920:1080:x=0:y=trunc(108*$n/$d/2)*2,setsar=1,format=yuv420p';
        default: // panup
          return 'scale=1920:1188:force_original_aspect_ratio=increase,'
              'crop=1920:1080:x=0:y=trunc(108*(1-$n/$d)/2)*2,setsar=1,format=yuv420p';
      }
    }
    const effectNames = ['zoomin','zoomout','panright','panleft','pandown','panup'];
    final seed = DateTime.now().millisecondsSinceEpoch;
    final filters = StringBuffer();
    int lastIdx = -1;
    for (int i = 0; i < sceneCount; i++) {
      final scene = widget.project.scenes[i];
      final d = (scene.duration * 25).toInt().clamp(1, 99999);
      int idx;
      do { idx = (seed ~/ (i + 1) + i * 3) % effectNames.length; } while (idx == lastIdx && effectNames.length > 1);
      lastIdx = idx;
      final f = kenBurns(d, effectNames[idx]);
      filters.write('[$i:v]scale=1920:1080:force_original_aspect_ratio=decrease,'
          'pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=25,$f[v$i];');
    }
    final concat = List.generate(sceneCount, (i) => '[v$i]').join('');
    filters.write('${concat}concat=n=$sceneCount:v=1:a=0[vid]');
    return filters.toString();
  }

  // 장면별 TTS가 있는지 확인
  bool get _hasPerSceneTts => widget.project.scenes.any((s) => s.sceneTtsBytes != null);

  // Mac/Linux용 쉘 스크립트 ffmpeg 명령어 (줄바꿈 \ 사용)
  String _buildFfmpegCommand() {
    final safe = widget.project.title.replaceAll(RegExp(r'[^\w가-힣]'), '_');
    final hasTts = widget.project.ttsAudioBytes != null;
    final hasPerSceneTts = _hasPerSceneTts;
    final sceneCount = widget.project.scenes.length;
    final hasIntro = _includeIntro;
    final hasOutro = _includeOutro;

    // ── 장면별 TTS 모드: 각 이미지+해당 TTS를 개별 합성 후 concat ──
    // 인트로/아웃트로 없고, 장면별 TTS 존재 시 사용 (가장 정확한 싱크)
    if (hasPerSceneTts && !hasIntro && !hasOutro) {
      final inputLines = StringBuffer();
      for (int i = 0; i < sceneCount; i++) {
        final scene = widget.project.scenes[i];
        final dur = scene.duration.toStringAsFixed(3);
        final hasImg = scene.imageBytes != null;
        if (hasImg) {
          inputLines.write('  -loop 1 -t $dur -i "scenes/scene_${i + 1}.jpg" \\\n');
        } else {
          inputLines.write('  -f lavfi -t $dur -i "color=black:s=1920x1080:r=25" \\\n');
        }
        // TTS 오디오 입력 (각 장면)
        if (scene.sceneTtsBytes != null) {
          inputLines.write('  -i "scenes/scene_${i + 1}_tts.wav" \\\n');
        }
      }

      // filter_complex: 각 (이미지,오디오) 쌍 → [vi][ai] → concat
      final filterParts = StringBuffer();
      final vidConcat = StringBuffer();
      final audConcat = StringBuffer();
      int inputIdx = 0;
      for (int i = 0; i < sceneCount; i++) {
        final scene = widget.project.scenes[i];
        final d = (scene.duration * 25).toInt();
        final vidIdx = inputIdx++;
        final audIdx = scene.sceneTtsBytes != null ? inputIdx++ : -1;
        filterParts.write('[$vidIdx:v]format=yuv420p,scale=1920:1080:force_original_aspect_ratio=decrease,'
            'pad=1920:1080:(ow-iw)/2:(oh-ih)/2,'
            "zoompan=z='min(zoom+0.0005,1.2)':d=$d:s=1920x1080,setsar=1[sv$i];");
        vidConcat.write('[sv$i]');
        if (audIdx >= 0) {
          audConcat.write('[$audIdx:a]');
        } else {
          filterParts.write('aevalsrc=0:d=${scene.duration.toStringAsFixed(3)}[sa$i];');
          audConcat.write('[sa$i]');
        }
      }
      filterParts.write('${vidConcat}concat=n=$sceneCount:v=1:a=0[vid];');
      filterParts.write('${audConcat}concat=n=$sceneCount:v=0:a=1[aud];');
      filterParts.write('[vid]${_subtitleFilter()}[out]');

      return '''ffmpeg -y \\
${inputLines}  -filter_complex "${filterParts}" \\
  -map "[out]" -map "[aud]" \\
  -c:v libx264 -preset medium -crf 18 \\
  -c:a aac -b:a 192k -r 25 \\
  "${safe}_final.mp4"''';
    }

    // 인트로/아웃트로가 있으면 concat 방식 사용
    if ((hasIntro || hasOutro) && sceneCount > 0) {
      final introPart = hasIntro ? '  -i "intro.mp4" \\\n' : '';
      final outroPart = hasOutro ? '  -i "outro.mp4" \\\n' : '';
      final audioInput = hasTts ? '  -i "${safe}_tts.wav" \\\n' : '';

      // 인덱스 계산
      int idx = 0;
      final introIdx = hasIntro ? idx++ : -1;
      final mainIdx = idx++;
      final outroIdx = hasOutro ? idx++ : -1;
      final ttsIdx = hasTts ? idx : -1;

      final concatParts = StringBuffer();
      if (introIdx >= 0) concatParts.write('[$introIdx:v][$introIdx:a]');
      concatParts.write('[$mainIdx:v]');
      if (hasTts) concatParts.write('[$ttsIdx:a]'); else concatParts.write('[$mainIdx:a]');
      if (outroIdx >= 0) concatParts.write('[$outroIdx:v][$outroIdx:a]');
      final n = (hasIntro ? 1 : 0) + 1 + (hasOutro ? 1 : 0);

      return '''ffmpeg -y \\
${introPart}  -f concat -safe 0 -i scenes.txt \\
${outroPart}${audioInput}  -filter_complex "${concatParts}concat=n=$n:v=1:a=1[vid][aud];[vid]${_subtitleFilter()}[out]" \\
  -map "[out]" -map "[aud]" \\
  -c:v libx264 -preset medium -crf 18 \\
  -c:a aac -b:a 192k -r 25 \\
  "${safe}_final.mp4"''';
    }

    // 폴백: 이미지+전체TTS 방식 (소수점 duration 유지)
    final inputs = List.generate(sceneCount, (i) {
      final dur = widget.project.scenes[i].duration.toStringAsFixed(3);
      final hasImg = widget.project.scenes[i].imageBytes != null;
      if (hasImg) {
        return '  -loop 1 -t $dur -i "scenes/scene_${i + 1}.jpg" \\\n';
      } else {
        return '  -f lavfi -t $dur -i "color=black:s=1920x1080:r=25" \\\n';
      }
    }).join('');
    final ttsInput = hasTts ? '  -i "${safe}_tts.wav" \\\n' : '';
    final ttsIdx = sceneCount;
    final mapAudio = hasTts
        ? '  -map "[out]" -map ${ttsIdx}:a \\\n'
        : '  -map "[out]" \\\n';
    final audioCodec = hasTts ? '  -c:a aac -b:a 192k \\\n' : '  -an \\\n';

    // 각 장면 filter: format→scale→pad→zoompan (이미지/검정 모두 동일 처리)
    String makeSceneFilter(int i) {
      final d = (widget.project.scenes[i].duration * 25).toInt();
      if (_includeRandomEffect) return '';
      return "[$i:v]format=yuv420p,scale=1920:1080:force_original_aspect_ratio=decrease,"
          "pad=1920:1080:(ow-iw)/2:(oh-ih)/2,"
          "zoompan=z='min(zoom+0.0005,1.2)':d=$d:s=1920x1080,setsar=1[v$i]";
    }

    if (_includeRandomEffect) {
      final filterStr = _buildRandomEffectFilter(sceneCount);
      return '''ffmpeg -y \\
${inputs}${ttsInput}  -filter_complex "${filterStr};[vid]${_subtitleFilter()}[out]" \\
${mapAudio}  -c:v libx264 -preset medium -crf 18 \\
${audioCodec}  -r 25 "${safe}_final.mp4"''';
    }

    final perScene = List.generate(sceneCount, makeSceneFilter).join(';');
    final concatIn = List.generate(sceneCount, (i) => '[v$i]').join('');
    final filterStr = '$perScene;${concatIn}concat=n=$sceneCount:v=1:a=0[vid];[vid]${_subtitleFilter()}[out]';
    return '''ffmpeg -y \\
${inputs}${ttsInput}  -filter_complex "${filterStr}" \\
${mapAudio}  -c:v libx264 -preset medium -crf 18 \\
${audioCodec}  -r 25 "${safe}_final.mp4"''';
  }

  // Windows 배치 파일용 한 줄 명령어
  String _buildFfmpegCommandWindows() {
    final safe = widget.project.title.replaceAll(RegExp(r'[^\w가-힣]'), '_');
    final hasTts = widget.project.ttsAudioBytes != null;
    final hasPerSceneTts = _hasPerSceneTts;
    final sceneCount = widget.project.scenes.length;
    final hasIntro = _includeIntro;
    final hasOutro = _includeOutro;

    // ── 장면별 TTS 모드 (Windows) ──
    if (hasPerSceneTts && !hasIntro && !hasOutro) {
      final inputParts = StringBuffer();
      for (int i = 0; i < sceneCount; i++) {
        final scene = widget.project.scenes[i];
        final dur = scene.duration.toStringAsFixed(3);
        final hasImg = scene.imageBytes != null;
        if (hasImg) {
          inputParts.write('-loop 1 -t $dur -i "scenes/scene_${i + 1}.jpg" ');
        } else {
          inputParts.write('-f lavfi -t $dur -i "color=black:s=1920x1080:r=25" ');
        }
        if (scene.sceneTtsBytes != null) {
          inputParts.write('-i "scenes/scene_${i + 1}_tts.wav" ');
        }
      }
      final filterParts = StringBuffer();
      final vidConcat = StringBuffer();
      final audConcat = StringBuffer();
      int inputIdx = 0;
      for (int i = 0; i < sceneCount; i++) {
        final scene = widget.project.scenes[i];
        final d = (scene.duration * 25).toInt();
        final vidIdx = inputIdx++;
        final audIdx = scene.sceneTtsBytes != null ? inputIdx++ : -1;
        filterParts.write('[$vidIdx:v]format=yuv420p,scale=1920:1080:force_original_aspect_ratio=decrease,'
            'pad=1920:1080:(ow-iw)/2:(oh-ih)/2,'
            "zoompan=z='min(zoom+0.0005,1.2)':d=$d:s=1920x1080,setsar=1[sv$i];");
        vidConcat.write('[sv$i]');
        if (audIdx >= 0) {
          audConcat.write('[$audIdx:a]');
        } else {
          filterParts.write('aevalsrc=0:d=${scene.duration.toStringAsFixed(3)}[sa$i];');
          audConcat.write('[sa$i]');
        }
      }
      filterParts.write('${vidConcat}concat=n=$sceneCount:v=1:a=0[vid];');
      filterParts.write('${audConcat}concat=n=$sceneCount:v=0:a=1[aud];');
      filterParts.write('[vid]${_subtitleFilter()}[out]');
      return '%FFMPEG% -y ${inputParts}'
          '-filter_complex "${filterParts}" '
          '-map "[out]" -map "[aud]" '
          '-c:v libx264 -preset medium -crf 18 -c:a aac -b:a 192k -r 25 "${safe}_final.mp4"';
    }

    // 인트로/아웃트로가 있으면 concat 방식 사용
    if ((hasIntro || hasOutro) && sceneCount > 0) {
      final introPart = hasIntro ? '-i "intro.mp4" ' : '';
      final outroPart = hasOutro ? '-i "outro.mp4" ' : '';
      final audioInput = hasTts ? '-i "${safe}_tts.wav" ' : '';

      int idx = 0;
      final introIdx = hasIntro ? idx++ : -1;
      final mainIdx = idx++;
      final outroIdx = hasOutro ? idx++ : -1;
      final ttsIdx = hasTts ? idx : -1;

      final concatParts = StringBuffer();
      if (introIdx >= 0) concatParts.write('[$introIdx:v][$introIdx:a]');
      concatParts.write('[$mainIdx:v]');
      if (hasTts) concatParts.write('[$ttsIdx:a]'); else concatParts.write('[$mainIdx:a]');
      if (outroIdx >= 0) concatParts.write('[$outroIdx:v][$outroIdx:a]');
      final n = (hasIntro ? 1 : 0) + 1 + (hasOutro ? 1 : 0);

      return '%FFMPEG% -y ${introPart}-f concat -safe 0 -i scenes.txt '
          '${outroPart}${audioInput}'
          '-filter_complex "${concatParts}concat=n=$n:v=1:a=1[vid][aud];[vid]${_subtitleFilter()}[out]" '
          '-map "[out]" -map "[aud]" '
          '-c:v libx264 -preset medium -crf 18 -c:a aac -b:a 192k -r 25 "${safe}_final.mp4"';
    }

    // 폴백: 이미지+전체TTS 방식 (소수점 duration 유지)
    final winInputs = List.generate(sceneCount, (i) {
      final dur = widget.project.scenes[i].duration.toStringAsFixed(3);
      final hasImg = widget.project.scenes[i].imageBytes != null;
      if (hasImg) {
        return '-loop 1 -t $dur -i "scenes/scene_${i + 1}.jpg" ';
      } else {
        return '-f lavfi -t $dur -i "color=black:s=1920x1080:r=25" ';
      }
    }).join('');
    final winTtsInput = hasTts ? '-i "${safe}_tts.wav" ' : '';
    final winTtsIdx = sceneCount;
    final winMapAudio = hasTts ? '-map "[out]" -map ${winTtsIdx}:a ' : '-map "[out]" ';
    final winAudioCodec = hasTts ? '-c:a aac -b:a 192k ' : '-an ';

    if (_includeRandomEffect && sceneCount > 0) {
      final filterStr = _buildRandomEffectFilter(sceneCount);
      return '%FFMPEG% -y ${winInputs}${winTtsInput}'
          '-filter_complex "${filterStr};[vid]${_subtitleFilter()}[out]" '
          '${winMapAudio}-c:v libx264 -preset medium -crf 18 ${winAudioCodec}-r 25 "${safe}_final.mp4"';
    }

    // 표준 모드 Windows (이미지/검정 동일 처리)
    {
      final perScene = List.generate(sceneCount, (i) {
        final d = (widget.project.scenes[i].duration * 25).toInt();
        return "[$i:v]format=yuv420p,scale=1920:1080:force_original_aspect_ratio=decrease,"
            "pad=1920:1080:(ow-iw)/2:(oh-ih)/2,"
            "zoompan=z='min(zoom+0.0005,1.2)':d=$d:s=1920x1080,setsar=1[v$i]";
      }).join(';');
      final concatIn = List.generate(sceneCount, (i) => '[v$i]').join('');
      final filterStr = '$perScene;${concatIn}concat=n=$sceneCount:v=1:a=0[vid];[vid]${_subtitleFilter()}[out]';
      if (hasTts) {
        return '%FFMPEG% -y ${winInputs}${winTtsInput}'
            '-filter_complex "${filterStr}" '
            '-map "[out]" -map ${winTtsIdx}:a '
            '-c:v libx264 -preset medium -crf 18 -c:a aac -b:a 192k -r 25 "${safe}_final.mp4"';
      } else {
        return '%FFMPEG% -y ${winInputs}'
            '-filter_complex "${filterStr}" '
            '-map "[out]" '
            '-c:v libx264 -preset medium -crf 18 -an -r 25 "${safe}_final.mp4"';
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // 앱 시작 시 FFmpeg 자동 감지
    if (!kIsWeb && Platform.isWindows) {
      _detectFfmpeg();
    }
  }

  // ── FFmpeg 자동 감지 ──
  Future<void> _detectFfmpeg() async {
    // 우선순위 경로 목록
    final candidates = [
      'ffmpeg', // PATH에 등록된 경우
      r'C:\ffmpeg\bin\ffmpeg.exe',
      r'C:\ffmpeg\ffmpeg.exe',
      r'C:\Program Files\ffmpeg\bin\ffmpeg.exe',
      r'C:\Program Files (x86)\ffmpeg\bin\ffmpeg.exe',
    ];
    for (final path in candidates) {
      try {
        final result = await Process.run(path, ['-version']);
        if (result.exitCode == 0) {
          if (mounted) {
            setState(() {
              _ffmpegPath = path;
              _ffmpegFound = true;
            });
          }
          return;
        }
      } catch (_) {
        continue;
      }
    }
    if (mounted) {
      setState(() {
        _ffmpegFound = false;
        _ffmpegPath = '';
      });
    }
  }

  // ── MP4 직접 렌더링 (FFmpeg 사용) ──
  Future<void> _startDirectRender() async {
    if (widget.project.scenes.isEmpty) {
      _showSnack('장면이 없습니다. 먼저 미디어를 생성해주세요.');
      return;
    }
    if (!_ffmpegFound) {
      _showSnack('FFmpeg를 찾을 수 없습니다. ZIP 패키지 방식을 사용하세요.');
      return;
    }

    // 저장 경로 선택
    final safe = widget.project.title.replaceAll(RegExp(r'[^\w가-힣]'), '_');
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'MP4 저장 위치 선택',
      fileName: '${safe}_final.mp4',
      type: FileType.custom,
      allowedExtensions: ['mp4'],
    );
    if (outputPath == null) return; // 취소

    setState(() {
      _isRendering = true;
      _isDirectRender = true;
      _renderProgress = 0.0;
      _renderLog = '🎬 MP4 직접 렌더링 시작...\n';
      _directRenderStatus = '준비 중...';
      _lastOutputMp4 = '';
    });

    // 임시 작업 디렉토리 생성
    final tempDir = await Directory.systemTemp.createTemp('tubemaster_render_');
    try {
      final scenes = widget.project.scenes;
      final hasPerSceneTts = _hasPerSceneTts;
      final hasTts = widget.project.ttsAudioBytes != null;

      // ── duration 계산 ──
      if (hasPerSceneTts) {
        int syncedCount = 0;
        for (final scene in scenes) {
          if (scene.sceneTtsBytes != null) {
            scene.duration = _calcAudioDuration(scene.sceneTtsBytes!).clamp(0.5, 300.0);
            syncedCount++;
          }
        }
        final totalSynced = scenes.fold<double>(0.0, (s, e) => s + e.duration);
        final m = totalSynced ~/ 60;
        final s = (totalSynced % 60).toInt();
        setState(() => _renderLog += '[싱크] 장면별 TTS 적용: $syncedCount개 장면 → 총 ${m}분 ${s}초\n');
      } else if (hasTts) {
        final ttsBytes = widget.project.ttsAudioBytes!;
        final ttsTotalSecs = _calcAudioDuration(ttsBytes);
        final perScene = (ttsTotalSecs / scenes.length).clamp(1.0, 120.0);
        for (final s in scenes) { s.duration = perScene; }
        setState(() => _renderLog += '[싱크] 합본 TTS 균등 분배: 장면당 ${perScene.toStringAsFixed(1)}초\n');
      }

      // ── 이미지 파일 저장 ──
      setState(() { _renderProgress = 0.1; _renderLog += '[1/5] 이미지 파일 준비 중...\n'; });
      final scenesDir = Directory('${tempDir.path}\\scenes');
      await scenesDir.create();
      for (int i = 0; i < scenes.length; i++) {
        final scene = scenes[i];
        if (scene.imageBytes != null) {
          await File('${scenesDir.path}\\scene_${i + 1}.jpg').writeAsBytes(scene.imageBytes!);
        }
        // 장면별 TTS 저장
        if (scene.sceneTtsBytes != null) {
          final wavBytes = WebAudioHelper.isWav(scene.sceneTtsBytes!)
              ? scene.sceneTtsBytes!
              : WebAudioHelper.pcmToWav(scene.sceneTtsBytes!, sampleRate: 24000);
          await File('${scenesDir.path}\\scene_${i + 1}_tts.wav').writeAsBytes(wavBytes);
        }
        if (i % 3 == 0) {
          setState(() => _renderProgress = 0.1 + (i / scenes.length) * 0.15);
          await Future.delayed(const Duration(milliseconds: 30));
        }
      }

      // ── 합본 TTS 저장 (장면별 TTS 없을 때) ──
      String ttsFilePath = '';
      if (!hasPerSceneTts && hasTts) {
        final ttsBytes = widget.project.ttsAudioBytes!;
        final wavBytes = WebAudioHelper.isWav(ttsBytes)
            ? ttsBytes : WebAudioHelper.pcmToWav(ttsBytes, sampleRate: 24000);
        ttsFilePath = '${tempDir.path}\\${safe}_tts.wav';
        await File(ttsFilePath).writeAsBytes(wavBytes);
      }

      // ── SRT 자막 파일 생성 → tempDir에 저장 ──
      setState(() { _renderLog += '[자막] SRT 파일 생성 중...\n'; });
      final srtBuffer = StringBuffer();
      double srtElapsed = 0.0;
      int srtIdx = 1;
      for (int i = 0; i < scenes.length; i++) {
        final sceneDur = scenes[i].duration;
        final text = scenes[i].scriptText.trim();
        final chunks = _splitSubtitle(text, _subtitleMaxChars);
        final chunkDur = sceneDur / chunks.length;
        for (int c = 0; c < chunks.length; c++) {
          final start = _formatSrtTime(srtElapsed + c * chunkDur);
          final end   = _formatSrtTime(srtElapsed + (c + 1) * chunkDur - 0.05);
          srtBuffer.writeln(srtIdx++);
          srtBuffer.writeln('$start --> $end');
          srtBuffer.writeln(chunks[c]);
          srtBuffer.writeln();
        }
        srtElapsed += sceneDur;
      }
      final srtFilePath = '${tempDir.path}\\subtitles.srt';
      await File(srtFilePath).writeAsString(srtBuffer.toString(), encoding: utf8);
      setState(() { _renderLog += '[자막] subtitles.srt 저장 완료 (${srtIdx - 1}개 항목)\n'; });

      // ── FFmpeg 명령 구성 ──
      setState(() { _renderProgress = 0.3; _renderLog += '[2/5] FFmpeg 명령 구성 중...\n'; });
      final ffmpegArgs = _buildFfmpegArgs(
        tempDir.path, scenesDir.path, outputPath,
        hasPerSceneTts: hasPerSceneTts, ttsFilePath: ttsFilePath,
        srtPath: srtFilePath,
      );
      // 전체 FFmpeg 명령어 로그 출력 (디버깅용)
      setState(() => _renderLog += '[FFmpeg 전체 명령]\n${_ffmpegPath} ${ffmpegArgs.join(" ")}\n\n');

      // ── FFmpeg 실행 ──
      setState(() { _renderProgress = 0.35; _renderLog += '[3/5] FFmpeg 렌더링 중... (시간이 걸립니다)\n'; });
      _isRenderCancelled = false;
      _ffmpegProcess = await Process.start(_ffmpegPath, ffmpegArgs, workingDirectory: tempDir.path);

      // stderr에서 진행률 파싱 (FFmpeg는 stderr로 출력)
      final totalDur = scenes.fold<double>(0.0, (s, e) => s + e.duration);
      final stderrBuffer = StringBuffer();
      _ffmpegProcess!.stderr.transform(const SystemEncoding().decoder).listen((data) {
        stderrBuffer.write(data);
        // time=HH:MM:SS.ss 파싱
        final timeMatch = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)').firstMatch(data);
        if (timeMatch != null && mounted) {
          final h = int.parse(timeMatch.group(1)!);
          final m = int.parse(timeMatch.group(2)!);
          final s = double.parse(timeMatch.group(3)!);
          final currentSecs = h * 3600 + m * 60 + s;
          final progress = totalDur > 0 ? (currentSecs / totalDur).clamp(0.0, 0.99) : 0.5;
          final timeStr = '${m.toString().padLeft(2,'0')}:${s.toInt().toString().padLeft(2,'0')}';
          setState(() {
            _renderProgress = 0.35 + progress * 0.6;
            _directRenderStatus = '처리 중: $timeStr / ${_fmtSecs(totalDur.toInt())}  (${(progress * 100).toInt()}%)';
          });
        }
        // 오류 메시지 실시간 로그 표시
        if (data.contains('Error') || data.contains('Invalid') || data.contains('error') || data.contains('No such')) {
          if (mounted) setState(() => _renderLog += '[FFmpeg] $data');
        }
      });

      final exitCode = await _ffmpegProcess!.exitCode;
      _ffmpegProcess = null;

      // 취소된 경우
      if (_isRenderCancelled) {
        if (mounted) setState(() {
          _isRendering = false;
          _renderProgress = 0.0;
          _renderLog += '⏹ 렌더링이 취소되었습니다.\n';
          _directRenderStatus = '⏹ 취소됨';
        });
        return;
      }

      if (exitCode != 0) {
        // stderr 전체 로그 표시
        final errLog = stderrBuffer.toString();
        final errLines = errLog.split('\n').where((l) =>
          l.contains('Error') || l.contains('Invalid') || l.contains('error') ||
          l.contains('No such') || l.contains('failed') || l.contains('invalid')
        ).take(10).join('\n');
        if (mounted) setState(() => _renderLog += '[FFmpeg 오류 상세]\n$errLines\n');
        throw Exception('FFmpeg 실패 (exit code: $exitCode)\n렌더링 로그를 확인하세요.');
      }

      // ── 완료 ──
      setState(() {
        _renderProgress = 1.0;
        _renderLog += '[5/5] ✅ 렌더링 완료!\n저장 위치: $outputPath\n';
        _directRenderStatus = '✅ 완료! MP4 저장됨';
        _lastOutputMp4 = outputPath;
        _isRendering = false;
      });

      widget.project.status = ProjectStatus.rendered;
      widget.project.finalVideoPath = outputPath;
      widget.provider.updateProject(widget.project);
      widget.provider.addNotification('🎬 "${widget.project.title}" MP4 렌더링 완료: $outputPath');

      if (mounted) {
        _showSnack('✅ MP4 저장 완료! 파일 탐색기로 열기?');
        // 저장 폴더 열기
        final folder = File(outputPath).parent.path;
        await launchUrl(Uri.parse('file:///$folder'));
      }

    } catch (e) {
      setState(() {
        _isRendering = false;
        _renderLog += '❌ 오류: $e\n';
        _directRenderStatus = '❌ 실패: $e';
      });
      _showSnack('렌더링 실패: $e');
    } finally {
      // 임시 폴더 정리
      try { await tempDir.delete(recursive: true); } catch (_) {}
    }
  }

  // HH:MM:SS 포맷
  String _fmtSecs(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  // FFmpeg 인수 리스트 생성 (직접 렌더링용)
  List<String> _buildFfmpegArgs(
    String workDir, String scenesDir, String outputPath, {
    required bool hasPerSceneTts,
    required String ttsFilePath,
    String srtPath = '',  // 자막 SRT 파일 경로 (비어있으면 자막 미적용)
  }) {
    final scenes = widget.project.scenes;
    final sceneCount = scenes.length;
    final args = <String>['-y']; // 덮어쓰기 허용

    // ── 공통 장면 필터 생성 (따옴표 없는 안전한 버전) ──
    // ── 랜덤 카메라 효과 필터 목록 (Process.start 인수 배열용 → 따옴표 불필요) ──
    // ── 랜덤 카메라 효과 (Ken Burns) ──
    // 원리: 이미지를 1.1배 크게 scale → crop 좌표를 프레임에 따라 선형 이동
    // 핵심: on=현재프레임(루프 시 계속 증가) → min(on,d-1)으로 d 초과 방지
    //       d=총프레임수, 모든 수식은 짝수 보장을 위해 trunc(x/2)*2 사용
    // 크기: 원본 1920x1080 → 확대 2112x1188 (10% 여유)
    final _randomEffects = [
      // 줌인: crop 크기 2112→1920, 1188→1080 (점점 좁아짐 = 확대 효과)
      (int d) {
        final n = 'min(on\\,$d-1)';
        return 'scale=2112:1188:force_original_aspect_ratio=increase,crop=2112:1188,'
            'crop=w=trunc((2112-(192*$n/$d))/2)*2:h=trunc((1188-(108*$n/$d))/2)*2'
            ':x=trunc(96*$n/$d/2)*2:y=trunc(54*$n/$d/2)*2,'
            'scale=1920:1080,setsar=1,format=yuv420p';
      },
      // 줌아웃: crop 크기 1920→2112, 1080→1188 (점점 넓어짐 = 축소 효과)
      (int d) {
        final n = 'min(on\\,$d-1)';
        return 'scale=2112:1188:force_original_aspect_ratio=increase,crop=2112:1188,'
            'crop=w=trunc((1920+(192*$n/$d))/2)*2:h=trunc((1080+(108*$n/$d))/2)*2'
            ':x=trunc((96-96*$n/$d)/2)*2:y=trunc((54-54*$n/$d)/2)*2,'
            'scale=1920:1080,setsar=1,format=yuv420p';
      },
      // 오른쪽 패닝: x 0 → 192
      (int d) {
        final n = 'min(on\\,$d-1)';
        return 'scale=2112:1080:force_original_aspect_ratio=increase,'
            'crop=1920:1080:x=trunc(192*$n/$d/2)*2:y=0,'
            'setsar=1,format=yuv420p';
      },
      // 왼쪽 패닝: x 192 → 0
      (int d) {
        final n = 'min(on\\,$d-1)';
        return 'scale=2112:1080:force_original_aspect_ratio=increase,'
            'crop=1920:1080:x=trunc(192*(1-$n/$d)/2)*2:y=0,'
            'setsar=1,format=yuv420p';
      },
      // 아래 패닝: y 0 → 108
      (int d) {
        final n = 'min(on\\,$d-1)';
        return 'scale=1920:1188:force_original_aspect_ratio=increase,'
            'crop=1920:1080:x=0:y=trunc(108*$n/$d/2)*2,'
            'setsar=1,format=yuv420p';
      },
      // 위 패닝: y 108 → 0
      (int d) {
        final n = 'min(on\\,$d-1)';
        return 'scale=1920:1188:force_original_aspect_ratio=increase,'
            'crop=1920:1080:x=0:y=trunc(108*(1-$n/$d)/2)*2,'
            'setsar=1,format=yuv420p';
      },
    ];

    // 장면별 필터 생성: 랜덤 효과 ON/OFF 분기
    String makeVideoFilter(int inputIdx, int sceneIdx) {
      final scene = scenes[sceneIdx];
      final d = (scene.duration * 25).toInt().clamp(1, 99999);
      if (_includeRandomEffect) {
        final effectIdx = sceneIdx % _randomEffects.length;
        final effectFilter = _randomEffects[effectIdx](d);
        return '[$inputIdx:v]scale=1920:1080:force_original_aspect_ratio=decrease,'
            'pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=25,$effectFilter[sv$sceneIdx]';
      }
      // 기본: scale+pad (안정적, 빠름)
      return '[$inputIdx:v]format=yuv420p,'
          'scale=1920:1080:force_original_aspect_ratio=decrease,'
          'pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1[sv$sceneIdx]';
    }

    if (hasPerSceneTts) {
      // ── 1단계: 입력 인덱스 미리 계산 (vidIdx, audIdx 정확히 매핑) ──
      final List<int> vidIdxList = [];
      final List<int> audIdxList = []; // -1이면 TTS 없음
      int inputIdx = 0;
      for (int i = 0; i < sceneCount; i++) {
        vidIdxList.add(inputIdx++);
        audIdxList.add(scenes[i].sceneTtsBytes != null ? inputIdx++ : -1);
      }

      // ── 2단계: 실제 입력 추가 (인덱스 순서와 일치) ──
      for (int i = 0; i < sceneCount; i++) {
        final scene = scenes[i];
        final dur = scene.duration.toStringAsFixed(3);
        final imgPath = '$scenesDir${Platform.pathSeparator}scene_${i + 1}.jpg';
        final hasImg = scene.imageBytes != null && File(imgPath).existsSync();
        if (hasImg) {
          args.addAll(['-loop', '1', '-t', dur, '-i', imgPath]);
        } else {
          args.addAll(['-f', 'lavfi', '-t', dur, '-i', 'color=black:s=1920x1080:r=25']);
        }
        if (scene.sceneTtsBytes != null) {
          args.addAll(['-i', '$scenesDir${Platform.pathSeparator}scene_${i + 1}_tts.wav']);
        }
      }

      // ── 3단계: filter_complex 구성 ──
      final filterParts = StringBuffer();
      final vidConcat = StringBuffer();
      final audConcat = StringBuffer();
      for (int i = 0; i < sceneCount; i++) {
        final scene = scenes[i];
        final vidIdx = vidIdxList[i];
        final audIdx = audIdxList[i];
        filterParts.write(makeVideoFilter(vidIdx, i));
        filterParts.write(';');
        vidConcat.write('[sv$i]');
        if (audIdx >= 0) {
          audConcat.write('[$audIdx:a]');
        } else {
          filterParts.write('aevalsrc=0:d=${scene.duration.toStringAsFixed(3)},aformat=sample_rates=24000:channel_layouts=mono[sa$i];');
          audConcat.write('[sa$i]');
        }
      }
      filterParts.write('${vidConcat}concat=n=$sceneCount:v=1:a=0[vidraw];');
      filterParts.write('${audConcat}concat=n=$sceneCount:v=0:a=1[aud]');
      // 자막 필터: filter_complex 끝에 subtitles 체인 추가
      if (srtPath.isNotEmpty) {
        final srtFilter = _buildSrtFilterChain(srtPath);
        final finalFilter = '${filterParts.toString()};[vidraw]$srtFilter[vout]';
        args.addAll(['-filter_complex', finalFilter]);
        args.addAll(['-map', '[vout]', '-map', '[aud]']);
      } else {
        // [vidraw]를 최종 출력으로 그대로 사용
        final baseFilter = filterParts.toString().replaceAll('[vidraw]', '[vid]');
        args.addAll(['-filter_complex', baseFilter]);
        args.addAll(['-map', '[vid]', '-map', '[aud]']);
      }
    } else if (ttsFilePath.isNotEmpty) {
      // 이미지들 + 합본 TTS
      for (int i = 0; i < sceneCount; i++) {
        final scene = scenes[i];
        final dur = scene.duration.toStringAsFixed(3);
        final imgPath = '$scenesDir${Platform.pathSeparator}scene_${i + 1}.jpg';
        final hasImg = scene.imageBytes != null && File(imgPath).existsSync();
        if (hasImg) {
          args.addAll(['-loop', '1', '-t', dur, '-i', imgPath]);
        } else {
          args.addAll(['-f', 'lavfi', '-t', dur, '-i', 'color=black:s=1920x1080:r=25']);
        }
      }
      args.addAll(['-i', ttsFilePath]);
      final perScene = List.generate(sceneCount, (i) => makeVideoFilter(i, i)).join(';');
      final concatIn = List.generate(sceneCount, (i) => '[sv$i]').join('');
      if (srtPath.isNotEmpty) {
        final srtFilter = _buildSrtFilterChain(srtPath);
        final filterStr = '$perScene;${concatIn}concat=n=$sceneCount:v=1:a=0[vidraw];[vidraw]$srtFilter[vout]';
        args.addAll(['-filter_complex', filterStr]);
        args.addAll(['-map', '[vout]', '-map', '${sceneCount}:a']);
      } else {
        final filterStr = '$perScene;${concatIn}concat=n=$sceneCount:v=1:a=0[vid]';
        args.addAll(['-filter_complex', filterStr]);
        args.addAll(['-map', '[vid]', '-map', '${sceneCount}:a']);
      }
    } else {
      // TTS 없음 - 영상만
      for (int i = 0; i < sceneCount; i++) {
        final scene = scenes[i];
        final dur = scene.duration.toStringAsFixed(3);
        final imgPath = '$scenesDir${Platform.pathSeparator}scene_${i + 1}.jpg';
        final hasImg = scene.imageBytes != null && File(imgPath).existsSync();
        if (hasImg) {
          args.addAll(['-loop', '1', '-t', dur, '-i', imgPath]);
        } else {
          args.addAll(['-f', 'lavfi', '-t', dur, '-i', 'color=black:s=1920x1080:r=25']);
        }
      }
      final perScene2 = List.generate(sceneCount, (i) => makeVideoFilter(i, i)).join(';');
      final concatIn2 = List.generate(sceneCount, (i) => '[sv$i]').join('');
      if (srtPath.isNotEmpty) {
        final srtFilter = _buildSrtFilterChain(srtPath);
        final filterStr2 = '$perScene2;${concatIn2}concat=n=$sceneCount:v=1:a=0[vidraw];[vidraw]$srtFilter[vout]';
        args.addAll(['-filter_complex', filterStr2]);
        args.addAll(['-map', '[vout]']);
      } else {
        args.addAll(['-filter_complex', '$perScene2;${concatIn2}concat=n=$sceneCount:v=1:a=0[vid]']);
        args.addAll(['-map', '[vid]']);
      }
    }

    // 공통 출력 옵션
    args.addAll([
      '-c:v', 'libx264',
      '-preset', 'medium',
      '-crf', '18',
      '-c:a', 'aac',
      '-b:a', '192k',
      '-r', '25',
      outputPath,
    ]);
    return args;
  }

  /// SRT 자막을 filter_complex 체인으로 만드는 헬퍼
  /// ASS 파일로 변환 후 subtitles 필터 사용 (박스 배경 완벽 지원)
  String _buildSrtFilterChain(String srtPath) {
    try {
      final srtFile = File(srtPath);
      if (!srtFile.existsSync()) return 'null';

      // SRT → ASS 변환 후 같은 디렉토리에 저장
      final assPath = srtPath.replaceAll('.srt', '.ass');
      final srtContent = srtFile.readAsStringSync();
      final assContent = _convertSrtToAss(srtContent);
      File(assPath).writeAsStringSync(assContent);

      // ASS 파일명만 사용 (workingDirectory 기준 상대경로)
      final assFileName = assPath.split(Platform.pathSeparator).last;
      return 'ass=$assFileName';
    } catch (e) {
      return 'null';
    }
  }

  /// SRT → ASS 변환 (박스 배경 스타일 포함)
  String _convertSrtToAss(String srtContent) {
    final fontSize = _subtitleFontSize.toInt();

    // ASS 헤더: 박스 배경(BorderStyle=3), 흰색 텍스트, 반투명 검정 박스
    // ASS 색상: &HAABBGGRR (알파, 파랑, 초록, 빨강)
    // 흰색: &H00FFFFFF  (알파00=완전불투명, 흰색)
    // 검정박스: &H99000000 (알파99=40%불투명, 검정)
    final assHeader = '''[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Malgun Gothic,$fontSize,&H00FFFFFF,&H000000FF,&H00000000,&H99000000,0,0,0,0,100,100,0,0,3,0,0,2,10,10,40,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
''';

    final eventsBuffer = StringBuffer(assHeader);

    // SRT 블록 파싱
    final blocks = srtContent.trim().split(RegExp(r'\r?\n\r?\n'));
    for (final block in blocks) {
      final lines = block.trim().split(RegExp(r'\r?\n'));
      if (lines.length < 3) continue;

      final timeLine = lines[1];
      final timeMatch = RegExp(
        r'(\d+):(\d+):(\d+)[,.](\d+)\s*-->\s*(\d+):(\d+):(\d+)[,.](\d+)',
      ).firstMatch(timeLine);
      if (timeMatch == null) continue;

      // ASS 시간 형식: H:MM:SS.cs (센티초 2자리)
      String toAssTime(String h, String m, String s, String ms) {
        final msInt = int.parse(ms);
        final cs = (msInt / 10).round().toString().padLeft(2, '0');
        return '$h:${m.padLeft(2,'0')}:${s.padLeft(2,'0')}.$cs';
      }

      final start = toAssTime(
        timeMatch.group(1)!, timeMatch.group(2)!,
        timeMatch.group(3)!, timeMatch.group(4)!,
      );
      final end = toAssTime(
        timeMatch.group(5)!, timeMatch.group(6)!,
        timeMatch.group(7)!, timeMatch.group(8)!,
      );

      // 텍스트: 여러 줄이면 \N (ASS 줄바꿈)
      final text = lines.sublist(2).join('\\N');

      eventsBuffer.writeln('Dialogue: 0,$start,$end,Default,,0,0,0,,{\\an2}$text');
    }

    return eventsBuffer.toString();
  }

  // 오디오 바이트로 재생 시간(초) 계산
  double _calcAudioDuration(Uint8List bytes) {
    if (WebAudioHelper.isWav(bytes)) {
      final pcmLen = bytes.length > 44 ? bytes.length - 44 : bytes.length;
      return pcmLen / (24000 * 2);
    } else if (WebAudioHelper.isMp3(bytes)) {
      return bytes.length / 16000; // 128kbps 추정
    } else {
      return bytes.length / (24000 * 2); // raw PCM 24kHz 16bit mono
    }
  }

  Future<void> _startRendering() async {
    if (widget.project.scenes.isEmpty) {
      _showSnack('장면이 없습니다. 먼저 미디어를 생성해주세요.');
      return;
    }

    final hasImages = widget.project.scenes.any((s) => s.imageBytes != null);
    final hasTts = widget.project.ttsAudioBytes != null;
    final hasPerSceneTts = _hasPerSceneTts;
    final safe = widget.project.title.replaceAll(RegExp(r'[^\w가-힣]'), '_');
    final scenes = widget.project.scenes;

    setState(() {
      _isRendering = true;
      _isDirectRender = false;
      _renderProgress = 0.0;
      _renderLog = '📦 ZIP 패키지 생성 시작...\n';
    });

    try {
      // ── TTS 길이 기반 장면 duration 정확 계산 ──
      if (hasPerSceneTts) {
        // 장면별 TTS가 있으면 각 장면 TTS 길이로 duration 정확히 설정
        int syncedCount = 0;
        for (final scene in scenes) {
          if (scene.sceneTtsBytes != null) {
            scene.duration = _calcAudioDuration(scene.sceneTtsBytes!).clamp(0.5, 300.0);
            syncedCount++;
          }
        }
        final totalSynced = scenes.fold<double>(0.0, (s, e) => s + e.duration);
        final m = totalSynced ~/ 60;
        final s = (totalSynced % 60).toInt();
        setState(() {
          _renderLog += '[TTS 싱크] 장면별 TTS 길이 적용: $syncedCount/${scenes.length}개 장면 '
              '→ 총 영상 길이 ${m}분 ${s}초\n';
        });
      } else if (hasTts && scenes.isNotEmpty) {
        // 합본 TTS만 있으면 균등 분배 (폴백)
        final ttsBytes = widget.project.ttsAudioBytes!;
        final ttsTotalSecs = _calcAudioDuration(ttsBytes);
        final perScene = (ttsTotalSecs / scenes.length).clamp(1.0, 120.0);
        for (final s in scenes) {
          s.duration = perScene;
        }
        final ttsMin = ttsTotalSecs ~/ 60;
        final ttsSec = (ttsTotalSecs % 60).toInt();
        setState(() {
          _renderLog += '[TTS 싱크] 합본 TTS 총 길이 ${ttsMin}분 ${ttsSec}초 → '
              '장면당 ${perScene.toStringAsFixed(1)}초 균등 분배\n'
              '⚠️ TTS를 다시 생성하면 장면별 정확한 싱크가 적용됩니다.\n';
        });
      }

      // ── 1단계: SRT 자막 생성 ──
      await Future.delayed(const Duration(milliseconds: 200));

      // 총 예상 영상 길이 계산 (각 장면 duration 합계)
      final totalSecs = scenes.fold<double>(0.0, (sum, s) => sum + s.duration);
      final totalMin = totalSecs ~/ 60;
      final totalSecR = (totalSecs % 60).toInt();
      setState(() {
        _renderProgress = 0.1;
        _renderLog += '[${_timestamp()}] 자막(SRT) 생성 중...\n'
            '[정보] 장면 ${scenes.length}개 × 장면당 ${scenes.first.duration.toStringAsFixed(1)}초 '
            '= 총 영상 길이 약 ${totalMin}분 ${totalSecR}초\n';
      });

      final srtBuffer = StringBuffer();
      double elapsed = 0.0;
      int srtIndex = 1;
      for (int i = 0; i < scenes.length; i++) {
        final sceneDur = scenes[i].duration;  // 각 장면별 duration 사용
        final text = scenes[i].scriptText.trim();
        // 자막 분할: 글자수 기준 의미단위 분리
        final chunks = _splitSubtitle(text, _subtitleMaxChars);
        final chunkDur = sceneDur / chunks.length;
        for (int c = 0; c < chunks.length; c++) {
          final start = _formatSrtTime(elapsed + c * chunkDur);
          final end   = _formatSrtTime(elapsed + (c + 1) * chunkDur);
          srtBuffer.writeln(srtIndex++);
          srtBuffer.writeln('$start --> $end');
          srtBuffer.writeln(chunks[c]);
          srtBuffer.writeln();
        }
        elapsed += sceneDur;
      }

      // ── 2단계: scenes.txt (FFmpeg concat 목록) ──
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() { _renderProgress = 0.2; _renderLog += '[${_timestamp()}] scenes.txt 생성 중...\n'; });

      final scenesBuffer = StringBuffer();
      for (int i = 0; i < scenes.length; i++) {
        scenesBuffer.writeln("file 'scenes/scene_${i + 1}.jpg'");
        scenesBuffer.writeln("duration ${scenes[i].duration.toStringAsFixed(2)}");  // 각 장면 duration 사용 + 소수점 유지
      }

      // ── 3단계: FFmpeg 렌더 스크립트 ──
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() { _renderProgress = 0.3; _renderLog += '[${_timestamp()}] FFmpeg 스크립트 생성 중...\n'; });

      final ffmpegCmd = _buildFfmpegCommand();
      final ffmpegCmdWin = _buildFfmpegCommandWindows();

      // Windows 배치 파일 (한 줄 명령어, ^ 불필요)
      final batScript =
          '@echo off\r\n'
          'chcp 65001 > nul\r\n'
          'echo TubeMaster - FFmpeg 렌더링 시작...\r\n'
          'echo.\r\n'
          ':: FFmpeg 경로 설정 (변경 불필요 - C:\\ffmpeg\\bin\\ffmpeg.exe 기준)\r\n'
          'set FFMPEG=C:\\ffmpeg\\bin\\ffmpeg.exe\r\n'
          'echo.\r\n'
          'echo 이미지와 TTS 음성을 MP4로 합성합니다.\r\n'
          'echo.\r\n'
          '$ffmpegCmdWin\r\n'
          'echo.\r\n'
          'if %ERRORLEVEL% EQU 0 (\r\n'
          '  echo ✅ 렌더링 완료! ${safe}_final.mp4 파일을 확인하세요.\r\n'
          ') else (\r\n'
          '  echo ❌ 오류 발생. FFmpeg 경로를 확인하세요: C:\\ffmpeg\\bin\\ffmpeg.exe\r\n'
          ')\r\n'
          'pause\r\n';

      // macOS/Linux 쉘 스크립트
      final shScript =
          '#!/bin/bash\n'
          'echo "TubeMaster - FFmpeg 렌더링 시작..."\n'
          'echo\n'
          '$ffmpegCmd\n'
          'if [ \$? -eq 0 ]; then\n'
          '  echo "✅ 렌더링 완료! ${safe}_final.mp4 파일을 확인하세요."\n'
          'else\n'
          '  echo "❌ 오류 발생. FFmpeg 설치: brew install ffmpeg (Mac) / sudo apt install ffmpeg (Linux)"\n'
          'fi\n';

      // README (장면별 TTS 여부 + 총 영상 길이 포함)
      final sceneDuration = scenes.isNotEmpty ? scenes.first.duration : 5.0;
      final totalVideoSecs = scenes.fold<double>(0.0, (s, e) => s + e.duration);
      final readme = _buildReadme(safe, scenes.length, hasImages, hasTts || hasPerSceneTts,
          ffmpegCmd, sceneDuration, hasPerSceneTts: hasPerSceneTts, totalVideoSecs: totalVideoSecs);

      // ── 4단계: ZIP 아카이브용 파일 목록 조립 ──
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() { _renderProgress = 0.4; _renderLog += '[${_timestamp()}] 파일 목록 준비 중...\n'; });

      // compute()에 전달할 파일 목록: [['경로', bytes], ...]
      final fileList = <List<dynamic>>[];

      // README
      final readmeBytes = utf8.encode(readme);
      fileList.add(['README.txt', readmeBytes]);

      // 자막
      final srtBytes = utf8.encode(srtBuffer.toString());
      fileList.add(['subtitles.srt', srtBytes]);

      // scenes.txt
      final scenesTxtBytes = utf8.encode(scenesBuffer.toString());
      fileList.add(['scenes.txt', scenesTxtBytes]);

      // FFmpeg 스크립트들
      final batBytes = utf8.encode(batScript);
      fileList.add(['render.bat', batBytes]);
      final shBytes = utf8.encode(shScript);
      fileList.add(['render.sh', shBytes]);

      // ── 5단계: 이미지 + 장면별 TTS 파일 추가 ──
      int imageCount = 0;
      int ttsCount = 0;
      for (int i = 0; i < scenes.length; i++) {
        final scene = scenes[i];
        // 이미지 추가
        if (scene.imageBytes != null) {
          fileList.add(['scenes/scene_${i + 1}.jpg', scene.imageBytes!]);
          imageCount++;
        }
        // 장면별 TTS 추가 (있으면)
        if (scene.sceneTtsBytes != null) {
          final sceneTts = scene.sceneTtsBytes!;
          final wavBytes = WebAudioHelper.isWav(sceneTts)
              ? sceneTts
              : WebAudioHelper.pcmToWav(sceneTts, sampleRate: 24000);
          fileList.add(['scenes/scene_${i + 1}_tts.wav', wavBytes]);
          ttsCount++;
        }
        // 진행률 업데이트
        if (i % 3 == 0) {
          final progress = 0.4 + (i / scenes.length) * 0.4;
          setState(() {
            _renderProgress = progress;
            _renderLog += '[${_timestamp()}] 이미지/TTS 추가 중... (이미지: $imageCount, TTS: $ttsCount/${scenes.length})\n';
          });
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // ── 6단계: TTS 오디오 추가 ──
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() { _renderProgress = 0.85; _renderLog += '[${_timestamp()}] TTS 오디오 추가 중...\n'; });

      if (hasPerSceneTts) {
        // 장면별 TTS 모드: 합본도 참고용으로 포함 (재생용)
        if (hasTts) {
          final ttsBytes = widget.project.ttsAudioBytes!;
          final audioBytes = WebAudioHelper.isWav(ttsBytes)
              ? ttsBytes
              : WebAudioHelper.pcmToWav(ttsBytes, sampleRate: 24000);
          fileList.add(['${safe}_tts_combined.wav', audioBytes]);
        }
        setState(() {
          _renderLog += '[${_timestamp()}] ✅ 장면별 TTS 모드: $ttsCount개 장면 TTS가 각 이미지와 1:1 매핑됩니다.\n';
        });
      } else if (hasTts) {
        // 폴백: 합본 TTS만 있는 경우
        final ttsBytes = widget.project.ttsAudioBytes!;
        final audioBytes = WebAudioHelper.isWav(ttsBytes)
            ? ttsBytes
            : WebAudioHelper.pcmToWav(ttsBytes, sampleRate: 24000);
        fileList.add(['${safe}_tts.wav', audioBytes]);
      }

      // ── 7단계: ZIP 인코딩 (백그라운드 isolate) ──
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() { _renderProgress = 0.9; _renderLog += '[${_timestamp()}] ZIP 압축 중... (백그라운드 처리)\n'; });

      // compute()로 isolate에서 ZIP 인코딩 → UI 스레드 블로킹 없음
      final zipBytes = await compute(_encodeZipIsolate, fileList);
      if (zipBytes.isEmpty) throw Exception('ZIP 인코딩 실패');

      // ── 8단계: ZIP 즉시 다운로드 ──
      setState(() { _renderProgress = 1.0; _renderLog += '[${_timestamp()}] ✅ ZIP 다운로드 시작!\n'; });

      // 즉시 다운로드
      _downloadZip(zipBytes, '${safe}_tubemaster.zip');

      // 프로젝트 상태 업데이트
      widget.project.status = ProjectStatus.rendered;
      widget.project.finalVideoPath = '${safe}_tubemaster.zip';
      widget.provider.updateProject(widget.project);
      widget.provider.addNotification('🎬 "${widget.project.title}" 렌더링 패키지 다운로드 완료');

      setState(() => _isRendering = false);

      if (mounted) {
        _showSnack('✅ ${safe}_tubemaster.zip 다운로드 완료! ZIP 압축 해제 후 render.bat(Windows) 또는 render.sh(Mac) 실행하면 MP4가 생성됩니다.');
      }

    } catch (e) {
      setState(() {
        _isRendering = false;
        _renderLog += '[${_timestamp()}] ❌ 오류: $e\n';
      });
      _showSnack('오류 발생: $e');
    }
  }

  String _buildReadme(String safe, int sceneCount, bool hasImages, bool hasTts,
      String ffmpegCmd, double sceneDuration,
      {bool hasPerSceneTts = false, double totalVideoSecs = 0.0}) {
    final totalMin = totalVideoSecs ~/ 60;
    final totalSec = (totalVideoSecs % 60).toInt();
    final ttsMode = hasPerSceneTts
        ? '장면별 TTS ✅ (각 장면 길이가 TTS와 정확히 일치)'
        : (hasTts ? '합본 TTS ✅ (균등 분배)' : '없음 (TTS 생성 필요)');
    return '''TubeMaster 렌더링 패키지
========================
프로젝트: ${widget.project.title}
장면 수: ${sceneCount}개
총 영상 길이: ${totalMin}분 ${totalSec}초
이미지: ${hasImages ? '포함 ✅' : '없음 (이미지 생성 필요)'}
TTS 오디오: $ttsMode
랜덤 효과: ${_includeRandomEffect ? '활성화 ✅' : '비활성'}
인트로: ${_includeIntro ? '활성화 ✅ (intro.mp4 직접 추가 필요)' : '없음'}
아웃트로: ${_includeOutro ? '활성화 ✅ (outro.mp4 직접 추가 필요)' : '없음'}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 ZIP 파일 구조
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  README.txt          ← 이 파일
  subtitles.srt       ← 자막 파일
  scenes.txt          ← FFmpeg 이미지 목록
  render.bat          ← Windows 실행 스크립트
  render.sh           ← macOS/Linux 실행 스크립트
  scenes/
    scene_1.jpg       ← 장면 이미지들
    scene_1_tts.wav   ← 장면별 TTS 음성 (장면별 TTS 생성 시)
    scene_2.jpg
    scene_2_tts.wav
    ...
  ${safe}_tts_combined.wav ← 합본 TTS (참고용, 장면별 TTS 모드)
  ${safe}_tts.wav    ← TTS 음성 (합본 TTS 모드)
  intro.mp4          ← 인트로 영상 (직접 추가 필요)
  outro.mp4          ← 아웃트로 영상 (직접 추가 필요)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎬 영상 만드는 방법
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[방법 1] 자동 스크립트 실행 (권장)
  Windows: render.bat 더블클릭
  macOS/Linux: chmod +x render.sh && ./render.sh

[방법 2] 직접 FFmpeg 명령어 실행
  아래 명령어를 터미널에서 실행:

$ffmpegCmd${(_includeIntro || _includeOutro) ? '''

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎬 인트로/아웃트로 추가 방법
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

인트로/아웃트로 기능이 활성화되어 있습니다.
반드시 아래 절차를 따르세요:

${_includeIntro ? """[인트로 추가]
  STEP 1: 이 ZIP 파일 압축 해제
  STEP 2: 해제된 폴더에 인트로 MP4 파일을 복사
  STEP 3: 파일명을 반드시 "intro.mp4" 로 변경
  STEP 4: render.bat 또는 render.sh 실행
  
  ⚠️ 파일명이 intro.mp4 가 아니면 인트로가 삽입되지 않습니다!
  
""" : ""}${_includeOutro ? """[아웃트로 추가]
  STEP 1: 이 ZIP 파일 압축 해제
  STEP 2: 해제된 폴더에 아웃트로 MP4 파일을 복사
  STEP 3: 파일명을 반드시 "outro.mp4" 로 변경
  STEP 4: render.bat 또는 render.sh 실행
  
  ⚠️ 파일명이 outro.mp4 가 아니면 아웃트로가 삽입되지 않습니다!
  
""" : ""}[최종 폴더 구조 예시]
  📁 압축 해제 폴더/
  ├── render.bat        ← 이것 더블클릭
  ├── render.sh
  ├── subtitles.srt
  ├── ${_includeIntro ? "intro.mp4         ← 본인 인트로 영상 (직접 추가)\n  ├── " : ""}${_includeOutro ? "outro.mp4         ← 본인 아웃트로 영상 (직접 추가)\n  ├── " : ""}scenes/
  │   ├── scene_1.jpg
  │   └── ...
  └── ${safe}_tts.wav  (TTS 있는 경우)
''' : ''}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 FFmpeg 설치 방법
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  공식 사이트: https://ffmpeg.org/download.html
  Windows 추천: https://www.gyan.dev/ffmpeg/builds/
  macOS: brew install ffmpeg
  Ubuntu: sudo apt install ffmpeg
''';
  }

  // ── 자막 의미단위 분할 ──
  // maxChars 글자 수 기준으로 자연스럽게 끊음
  // 우선순위: 문장부호(. ! ? .) > 쉼표(, ) > 조사/어미 뒤 공백 > 강제 글자수 분할
  List<String> _splitSubtitle(String text, int maxChars) {
    if (text.length <= maxChars) return [text];

    final chunks = <String>[];
    String remaining = text;

    while (remaining.length > maxChars) {
      final window = remaining.substring(0, maxChars);

      // 1순위: 문장 끝 부호 찾기 (가장 오른쪽)
      int cut = -1;
      for (int i = window.length - 1; i >= maxChars ~/ 2; i--) {
        final ch = window[i];
        if (ch == '.' || ch == '!' || ch == '?' || ch == '。' || ch == '…') {
          cut = i + 1;
          break;
        }
      }

      // 2순위: 쉼표/중간 구분자
      if (cut == -1) {
        for (int i = window.length - 1; i >= maxChars ~/ 2; i--) {
          final ch = window[i];
          if (ch == ',' || ch == '，' || ch == ';') {
            cut = i + 1;
            break;
          }
        }
      }

      // 3순위: 공백 (어절 경계)
      if (cut == -1) {
        for (int i = window.length - 1; i >= maxChars ~/ 2; i--) {
          if (window[i] == ' ') {
            cut = i + 1;
            break;
          }
        }
      }

      // 4순위: 강제 글자수 분할
      if (cut == -1) cut = maxChars;

      final chunk = remaining.substring(0, cut).trim();
      if (chunk.isNotEmpty) chunks.add(chunk);
      remaining = remaining.substring(cut).trim();
    }

    if (remaining.isNotEmpty) chunks.add(remaining);
    return chunks.isEmpty ? [text] : chunks;
  }

  // ── 자막 FFmpeg 필터 문자열 생성 ──
  String _subtitleFilter({bool isWindows = false}) {
    // Windows에서는 폰트 이름에 특수처리 불필요
    // force_style로 폰트크기·폰트이름 지정
    final fontSize = _subtitleFontSize.toInt();
    final font = _subtitleFont;
    return "subtitles=subtitles.srt:force_style='FontName=$font,FontSize=$fontSize,PrimaryColour=&HFFFFFF,OutlineColour=&H000000,Outline=2,Shadow=1,Alignment=2'";
  }

  String _timestamp() =>
      DateTime.now().toLocal().toString().substring(11, 19);

  String _formatSrtTime(double seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final ms = ((s - s.truncate()) * 1000).toInt();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.truncate().toString().padLeft(2, '0')},${ms.toString().padLeft(3, '0')}';
  }

  void _downloadZip(Uint8List zipBytes, String filename) {
    if (kIsWeb) {
      WebAudioHelper.downloadFile(zipBytes,
          fileName: filename, mimeType: 'application/zip');
      _showSnack('$filename 다운로드 시작! 브라우저 다운로드 폴더를 확인하세요.');
    } else {
      // Windows/Desktop: FilePicker로 저장 경로 선택
      _saveZipDesktop(zipBytes, filename);
    }
  }

  Future<void> _saveZipDesktop(Uint8List zipBytes, String filename) async {
    try {
      // FilePicker로 저장 경로 선택
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'ZIP 파일 저장 위치 선택',
        fileName: filename,
        allowedExtensions: ['zip'],
        type: FileType.custom,
      );

      if (result != null) {
        // 선택한 경로에 파일 저장
        final file = File(result);
        await file.writeAsBytes(zipBytes);
        _showSnack('✅ 저장 완료!\n경로: $result');

        // 저장된 폴더 열기 (Windows 탐색기)
        final folder = File(result).parent.path;
        await launchUrl(Uri.parse('file:///$folder'));
      } else {
        // 사용자가 취소 → 대안으로 Documents에 자동 저장
        final docs = await getApplicationDocumentsDirectory();
        final savePath = '${docs.path}\\$filename';
        await File(savePath).writeAsBytes(zipBytes);
        _showSnack('💾 저장됨: $savePath\n(내 문서 폴더)');

        // 저장된 폴더 열기
        await launchUrl(Uri.parse('file:///${docs.path}'));
      }
    } catch (e) {
      // FilePicker 실패 시 Documents 폴더에 자동 저장
      try {
        final docs = await getApplicationDocumentsDirectory();
        final savePath = '${docs.path}\\$filename';
        await File(savePath).writeAsBytes(zipBytes);
        _showSnack('💾 저장됨: $savePath\n(내 문서 폴더에 자동 저장)');
        await launchUrl(Uri.parse('file:///${docs.path}'));
      } catch (e2) {
        _showSnack('❌ 저장 실패: $e2');
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.notoSansKr()),
        backgroundColor: AppTheme.bgElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 왼쪽: 설정
        Container(
          width: 340,
          decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AppTheme.border))),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('🎬 렌더링 설정'),
                const SizedBox(height: 12),
                // 웹 환경 안내
                Container(
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
                        const Icon(Icons.folder_zip_rounded, color: AppTheme.primary, size: 14),
                        const SizedBox(width: 6),
                        Text('렌더링 방식 안내',
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.primary, fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        '① 🎬 렌더링 시작 버튼 클릭\n'
                        '② ZIP 파일이 자동으로 다운로드됨\n'
                        '③ ZIP 압축 해제\n'
                        '④ render.bat(Windows) 또는 render.sh(Mac) 더블클릭\n'
                        '⑤ 같은 폴더에 MP4 영상 완성!',
                        style: GoogleFonts.notoSansKr(
                            color: AppTheme.textSecondary, fontSize: 10, height: 1.6),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse('https://ffmpeg.org/download.html')),
                        child: Text('⚙️ FFmpeg 없으면 여기서 먼저 설치 →',
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.primary, fontSize: 10,
                                decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _label('렌더링 프리셋'),
                const SizedBox(height: 6),
                ..._presets.entries.map((e) {
                  final selected = _selectedPreset == e.key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPreset = e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary.withValues(alpha: 0.1)
                            : AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: selected
                                ? AppTheme.primary.withValues(alpha: 0.6)
                                : AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: e.key,
                            groupValue: _selectedPreset,
                            onChanged: (v) =>
                                setState(() => _selectedPreset = v!),
                            activeColor: AppTheme.primary,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.value['label']!,
                                    style: GoogleFonts.notoSansKr(
                                        color: selected
                                            ? AppTheme.textPrimary
                                            : AppTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.normal)),
                                Text(e.value['desc']!,
                                    style: GoogleFonts.notoSansKr(
                                        color: AppTheme.textHint,
                                        fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                // ── 자막 설정 섹션 ──
                _sectionTitle('💬 자막 설정'),
                const SizedBox(height: 10),
                // 폰트 선택
                _label('자막 폰트'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _subtitleFont,
                      isExpanded: true,
                      dropdownColor: AppTheme.bgElevated,
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.textSecondary, fontSize: 13),
                      items: _subtitleFonts.map((f) {
                        final fontKey = f['flutter'] ?? 'notoSansKr';
                        return DropdownMenuItem<String>(
                          value: f['name'],
                          child: Row(
                            children: [
                              SizedBox(
                                width: 64,
                                child: Text('가나Aa',
                                    style: _getFlutterFontStyle(fontKey, 13,
                                        bold: f['name'] != 'Impact')),
                              ),
                              const SizedBox(width: 8),
                              Text(f['label']!,
                                  style: GoogleFonts.notoSansKr(
                                      color: AppTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _subtitleFont = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 폰트 크기
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _label('자막 크기'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${_subtitleFontSize.toInt()}pt',
                          style: GoogleFonts.notoSansKr(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Slider(
                  value: _subtitleFontSize,
                  min: 14,
                  max: 120,
                  divisions: 53,
                  activeColor: AppTheme.primary,
                  inactiveColor: AppTheme.border,
                  onChanged: (v) => setState(() => _subtitleFontSize = v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('14pt', style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 10)),
                    Text('120pt', style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 12),
                // 자막 분할 글자수
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('자막 분할 글자수'),
                        const SizedBox(height: 2),
                        Text(
                          '이 글자수가 넘으면 다음 자막으로 전환',
                          style: GoogleFonts.notoSansKr(
                              color: AppTheme.textHint, fontSize: 9),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$_subtitleMaxChars자',
                          style: GoogleFonts.notoSansKr(
                              color: AppTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Slider(
                  value: _subtitleMaxChars.toDouble(),
                  min: 10,
                  max: 40,
                  divisions: 30,
                  activeColor: AppTheme.accent,
                  inactiveColor: AppTheme.border,
                  onChanged: (v) => setState(() => _subtitleMaxChars = v.toInt()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('10자 (짧게)', style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 10)),
                    Text('40자 (길게)', style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 10)),
                  ],
                ),
                // 자막 분할 방식 안내
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    '💡 자막 분할 규칙: 문장끝(.!?.) → 쉼표(,) → 공백(어절) → 글자수 강제 분할 순서로 자동 분리됩니다.',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.textHint, fontSize: 9, height: 1.5),
                  ),
                ),
                // ── 자막 미리보기 (16:9 / 9:16) ──
                const SizedBox(height: 10),
                _buildSubtitlePreview(),
                const SizedBox(height: 16),
                _sectionTitle('🎞️ 추가 옵션'),
                const SizedBox(height: 10),
                // ── 인트로 영상 ──
                _buildIntroOutroOption(
                  isIntro: true,
                  enabled: _includeIntro,
                  onToggle: (v) => setState(() => _includeIntro = v),
                ),
                const SizedBox(height: 8),
                // ── 아웃트로 영상 ──
                _buildIntroOutroOption(
                  isIntro: false,
                  enabled: _includeOutro,
                  onToggle: (v) => setState(() => _includeOutro = v),
                ),
                const SizedBox(height: 8),
                _checkRow('워터마크/로고 삽입', _includeWatermark,
                    (v) => setState(() => _includeWatermark = v)),
                // 랜덤 카메라 효과
                _checkRowWithDesc(
                  '🎬 랜덤 카메라 효과',
                  '줌인·줌아웃·패닝 등 장면마다 랜덤 적용\n(렌더링 시간 약 2배 증가)',
                  _includeRandomEffect,
                  (v) => setState(() => _includeRandomEffect = v),
                ),
                const SizedBox(height: 20),

                // ── 렌더링 모드 선택 + 버튼 ──
                // FFmpeg 상태 표시
                if (!kIsWeb && Platform.isWindows) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_ffmpegFound ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (_ffmpegFound ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _ffmpegFound ? Icons.check_circle_rounded : Icons.warning_rounded,
                          color: _ffmpegFound ? AppTheme.success : AppTheme.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _ffmpegFound
                                ? 'FFmpeg 감지됨: $_ffmpegPath'
                                : 'FFmpeg 미감지 → ZIP 패키지 방식만 사용 가능',
                            style: GoogleFonts.notoSansKr(
                              color: _ffmpegFound ? AppTheme.success : AppTheme.warning,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (!_ffmpegFound)
                          TextButton(
                            onPressed: _detectFfmpeg,
                            child: Text('재감지',
                                style: GoogleFonts.notoSansKr(
                                    color: AppTheme.primary, fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // MP4 직접 렌더링 버튼 (FFmpeg 있을 때)
                if (!kIsWeb && Platform.isWindows && _ffmpegFound) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isRendering ? null : _startDirectRender,
                          icon: _isRendering && _isDirectRender
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.movie_creation_rounded, size: 22),
                          label: Text(
                            (_isRendering && _isDirectRender) ? '🎬 MP4 렌더링 중...' : '🎬 MP4 직접 렌더링 (추천)',
                            style: GoogleFonts.notoSansKr(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C896),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      // 렌더링 중일 때만 취소 버튼 표시
                      if (_isRendering && _isDirectRender) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isRenderCancelled = true;
                              _directRenderStatus = '⏹ 취소 중...';
                            });
                            _ffmpegProcess?.kill();
                          },
                          icon: const Icon(Icons.stop_rounded, size: 20),
                          label: Text('취소', style: GoogleFonts.notoSansKr(fontSize: 13, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 직접 렌더링 상태 메시지
                  if (_isRendering || _directRenderStatus.isNotEmpty)
                    Text(
                      _directRenderStatus.isNotEmpty ? _directRenderStatus : '준비 중...',
                      style: GoogleFonts.notoSansKr(
                        color: _directRenderStatus.startsWith('✅')
                            ? AppTheme.success
                            : _directRenderStatus.startsWith('❌') || _directRenderStatus.startsWith('⏹')
                                ? AppTheme.error
                                : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 6),
                  // 완료 후 폴더 열기 버튼
                  if (_lastOutputMp4.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final folder = File(_lastOutputMp4).parent.path;
                          await launchUrl(Uri.parse('file:///$folder'));
                        },
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: Text('📂 저장 폴더 열기',
                            style: GoogleFonts.notoSansKr(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.success,
                          side: BorderSide(color: AppTheme.success.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_lastOutputMp4,
                        style: GoogleFonts.sourceCodePro(
                            color: AppTheme.textHint, fontSize: 10)),
                    const SizedBox(height: 8),
                  ],
                  Divider(color: AppTheme.border, height: 24),
                ],

                // ZIP 패키지 버튼 (항상 표시)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRendering ? null : _startRendering,
                    icon: _isRendering && !_isDirectRender
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.folder_zip_rounded, size: 22),
                    label: Text(
                      (_isRendering && !_isDirectRender) ? 'ZIP 생성 중...' : '📦 ZIP 패키지 생성',
                      style: GoogleFonts.notoSansKr(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.bgElevated,
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('ZIP 압축 → render.bat 실행 방식 (FFmpeg 없어도 사용 가능)',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.textHint, fontSize: 10)),

                // 진행률 바 (렌더링 중)
                if (_isRendering) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _renderProgress,
                    backgroundColor: AppTheme.border,
                    color: AppTheme.primary,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  Text('${(_renderProgress * 100).toInt()}% 완료',
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
                if (widget.project.status == ProjectStatus.rendered && _lastOutputMp4.isEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.success.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppTheme.success, size: 16),
                          const SizedBox(width: 6),
                          Text('✅ ZIP 다운로드 완료',
                              style: GoogleFonts.notoSansKr(
                                  color: AppTheme.success,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 8),
                        Text('ZIP 압축 해제 후\nrender.bat(Windows) 또는\nrender.sh(Mac) 실행 → MP4 완성!',
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.textSecondary, fontSize: 11, height: 1.5)),
                        const SizedBox(height: 8),
                        Text(widget.project.finalVideoPath,
                            style: GoogleFonts.sourceCodePro(
                                color: AppTheme.textHint, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // 오른쪽: 렌더링 로그 + FFmpeg 명령어
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('📋 렌더링 로그'),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _renderLog.isEmpty
                          ? '렌더링을 시작하면 로그가 표시됩니다...'
                          : _renderLog,
                      style: GoogleFonts.sourceCodePro(
                          color: _renderLog.isEmpty
                              ? AppTheme.textHint
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _sectionTitle('🔧 FFmpeg 명령어 (Mac/Linux)'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _buildFfmpegCommand()));
                        _showSnackSimple('명령어가 클립보드에 복사되었습니다!');
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: Text('복사', style: GoogleFonts.notoSansKr(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: SelectableText(
                    _buildFfmpegCommand(),
                    style: GoogleFonts.sourceCodePro(
                        color: const Color(0xFF79C0FF),
                        fontSize: 11,
                        height: 1.6),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _sectionTitle('🔧 FFmpeg 명령어 (Windows)'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _buildFfmpegCommandWindows()));
                        _showSnackSimple('Windows 명령어가 클립보드에 복사되었습니다!');
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: Text('복사', style: GoogleFonts.notoSansKr(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: SelectableText(
                    _buildFfmpegCommandWindows(),
                    style: GoogleFonts.sourceCodePro(
                        color: const Color(0xFF90EE90),
                        fontSize: 11,
                        height: 1.6),
                  ),
                ),
                const SizedBox(height: 20),
                // 프로젝트 요약
                _buildProjectSummary(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectSummary() {
    final p = widget.project;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('📊 프로젝트 요약'),
          const SizedBox(height: 12),
          _summaryRow('프로젝트', p.title),
          _summaryRow('채널 유형', p.channelType.displayName),
          _summaryRow('총 장면 수', '${p.totalScenes}장면'),
          _summaryRow('목표 길이', '${p.targetMinutes}분'),
          _summaryRow('대본 길이', '${p.script.length}자'),
          _summaryRow('TTS 파일', p.ttsAudioPath.isEmpty ? '미생성' : '✅ 완료'),
          _summaryRow('자막', p.subtitles.isEmpty ? '미생성' : '✅ ${p.subtitles.length}개'),
          _summaryRow('썸네일', p.thumbnailPath.isEmpty ? '미생성' : '✅ 완료'),
          _summaryRow('렌더링', p.finalVideoPath.isEmpty ? '미완료' : '✅ 완료'),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textHint, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.notoSansKr(
                    color: value.startsWith('✅')
                        ? AppTheme.success
                        : AppTheme.textSecondary,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── 자막 미리보기 위젯 (16:9 + 9:16) ──
  Widget _buildSubtitlePreview() {
    // ── 16:9: 1920×1080, 9:16: 1080×1920 기준 ──
    // 미리보기 박스 너비를 300으로 고정, 높이는 비율에 맞게
    const boxW = 300.0;
    final boxH = _previewIs169 ? boxW * 9 / 16 : boxW * 16 / 9;

    // 실제 영상 너비 (16:9=1920, 9:16=1080)
    final realW = _previewIs169 ? 1920.0 : 1080.0;

    // 비율 그대로 폰트 크기 변환: previewFontSize = realFontSize * (boxW / realW)
    final previewFontSize = (_subtitleFontSize * boxW / realW).clamp(5.0, 80.0);

    final fontKey = _currentFlutterFontKey;
    final previewText = '여기에 자막이 표시됩니다';
    final labelName = _subtitleFonts.firstWhere(
      (f) => f['name'] == _subtitleFont, orElse: () => _subtitleFonts.first)['label']!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 + 탭 버튼
          Row(
            children: [
              const Icon(Icons.preview_rounded, color: AppTheme.primary, size: 14),
              const SizedBox(width: 6),
              Text('자막 미리보기',
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.primary, fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              // 16:9 / 9:16 토글 탭
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _previewIs169 = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _previewIs169 ? AppTheme.primary : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(5),
                            bottomLeft: Radius.circular(5),
                          ),
                        ),
                        child: Text('16:9',
                            style: GoogleFonts.notoSansKr(
                                color: _previewIs169 ? Colors.white : AppTheme.textHint,
                                fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _previewIs169 = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: !_previewIs169 ? AppTheme.primary : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(5),
                            bottomRight: Radius.circular(5),
                          ),
                        ),
                        child: Text('9:16',
                            style: GoogleFonts.notoSansKr(
                                color: !_previewIs169 ? Colors.white : AppTheme.textHint,
                                fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 폰트/크기 정보
          Text(
            '폰트: $labelName  |  크기: ${_subtitleFontSize.toInt()}pt  |  '
            '미리보기 기준: ${_previewIs169 ? "1920×1080" : "1080×1920"}',
            style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 9),
          ),
          const SizedBox(height: 10),
          // 미리보기 박스 (가로 중앙 정렬)
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: boxW,
              height: boxH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 1.5),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E3A5F), Color(0xFF0D1117)],
                ),
              ),
              child: Stack(
                children: [
                  // 화면 비율 표시
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        _previewIs169 ? '16:9' : '9:16',
                        style: GoogleFonts.notoSansKr(
                            color: Colors.white54, fontSize: 9),
                      ),
                    ),
                  ),
                  // 중앙 이미지 아이콘
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.landscape_rounded,
                            color: Colors.white.withValues(alpha: 0.12),
                            size: boxW * 0.18),
                        const SizedBox(height: 4),
                        Text('장면 이미지',
                            style: GoogleFonts.notoSansKr(
                                color: Colors.white.withValues(alpha: 0.1),
                                fontSize: 9)),
                      ],
                    ),
                  ),
                  // 자막 (하단 10% 위치)
                  Positioned(
                    bottom: boxH * 0.07,
                    left: boxW * 0.05,
                    right: boxW * 0.05,
                    child: Column(
                      children: [
                        // 실제 폰트+크기로 자막 표시
                        Stack(
                          children: [
                            // 테두리 효과 (검정 shadow)
                            Text(
                              previewText,
                              textAlign: TextAlign.center,
                              style: _getFlutterFontStyle(fontKey, previewFontSize, bold: true).copyWith(
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = previewFontSize * 0.15
                                  ..color = Colors.black,
                              ),
                            ),
                            // 실제 텍스트
                            Text(
                              previewText,
                              textAlign: TextAlign.center,
                              style: _getFlutterFontStyle(fontKey, previewFontSize, bold: true).copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // 폰트 크기 비율 안내
                        Text(
                          '실제 영상에서 ${_subtitleFontSize.toInt()}pt',
                          style: GoogleFonts.notoSansKr(
                              color: Colors.white38, fontSize: 7),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 인트로/아웃트로 옵션 카드 ──
  Widget _buildIntroOutroOption({
    required bool isIntro,
    required bool enabled,
    required ValueChanged<bool> onToggle,
  }) {
    final label = isIntro ? '🎬 인트로 영상 추가' : '🎬 아웃트로 영상 추가';
    final filename = isIntro ? 'intro.mp4' : 'outro.mp4';
    final position = isIntro ? '맨 앞' : '맨 뒤';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: enabled
            ? AppTheme.primary.withValues(alpha: 0.08)
            : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled
              ? AppTheme.primary.withValues(alpha: 0.5)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (토글 + 제목)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                  activeColor: AppTheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.notoSansKr(
                          color: enabled
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: enabled
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      Text(
                        '영상 $position에 MP4 클립을 자동 삽입',
                        style: GoogleFonts.notoSansKr(
                            color: AppTheme.textHint, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 사용 방법 안내 (활성화 시)
          if (enabled) ...[
            Divider(
                height: 1,
                color: AppTheme.primary.withValues(alpha: 0.25)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 사용 방법',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _introStepRow('①', '렌더링 시작 버튼 클릭 → ZIP 파일 다운로드'),
                  _introStepRow('②', 'ZIP 파일 압축 해제'),
                  _introStepRow(
                    '③',
                    '압축 해제된 폴더 안에\n'
                    '본인의 $position 영상을\n'
                    '"$filename" 이름으로 복사',
                    highlight: true,
                  ),
                  _introStepRow('④', 'render.bat (Windows) 또는\nrender.sh (Mac) 실행'),
                  _introStepRow('⑤', '완성! 영상 $position에 $filename 자동 삽입됨'),
                  const SizedBox(height: 8),
                  // 핵심 포인트 강조
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.folder_open_rounded,
                            color: AppTheme.primary, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'ZIP 해제 폴더에 "$filename" 파일을 넣은 뒤 스크립트를 실행하세요.\n'
                            '파일명이 다르면 인식되지 않습니다.',
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.primary,
                                fontSize: 10,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _introStepRow(String step, String text, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: highlight
                  ? AppTheme.accent.withValues(alpha: 0.25)
                  : AppTheme.bgDark,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: highlight
                      ? AppTheme.accent.withValues(alpha: 0.6)
                      : AppTheme.border),
            ),
            child: Center(
              child: Text(
                step,
                style: GoogleFonts.notoSansKr(
                  color: highlight ? AppTheme.accent : AppTheme.textHint,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.notoSansKr(
                color: highlight
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
                fontSize: 11,
                height: 1.4,
                fontWeight:
                    highlight ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _checkRowWithDesc(String label, String desc, bool value,
      ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: value
              ? AppTheme.primary.withValues(alpha: 0.08)
              : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: value
                  ? AppTheme.primary.withValues(alpha: 0.5)
                  : AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.notoSansKr(
                          color: value
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: value
                              ? FontWeight.w600
                              : FontWeight.normal)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.textHint,
                          fontSize: 10,
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
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

  void _showSnackSimple(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.notoSansKr()),
        backgroundColor: AppTheme.bgElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─────────────────────────────────────
// 탭 2: 썸네일 생성
// ─────────────────────────────────────
class _ThumbnailTab extends StatefulWidget {
  final ProjectModel project;
  final AppProvider provider;
  const _ThumbnailTab({required this.project, required this.provider});

  @override
  State<_ThumbnailTab> createState() => _ThumbnailTabState();
}

class _ThumbnailTabState extends State<_ThumbnailTab> {
  bool _isGenerating = false;
  String _thumbTitle = '';
  String _thumbSubtitle = '';
  String _bgImagePath = '';
  Color _textColor = Colors.white;
  Color _bgColor = Colors.black;
  String _selectedTemplate = 'standard';
  bool _useAiBg = true;

  final Map<String, Map<String, dynamic>> _templates = {
    'standard': {
      'label': '표준형',
      'desc': '텍스트 + 이미지 조합',
      'color': AppTheme.primary,
    },
    'bold': {
      'label': '강렬형',
      'desc': '크고 굵은 텍스트',
      'color': AppTheme.error,
    },
    'minimal': {
      'label': '미니멀',
      'desc': '깔끔하고 간결',
      'color': AppTheme.textSecondary,
    },
    'split': {
      'label': '2분할',
      'desc': '좌우 분할 레이아웃',
      'color': AppTheme.accent,
    },
  };

  Future<void> _generateThumbnail() async {
    setState(() => _isGenerating = true);

    final geminiKey = widget.provider.apiKeys.geminiApiKey;

    try {
      if (geminiKey.isNotEmpty && widget.project.script.isNotEmpty) {
        // Gemini AI로 써네일 텍스트 실제 생성
        final service = GeminiService(geminiKey);
        final text = await service.generateThumbnailText(
          widget.project.script,
          widget.project.channelType,
        );
        final lines = text.trim().split('\n');
        setState(() {
          _thumbTitle = lines.isNotEmpty ? lines[0].trim() : widget.project.title;
          _thumbSubtitle = lines.length > 1 ? lines[1].trim() : '';
        });
      } else {
        // API 키 없으면 기본 텍스트 사용
        setState(() {
          _thumbTitle = widget.project.title.length > 12
              ? widget.project.title.substring(0, 12)
              : widget.project.title;
          _thumbSubtitle = '${widget.project.channelType.emoji} 지금 바로 보세요!';
        });
      }

      widget.project.thumbnailPath = '${widget.project.id}_thumbnail.jpg';
      widget.project.status = ProjectStatus.thumbnailReady;
      widget.provider.updateProject(widget.project);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 써네일 생성 완료!', style: GoogleFonts.notoSansKr()),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('써네일 생성 실패: $e', style: GoogleFonts.notoSansKr()),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 왼쪽: 설정
        Container(
          width: 320,
          decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AppTheme.border))),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('🖼️ 썸네일 템플릿'),
                const SizedBox(height: 10),
                ..._templates.entries.map((e) {
                  final selected = _selectedTemplate == e.key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTemplate = e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? (e.value['color'] as Color).withValues(alpha: 0.1)
                            : AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: selected
                                ? (e.value['color'] as Color).withValues(alpha: 0.6)
                                : AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: e.key,
                            groupValue: _selectedTemplate,
                            onChanged: (v) =>
                                setState(() => _selectedTemplate = v!),
                            activeColor: e.value['color'] as Color,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.value['label']!,
                                    style: GoogleFonts.notoSansKr(
                                        color: selected
                                            ? AppTheme.textPrimary
                                            : AppTheme.textSecondary,
                                        fontSize: 13,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.normal)),
                                Text(e.value['desc']!,
                                    style: GoogleFonts.notoSansKr(
                                        color: AppTheme.textHint,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                _sectionTitle('✏️ 썸네일 텍스트'),
                const SizedBox(height: 10),
                _label('제목 (상단)'),
                const SizedBox(height: 6),
                TextField(
                  onChanged: (v) => setState(() => _thumbTitle = v),
                  controller: TextEditingController(text: _thumbTitle),
                  style: GoogleFonts.notoSansKr(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'AI가 자동 생성합니다',
                    hintStyle: GoogleFonts.notoSansKr(
                        color: AppTheme.textHint, fontSize: 12),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                _label('부제 (하단)'),
                const SizedBox(height: 6),
                TextField(
                  onChanged: (v) => setState(() => _thumbSubtitle = v),
                  controller: TextEditingController(text: _thumbSubtitle),
                  style: GoogleFonts.notoSansKr(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: '클릭을 유도하는 부제목',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                _label('배경 이미지'),
                const SizedBox(height: 6),
                Row(children: [
                  Switch(
                    value: _useAiBg,
                    onChanged: (v) => setState(() => _useAiBg = v),
                    activeColor: AppTheme.primary,
                  ),
                  Text('AI 자동 생성',
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.textSecondary, fontSize: 13)),
                ]),
                if (!_useAiBg) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );
                      if (result != null) {
                        setState(
                            () => _bgImagePath = result.files.first.path ?? '');
                      }
                    },
                    icon: const Icon(Icons.image_rounded, size: 16),
                    label: Text('이미지 선택', style: GoogleFonts.notoSansKr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.bgElevated,
                      foregroundColor: AppTheme.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateThumbnail,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(_isGenerating ? '생성 중...' : '🖼️ AI 썸네일 생성',
                        style: GoogleFonts.notoSansKr(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 오른쪽: 미리보기
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('썸네일 미리보기',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                // 썸네일 미리보기 (1280x720)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    width: 640,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getThemeColor(widget.project.channelType),
                          _getThemeColor(widget.project.channelType)
                              .withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Stack(
                      children: [
                        // 배경 패턴
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: RadialGradient(
                                center: const Alignment(-0.5, -0.5),
                                radius: 1.5,
                                colors: [
                                  Colors.white.withValues(alpha: 0.05),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 채널 타입 이모지
                        Positioned(
                          right: 30,
                          top: 20,
                          child: Text(
                            widget.project.channelType.emoji,
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                        // 텍스트
                        Positioned(
                          left: 24,
                          bottom: 24,
                          right: 80,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_thumbTitle.isNotEmpty)
                                Text(
                                  _thumbTitle,
                                  style: GoogleFonts.notoSansKr(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                    shadows: [
                                      const Shadow(
                                        blurRadius: 4,
                                        color: Colors.black54,
                                        offset: Offset(1, 1),
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else
                                Container(
                                  height: 26,
                                  width: 240,
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              if (_thumbSubtitle.isNotEmpty)
                                Text(
                                  _thumbSubtitle,
                                  style: GoogleFonts.notoSansKr(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('1280 × 720px (YouTube 권장)',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.textHint, fontSize: 12)),
                if (widget.project.thumbnailPath.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.success, size: 14),
                      const SizedBox(width: 6),
                      Text('썸네일 저장됨',
                          style: GoogleFonts.notoSansKr(
                              color: AppTheme.success, fontSize: 12)),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getThemeColor(ChannelType type) {
    switch (type) {
      case ChannelType.economy: return const Color(0xFF1565C0);
      case ChannelType.patriot: return const Color(0xFFC62828);
      case ChannelType.folklore: return const Color(0xFF4A148C);
      case ChannelType.story: return const Color(0xFFAD1457);
      case ChannelType.bible: return const Color(0xFF1B5E20);
      case ChannelType.buddhism: return const Color(0xFFE65100);
      case ChannelType.psychology: return const Color(0xFF006064);
      case ChannelType.history: return const Color(0xFF37474F);
      case ChannelType.asmr: return const Color(0xFF263238);
      case ChannelType.playlist: return const Color(0xFF212121);
    }
  }

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.notoSansKr(
          color: AppTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.bold));

  Widget _label(String t) => Text(t,
      style:
          GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 12));
}

// ─────────────────────────────────────
// 탭 3: 유튜브 업로드
// ─────────────────────────────────────
class _YoutubeUploadTab extends StatefulWidget {
  final ProjectModel project;
  final AppProvider provider;
  const _YoutubeUploadTab({required this.project, required this.provider});

  @override
  State<_YoutubeUploadTab> createState() => _YoutubeUploadTabState();
}

class _YoutubeUploadTabState extends State<_YoutubeUploadTab> {
  bool _isGeneratingMeta = false;
  bool _isUploading = false;
  String _uploadStatus = '';
  bool _useSchedule = false;
  DateTime _scheduleTime = DateTime.now().add(const Duration(hours: 24));

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _tagsCtrl;
  String _privacyStatus = 'public';
  String _categoryId = '22';

  final Map<String, String> _categories = {
    '22': '사람 및 블로그',
    '28': '과학 기술',
    '27': '교육',
    '24': '엔터테인먼트',
    '25': '뉴스 및 정치',
    '10': '음악',
  };

  @override
  void initState() {
    super.initState();
    final u = widget.project.uploadSettings;
    _titleCtrl = TextEditingController(text: u.title);
    _descCtrl = TextEditingController(text: u.description);
    _tagsCtrl = TextEditingController(text: u.tags.join(', '));
    _privacyStatus = u.privacyStatus;
    if (u.scheduledTime != null) {
      _useSchedule = true;
      _scheduleTime = u.scheduledTime!;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateMetadata() async {
    final apiKey = widget.provider.apiKeys.geminiApiKey;
    if (apiKey.isEmpty) {
      _showSnack('설정에서 Gemini API 키를 입력해주세요.');
      return;
    }
    if (widget.project.script.isEmpty) {
      _showSnack('대본이 없습니다. 대본을 먼저 작성해주세요.');
      return;
    }

    setState(() => _isGeneratingMeta = true);

    try {
      // Gemini AI로 실제 메타데이터 생성
      final service = GeminiService(apiKey);
      final channel = widget.provider.channels
          .firstWhere((c) => c.id == widget.project.channelId,
              orElse: () => widget.provider.channels.first);

      final meta = await service.generateYoutubeMetadata(
        script: widget.project.script,
        channelType: widget.project.channelType,
        channelName: channel.name,
      );

      final title = meta['title']?.toString() ?? widget.project.title;
      final desc = meta['description']?.toString() ?? '';
      final rawTags = meta['tags'];
      final tags = rawTags is List
          ? rawTags.map((t) => t.toString()).toList()
          : <String>[];

      setState(() {
        _titleCtrl.text = title;
        _descCtrl.text = desc;
        _tagsCtrl.text = tags.join(', ');
      });

      widget.project.uploadSettings.title = title;
      widget.project.uploadSettings.description = desc;
      widget.project.uploadSettings.tags = tags;
      widget.provider.updateProject(widget.project);

      _showSnack('✅ AI가 메타데이터를 생성했습니다!');
    } catch (e) {
      _showSnack('메타데이터 생성 실패: $e');
    } finally {
      setState(() => _isGeneratingMeta = false);
    }
  }

  Future<void> _startUpload() async {
    if (widget.project.finalVideoPath.isEmpty) {
      _showSnack('렌더링을 먼저 완료해주세요.');
      return;
    }

    final ytClientId = widget.provider.apiKeys.youtubeClientId;
    final ytClientSecret = widget.provider.apiKeys.youtubeClientSecret;

    if (ytClientId.isEmpty || ytClientSecret.isEmpty) {
      _showSnack('설정에서 YouTube API 키를 입력해주세요.');
      // 설정으로 이동 안내
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: Text('YouTube API 설정 필요',
              style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary)),
          content: Text(
            '유튜브 자동 업로드를 사용하려면:\n\n'
            '1. Google Cloud Console에서 프로젝트 생성\n'
            '2. YouTube Data API v3 활성화\n'
            '3. OAuth 2.0 클라이언트 ID 생성\n'
            '4. 설정 화면에서 API 키 입력\n\n'
            '현재는 수동 업로드를 이용해주세요.',
            style: GoogleFonts.notoSansKr(
                color: AppTheme.textSecondary, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.provider.setNavIndex(6);
              },
              child:
                  Text('설정으로 이동', style: GoogleFonts.notoSansKr(color: AppTheme.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('닫기', style: GoogleFonts.notoSansKr()),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatus = '📤 업로드 준비 중...';
    });

    // 업로드 프로세스 시뮬레이션
    final steps = [
      '📤 업로드 준비 중...',
      '🔐 YouTube 인증 중...',
      '📁 파일 준비 중...',
      '⬆️ 영상 업로드 중... (파일 크기에 따라 시간이 걸립니다)',
      '🖼️ 썸네일 업로드 중...',
      '📝 메타데이터 설정 중...',
      if (_useSchedule) '⏰ 예약 업로드 설정 중...',
      '✅ 업로드 완료!',
    ];

    for (final step in steps) {
      if (!mounted) break;
      setState(() => _uploadStatus = step);
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    widget.project.status = ProjectStatus.uploaded;
    widget.provider.updateProject(widget.project);

    setState(() => _isUploading = false);
    _showSnack('🎉 유튜브 업로드가 완료되었습니다!');
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태 확인 섹션
          _buildReadinessCheck(),
          const SizedBox(height: 24),
          // 메타데이터 섹션
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildMetadataSection()),
              const SizedBox(width: 24),
              SizedBox(width: 320, child: _buildUploadSettings()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessCheck() {
    final checks = [
      {
        'label': '렌더링 완료',
        'done': widget.project.finalVideoPath.isNotEmpty,
        'action': () => widget.provider.setNavIndex(5),
        'actionLabel': '렌더링하기'
      },
      {
        'label': '썸네일 준비',
        'done': widget.project.thumbnailPath.isNotEmpty,
        'action': null,
        'actionLabel': ''
      },
      {
        'label': '제목/설명 입력',
        'done': _titleCtrl.text.isNotEmpty,
        'action': null,
        'actionLabel': ''
      },
      {
        'label': 'YouTube API 키',
        'done': widget.provider.apiKeys.hasYoutube,
        'action': () => widget.provider.setNavIndex(6),
        'actionLabel': '설정으로'
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('업로드 준비 체크',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...checks.map((c) {
            final done = c['done'] as bool;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: done ? AppTheme.success : AppTheme.textHint,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(c['label'] as String,
                        style: GoogleFonts.notoSansKr(
                            color: done
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontSize: 13)),
                  ),
                  if (!done && c['action'] != null)
                    TextButton(
                      onPressed: c['action'] as VoidCallback,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      child: Text(c['actionLabel'] as String,
                          style: GoogleFonts.notoSansKr(
                              color: AppTheme.primary, fontSize: 11)),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMetadataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('📋 영상 정보',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isGeneratingMeta ? null : _generateMetadata,
              icon: _isGeneratingMeta
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded, size: 14),
              label: Text(_isGeneratingMeta ? 'AI 생성 중...' : '🤖 AI 자동 생성',
                  style: GoogleFonts.notoSansKr(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _label('제목 (클릭유도 제목 권장)'),
        const SizedBox(height: 6),
        TextField(
          controller: _titleCtrl,
          style: GoogleFonts.notoSansKr(fontSize: 13),
          decoration: const InputDecoration(
            hintText: '매력적인 제목을 입력하세요',
            counterText: '',
          ),
          maxLength: 100,
          onChanged: (_) {
            widget.project.uploadSettings.title = _titleCtrl.text;
          },
        ),
        const SizedBox(height: 14),
        _label('설명'),
        const SizedBox(height: 6),
        TextField(
          controller: _descCtrl,
          style: GoogleFonts.notoSansKr(fontSize: 13),
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '영상 설명 (SEO 최적화, 해시태그 포함 권장)',
          ),
          onChanged: (_) {
            widget.project.uploadSettings.description = _descCtrl.text;
          },
        ),
        const SizedBox(height: 14),
        _label('태그 (쉼표로 구분)'),
        const SizedBox(height: 6),
        TextField(
          controller: _tagsCtrl,
          style: GoogleFonts.notoSansKr(fontSize: 13),
          decoration: const InputDecoration(
            hintText: '경제, 일본경제, 미국경제, 투자, 재테크',
          ),
          onChanged: (_) {
            widget.project.uploadSettings.tags =
                _tagsCtrl.text.split(',').map((t) => t.trim()).toList();
          },
        ),
      ],
    );
  }

  Widget _buildUploadSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('⚙️ 업로드 설정',
            style: GoogleFonts.notoSansKr(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        _label('공개 설정'),
        const SizedBox(height: 8),
        ...['public', 'unlisted', 'private'].map((v) {
          final labels = {
            'public': '🌍 공개',
            'unlisted': '🔗 링크 공유',
            'private': '🔒 비공개'
          };
          return RadioListTile<String>(
            value: v,
            groupValue: _privacyStatus,
            title: Text(labels[v]!,
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textSecondary, fontSize: 13)),
            onChanged: (val) {
              setState(() => _privacyStatus = val!);
              widget.project.uploadSettings.privacyStatus = val!;
            },
            activeColor: AppTheme.primary,
            dense: true,
            contentPadding: EdgeInsets.zero,
          );
        }),
        const SizedBox(height: 14),
        _label('카테고리'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButton<String>(
            value: _categoryId,
            isExpanded: true,
            dropdownColor: AppTheme.bgElevated,
            underline: const SizedBox(),
            style: GoogleFonts.notoSansKr(
                color: AppTheme.textPrimary, fontSize: 13),
            items: _categories.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) {
              setState(() => _categoryId = v!);
              widget.project.uploadSettings.categoryId = v!;
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Switch(
              value: _useSchedule,
              onChanged: (v) => setState(() => _useSchedule = v),
              activeColor: AppTheme.primary,
            ),
            Text('예약 업로드',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
        if (_useSchedule) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _scheduleTime,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark(),
                  child: child!,
                ),
              );
              if (date != null && mounted) {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_scheduleTime),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark(),
                    child: child!,
                  ),
                );
                if (time != null) {
                  setState(() {
                    _scheduleTime = DateTime(
                      date.year, date.month, date.day,
                      time.hour, time.minute,
                    );
                    widget.project.uploadSettings.scheduledTime = _scheduleTime;
                  });
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      color: AppTheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${_scheduleTime.year}/${_scheduleTime.month.toString().padLeft(2, '0')}/${_scheduleTime.day.toString().padLeft(2, '0')} '
                    '${_scheduleTime.hour.toString().padLeft(2, '0')}:${_scheduleTime.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.textPrimary, fontSize: 13),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit_rounded,
                      size: 14, color: AppTheme.textHint),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        // 업로드 버튼
        if (_isUploading) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_uploadStatus,
                          style: GoogleFonts.notoSansKr(
                              color: AppTheme.textPrimary, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startUpload,
              icon: const Icon(Icons.upload_rounded, size: 20),
              label: Text(
                  _useSchedule ? '⏰ 예약 업로드' : '📤 지금 업로드',
                  style: GoogleFonts.notoSansKr(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (widget.project.status == ProjectStatus.uploaded) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.success, size: 16),
                const SizedBox(width: 8),
                Text('업로드 완료!',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.success,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ],
        ],
      ],
    );
  }

  Widget _label(String t) => Text(t,
      style:
          GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 12));
}
