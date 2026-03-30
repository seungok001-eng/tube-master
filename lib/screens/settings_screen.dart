import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_provider.dart';
import '../models/api_key_model.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../models/channel_model.dart';
import '../models/project_model.dart' show ScriptAiModel;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _tabIndex = 0;

  // API 키별 테스트 상태: null=미테스트, true=성공, false=실패
  final Map<String, bool?> _testResults = {};
  final Map<String, bool> _testingFlags = {};

  // API 키 컨트롤러
  late TextEditingController _geminiCtrl;
  late TextEditingController _claudeCtrl;
  late TextEditingController _elevenLabsCtrl;
  late TextEditingController _clovaKeyCtrl;
  late TextEditingController _clovaSecretCtrl;
  late TextEditingController _ytClientIdCtrl;
  late TextEditingController _ytClientSecretCtrl;
  late TextEditingController _stabilityCtrl;
  late TextEditingController _replicateCtrl;
  late TextEditingController _falCtrl;
  late TextEditingController _openAiCtrl;
  late TextEditingController _outputFolderCtrl;

  // 가시성
  final Map<String, bool> _visible = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadKeys());
  }

  void _loadKeys() {
    final keys = context.read<AppProvider>().apiKeys;
    setState(() {
      _geminiCtrl = TextEditingController(text: keys.geminiApiKey);
      _claudeCtrl = TextEditingController(text: keys.claudeApiKey);
      _elevenLabsCtrl = TextEditingController(text: keys.elevenLabsApiKey);
      _clovaKeyCtrl = TextEditingController(text: keys.clovaApiKey);
      _clovaSecretCtrl = TextEditingController(text: keys.clovaApiSecret);
      _ytClientIdCtrl = TextEditingController(text: keys.youtubeClientId);
      _ytClientSecretCtrl = TextEditingController(text: keys.youtubeClientSecret);
      _stabilityCtrl = TextEditingController(text: keys.stabilityApiKey);
      _replicateCtrl = TextEditingController(text: keys.replicateApiKey);
      _falCtrl = TextEditingController(text: keys.falApiKey);
      _openAiCtrl = TextEditingController(text: keys.openAiApiKey);
      _outputFolderCtrl = TextEditingController(text: 'C:\\TubeMaster\\Output');
    });
  }

  @override
  void dispose() {
    _geminiCtrl.dispose();
    _claudeCtrl.dispose();
    _elevenLabsCtrl.dispose();
    _clovaKeyCtrl.dispose();
    _clovaSecretCtrl.dispose();
    _ytClientIdCtrl.dispose();
    _ytClientSecretCtrl.dispose();
    _stabilityCtrl.dispose();
    _replicateCtrl.dispose();
    _falCtrl.dispose();
    _openAiCtrl.dispose();
    _outputFolderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(provider),
              _buildTabs(),
              Expanded(child: _buildTabContent(provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings_rounded, color: AppTheme.primary, size: 24),
          const SizedBox(width: 12),
          Text('설정',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _saveSettings(provider),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text('저장', style: GoogleFonts.notoSansKr()),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['🔑 API 키', '📁 출력 설정', '🎬 기본 영상 설정', 'ℹ️ 정보'];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final selected = _tabIndex == e.key;
          return InkWell(
            onTap: () => setState(() => _tabIndex = e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? AppTheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(e.value,
                  style: GoogleFonts.notoSansKr(
                      color: selected ? AppTheme.primary : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(AppProvider provider) {
    switch (_tabIndex) {
      case 0: return _buildApiKeysTab(provider);
      case 1: return _buildOutputTab();
      case 2: return _buildVideoDefaultTab();
      case 3: return _buildInfoTab();
      default: return const SizedBox();
    }
  }

  // ═══════════════════════════════════════════
  // API 키 탭
  // ═══════════════════════════════════════════
  Widget _buildApiKeysTab(AppProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildApiSection(
            title: '🤖 AI 대본 생성',
            children: [
              _apiKeyField(
                label: 'Gemini API Key',
                controller: _geminiCtrl,
                hint: 'AIzaSy...',
                keyId: 'gemini',
                isSet: provider.apiKeys.hasGemini,
                helpUrl: 'https://aistudio.google.com/app/apikey',
                helpText: 'Google AI Studio에서 발급',
                canTest: true,
              ),
              _apiKeyField(
                label: 'Claude API Key',
                controller: _claudeCtrl,
                hint: 'sk-ant-...',
                keyId: 'claude',
                isSet: provider.apiKeys.hasClaude,
                helpUrl: 'https://console.anthropic.com/',
                helpText: 'Anthropic Console에서 발급',
                canTest: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildApiSection(
            title: '🎙️ TTS 음성 생성',
            children: [
              _apiKeyField(
                label: 'ElevenLabs API Key',
                controller: _elevenLabsCtrl,
                hint: 'xi-...',
                keyId: 'elevenlabs',
                isSet: provider.apiKeys.hasElevenLabs,
                helpUrl: 'https://elevenlabs.io/',
                helpText: 'ElevenLabs에서 발급 (월 구독)',
                canTest: true,
              ),
              _apiKeyField(
                label: '네이버 CLOVA Client ID',
                controller: _clovaKeyCtrl,
                hint: 'NCP_APIGW_API_KEY_ID (Client ID)',
                keyId: 'clovaKey',
                isSet: provider.apiKeys.hasClova,
                helpUrl: 'https://console.ncloud.com/naver-service/application',
                helpText: 'Naver Cloud → AI·NAVER API → Application 등록 → Client ID',
              ),
              _apiKeyField(
                label: '네이버 CLOVA Client Secret',
                controller: _clovaSecretCtrl,
                hint: 'NCP_APIGW_API_KEY (Client Secret)',
                keyId: 'clovaSecret',
                isSet: provider.apiKeys.hasClova,
                helpUrl: null,
                helpText: 'Application 등록 후 발급된 Client Secret',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildApiSection(
            title: '🎬 AI 영상 생성',
            children: [
              // fal.ai 안내 박스
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.movie_creation_outlined, color: AppTheme.primary, size: 14),
                      const SizedBox(width: 6),
                      Text('fal.ai: Kling v3 · Wan v2.6 · MiniMax · Vidu · Runway · Pixverse · Seedance',
                          style: GoogleFonts.notoSansKr(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      '하나의 API 키로 7가지 영상 모델을 이용할 수 있습니다.\n'
                      '가격: Kling \$0.42/클립, Wan \$0.25/클립, MiniMax \$0.28/클립 등',
                      style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 10, height: 1.5),
                    ),
                  ],
                ),
              ),
              _apiKeyField(
                label: 'fal.ai API Key',
                controller: _falCtrl,
                hint: 'fal-...',
                keyId: 'fal',
                isSet: provider.apiKeys.hasFal,
                helpUrl: 'https://fal.ai/dashboard/keys',
                helpText: 'fal.ai 대시보드에서 발급',
              ),
              const SizedBox(height: 16),
              // OpenAI 안내 박스
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 14),
                      const SizedBox(width: 6),
                      Text('OpenAI: Sora 2 · Sora 2 Pro',
                          style: GoogleFonts.notoSansKr(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      'Sora 2: \$0.50/클립(5초) · Sora 2 Pro: \$1.50/클립(5초)\n'
                      '기존 ChatGPT Plus API 키 그대로 사용 가능합니다.',
                      style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 10, height: 1.5),
                    ),
                  ],
                ),
              ),
              _apiKeyField(
                label: 'OpenAI API Key',
                controller: _openAiCtrl,
                hint: 'sk-proj-...',
                keyId: 'openai',
                isSet: provider.apiKeys.hasOpenAi,
                helpUrl: 'https://platform.openai.com/api-keys',
                helpText: 'OpenAI Platform에서 발급',
              ),
              const SizedBox(height: 8),
              // 로컬 모델 안내
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.computer_rounded, color: AppTheme.success, size: 14),
                      const SizedBox(width: 6),
                      Text('로컬 무료: AnimateDiff · SVD · SVD-XT · Wan 2.1 · Wan 2.6',
                          style: GoogleFonts.notoSansKr(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      'API 키 불필요 · 완전 무료 · 내 PC에서 실행\n'
                      '• AnimateDiff / SVD / SVD-XT → Automatic1111 WebUI 필요\n'
                      '• Wan 2.1 / Wan 2.6 → ComfyUI 필요\n'
                      '로컬 URL은 아래 "기본 영상 설정" 탭에서 설정하세요.',
                      style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 10, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildApiSection(
            title: '🖼️ 이미지 생성',
            children: [
              _apiKeyField(
                label: 'Stability AI API Key',
                controller: _stabilityCtrl,
                hint: 'sk-...',
                keyId: 'stability',
                isSet: provider.apiKeys.hasStability,
                helpUrl: 'https://platform.stability.ai/',
                helpText: 'Stability AI Platform',
              ),
              _apiKeyField(
                label: 'Replicate API Key',
                controller: _replicateCtrl,
                hint: 'r8_...',
                keyId: 'replicate',
                isSet: _replicateCtrl.text.isNotEmpty,
                helpUrl: 'https://replicate.com/',
                helpText: 'Replicate (SD, 기타 모델)',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildApiSection(
            title: '📺 YouTube 업로드',
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 16),
                        const SizedBox(width: 8),
                        Text('YouTube API 설정 안내',
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.warning, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Google Cloud Console에서 프로젝트 생성\n'
                      '2. YouTube Data API v3 활성화\n'
                      '3. OAuth 2.0 클라이언트 ID 생성 (데스크톱 앱)\n'
                      '4. 아래에 Client ID와 Secret 입력',
                      style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 12, height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _apiKeyField(
                label: 'YouTube Client ID',
                controller: _ytClientIdCtrl,
                hint: '123456789-xxx.apps.googleusercontent.com',
                keyId: 'ytClientId',
                isSet: provider.apiKeys.hasYoutube,
                helpUrl: 'https://console.cloud.google.com/',
                helpText: 'Google Cloud Console',
              ),
              _apiKeyField(
                label: 'YouTube Client Secret',
                controller: _ytClientSecretCtrl,
                hint: 'GOCSPX-...',
                keyId: 'ytClientSecret',
                isSet: provider.apiKeys.hasYoutube,
                helpUrl: null,
                helpText: '',
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildApiSection({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(title,
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _apiKeyField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String keyId,
    required bool isSet,
    String? helpUrl,
    required String helpText,
    bool canTest = false,
  }) {
    final isVisible = _visible[keyId] ?? false;
    final testResult = _testResults[keyId];
    final isTesting = _testingFlags[keyId] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              if (isSet)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('✓ 설정됨',
                      style: GoogleFonts.notoSansKr(color: AppTheme.success, fontSize: 10)),
                ),
              const Spacer(),
              // 테스트 결과 표시
              if (testResult != null) ...[
                Icon(
                  testResult ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 14,
                  color: testResult ? AppTheme.success : AppTheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  testResult ? '연결 성공' : '연결 실패',
                  style: GoogleFonts.notoSansKr(
                      color: testResult ? AppTheme.success : AppTheme.error, fontSize: 11),
                ),
                const SizedBox(width: 8),
              ],
              if (canTest && controller.text.isNotEmpty)
                SizedBox(
                  height: 28,
                  child: TextButton(
                    onPressed: isTesting ? null : () => _testApiKey(keyId, controller.text),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      backgroundColor: AppTheme.bgElevated,
                    ),
                    child: isTesting
                        ? const SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                        : Text('테스트', style: GoogleFonts.notoSansKr(fontSize: 11, color: AppTheme.primary)),
                  ),
                ),
              if (helpUrl != null && helpText.isNotEmpty) ...[
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: Text('발급받기 →',
                      style: GoogleFonts.notoSansKr(color: AppTheme.primary, fontSize: 11)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: !isVisible,
            onChanged: (_) => setState(() => _testResults[keyId] = null),
            style: GoogleFonts.notoSansKr(fontSize: 13, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 18,
                  color: AppTheme.textHint,
                ),
                onPressed: () => setState(() => _visible[keyId] = !isVisible),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testApiKey(String keyId, String key) async {
    setState(() => _testingFlags[keyId] = true);
    try {
      bool success = false;
      if (keyId == 'gemini') {
        final service = GeminiService(key.trim());
        final result = await service.generateThumbnailText('테스트', ChannelType.economy);
        success = result.isNotEmpty;
      } else if (keyId == 'elevenlabs') {
        // ElevenLabs: 키 형식 검증 (실제 호출은 비용 발생 가능)
        success = key.trim().length > 20;
      } else if (keyId == 'claude') {
        final service = ClaudeService(key.trim());
        final result = await service.generateScript(
          prompt: ChannelType.economy.defaultScriptPrompt,
          topic: 'API 연결 테스트',
          targetMinutes: 1,
          model: ScriptAiModel.claude4Sonnet,
        );
        success = result.isNotEmpty;
      }
      setState(() => _testResults[keyId] = success);
    } catch (_) {
      setState(() => _testResults[keyId] = false);
    } finally {
      setState(() => _testingFlags[keyId] = false);
    }
  }

  // ═══════════════════════════════════════════
  // 출력 설정 탭
  // ═══════════════════════════════════════════
  Widget _buildOutputTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            title: '📁 출력 폴더 설정',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('렌더링된 영상과 프로젝트 파일이 저장될 폴더',
                    style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _outputFolderCtrl,
                        decoration: const InputDecoration(
                          hintText: 'C:\\TubeMaster\\Output',
                          prefixIcon: Icon(Icons.folder_rounded, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      label: Text('찾아보기', style: GoogleFonts.notoSansKr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.bgElevated,
                        foregroundColor: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('폴더 구조 미리보기:',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.textHint, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    'C:\\TubeMaster\\Output\\\n'
                    '├── 경제채널\\\n'
                    '│   ├── 프로젝트명\\\n'
                    '│   │   ├── scenes\\  (장면 이미지/영상)\n'
                    '│   │   ├── audio\\   (TTS 음성)\n'
                    '│   │   ├── final.mp4 (완성 영상)\n'
                    '│   │   └── thumbnail.jpg\n'
                    '│   └── ...\n'
                    '└── ...',
                    style: GoogleFonts.sourceCodePro(
                        color: AppTheme.textSecondary, fontSize: 12, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionCard(
            title: '🔧 FFmpeg 설정',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.download_rounded, color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Text('FFmpeg 설치 안내',
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.primaryLight, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                        '1. https://ffmpeg.org/download.html 에서 Windows 버전 다운로드\n'
                        '2. C:\\ffmpeg\\bin 폴더에 압축 해제\n'
                        '3. 시스템 환경변수 PATH에 C:\\ffmpeg\\bin 추가\n'
                        '4. 명령 프롬프트에서 ffmpeg -version 으로 확인',
                        style: GoogleFonts.notoSansKr(
                            color: AppTheme.textSecondary, fontSize: 12, height: 1.7),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: Text('FFmpeg 다운로드', style: GoogleFonts.notoSansKr(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                          label: Text('설치 확인', style: GoogleFonts.notoSansKr(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.bgElevated,
                            foregroundColor: AppTheme.textPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 기본 영상 설정 탭
  // ═══════════════════════════════════════════
  Widget _buildVideoDefaultTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            title: '🎬 기본 영상 설정',
            child: Column(
              children: [
                _settingRow(
                  label: '기본 이미지 비율',
                  child: DropdownButton<String>(
                    value: '16:9',
                    dropdownColor: AppTheme.bgElevated,
                    style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary, fontSize: 13),
                    underline: const SizedBox(),
                    items: ['16:9 (가로)', '9:16 (세로)', '1:1 (정사각)', '4:3']
                        .map((v) => DropdownMenuItem(value: v.split(' ')[0], child: Text(v)))
                        .toList(),
                    onChanged: (_) {},
                  ),
                ),
                _settingRow(
                  label: '기본 해상도',
                  child: DropdownButton<String>(
                    value: '1080p',
                    dropdownColor: AppTheme.bgElevated,
                    style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary, fontSize: 13),
                    underline: const SizedBox(),
                    items: ['720p (HD)', '1080p (FHD)', '2K', '4K']
                        .map((v) => DropdownMenuItem(value: v.split(' ')[0], child: Text(v)))
                        .toList(),
                    onChanged: (_) {},
                  ),
                ),
                _settingRow(
                  label: '장면당 기본 시간',
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextField(
                          decoration: const InputDecoration(suffixText: '초', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                          controller: TextEditingController(text: '5'),
                        ),
                      ),
                    ],
                  ),
                ),
                _settingRow(
                  label: '화면 전환 시간',
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextField(
                          decoration: const InputDecoration(suffixText: '초', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                          controller: TextEditingController(text: '0.5'),
                        ),
                      ),
                    ],
                  ),
                ),
                _settingRow(
                  label: '줌 효과 기본값',
                  child: Switch(value: true, onChanged: (_) {}),
                ),
                _settingRow(
                  label: 'BGM 기본 사용',
                  child: Switch(value: true, onChanged: (_) {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionCard(
            title: '🖥️ 로컬 AI 영상 생성 설정',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '로컬 모델은 API 키 없이 완전 무료로 사용할 수 있습니다.\n'
                    '• AnimateDiff / SVD / SVD-XT → Automatic1111 WebUI 설치 필요\n'
                    '  설치: https://github.com/AUTOMATIC1111/stable-diffusion-webui\n'
                    '• Wan 2.1 / Wan 2.6 → ComfyUI 설치 필요\n'
                    '  설치: https://github.com/comfyanonymous/ComfyUI\n'
                    '실행 후 아래 URL이 맞는지 확인하세요.',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.textSecondary, fontSize: 11, height: 1.6),
                  ),
                ),
                _settingRow(
                  label: 'A1111 WebUI URL',
                  child: Expanded(
                    child: TextField(
                      controller: TextEditingController(text: 'http://127.0.0.1:7860'),
                      style: GoogleFonts.notoSansKr(fontSize: 13, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'http://127.0.0.1:7860',
                        hintStyle: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: AppTheme.bgDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        suffixIcon: TextButton(
                          onPressed: () {},
                          child: Text('연결 테스트',
                              style: GoogleFonts.notoSansKr(fontSize: 11, color: AppTheme.primary)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _settingRow(
                  label: 'ComfyUI URL',
                  child: Expanded(
                    child: TextField(
                      controller: TextEditingController(text: 'http://127.0.0.1:8188'),
                      style: GoogleFonts.notoSansKr(fontSize: 13, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'http://127.0.0.1:8188',
                        hintStyle: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: AppTheme.bgDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        suffixIcon: TextButton(
                          onPressed: () {},
                          child: Text('연결 테스트',
                              style: GoogleFonts.notoSansKr(fontSize: 11, color: AppTheme.primary)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionCard(
            title: '🔤 자막 기본 설정',
            child: Column(
              children: [
                _settingRow(
                  label: '자막 폰트',
                  child: DropdownButton<String>(
                    value: 'NotoSansKR',
                    dropdownColor: AppTheme.bgElevated,
                    style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary, fontSize: 13),
                    underline: const SizedBox(),
                    items: ['NotoSansKR', '나눔고딕', '나눔바른고딕', 'KoPubWorldDotum']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (_) {},
                  ),
                ),
                _settingRow(
                  label: '자막 크기',
                  child: Row(children: [
                    SizedBox(
                      width: 80,
                      child: TextField(
                        decoration: const InputDecoration(suffixText: 'px', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                        controller: TextEditingController(text: '36'),
                      ),
                    ),
                  ]),
                ),
                _settingRow(
                  label: '자막 위치',
                  child: DropdownButton<String>(
                    value: 'bottom',
                    dropdownColor: AppTheme.bgElevated,
                    style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary, fontSize: 13),
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(value: 'bottom', child: Text('하단 (일반)')),
                      DropdownMenuItem(value: 'center', child: Text('중앙')),
                      DropdownMenuItem(value: 'top', child: Text('상단')),
                    ],
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 정보 탭
  // ═══════════════════════════════════════════
  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            title: 'Tube Master',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('버전', 'v1.0.0'),
                _infoRow('플랫폼', 'Windows (Flutter)'),
                _infoRow('개발', 'AI 유튜브 자동화 도구'),
                const Divider(height: 24),
                Text('지원 기능', style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                ...[
                  '✅ AI 대본 생성 (Gemini / Claude)',
                  '✅ 대본 직접 입력 (3만자 이상 지원)',
                  '✅ 자동 장면 분할 (Gemini)',
                  '✅ AI 이미지 생성 (7가지 모델)',
                  '✅ AI 영상 생성 (7가지 모델)',
                  '✅ TTS 음성 생성 (4가지 엔진)',
                  '✅ 자막 자동 생성 + 편집',
                  '✅ FFmpeg 렌더링 (무료)',
                  '✅ 썸네일 자동 생성',
                  '✅ YouTube 예약 업로드',
                  '✅ 채널별 설정 저장',
                  '✅ 프로젝트 관리',
                ].map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(f, style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 13)),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(title,
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _settingRow({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 13)),
          ),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 13)),
          ),
          Text(value,
              style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }

  void _saveSettings(AppProvider provider) {
    final keys = ApiKeyModel(
      geminiApiKey: _geminiCtrl.text.trim(),
      claudeApiKey: _claudeCtrl.text.trim(),
      elevenLabsApiKey: _elevenLabsCtrl.text.trim(),
      clovaApiKey: _clovaKeyCtrl.text.trim(),
      clovaApiSecret: _clovaSecretCtrl.text.trim(),
      youtubeClientId: _ytClientIdCtrl.text.trim(),
      youtubeClientSecret: _ytClientSecretCtrl.text.trim(),
      stabilityApiKey: _stabilityCtrl.text.trim(),
      replicateApiKey: _replicateCtrl.text.trim(),
      falApiKey: _falCtrl.text.trim(),
      openAiApiKey: _openAiCtrl.text.trim(),
    );
    provider.updateApiKeys(keys);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('설정이 저장되었습니다!', style: GoogleFonts.notoSansKr(color: Colors.white)),
        ]),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
