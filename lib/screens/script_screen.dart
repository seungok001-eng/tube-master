import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/channel_model.dart';
import '../models/project_model.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';

class ScriptScreen extends StatefulWidget {
  const ScriptScreen({super.key});

  @override
  State<ScriptScreen> createState() => _ScriptScreenState();
}

class _ScriptScreenState extends State<ScriptScreen> {
  // 단계: 0=채널선택, 1=대본입력, 2=장면분할, 3=완료
  int _step = 0;
  bool _isCancelled = false;  // 생성 취소 플래그

  ChannelModel? _selectedChannel;
  ProjectModel? _project;

  final _titleCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _scriptCtrl = TextEditingController();
  int _targetMinutes = 20;
  ScriptAiModel _scriptModel = ScriptAiModel.geminiFlash;
  bool _isDirectInput = false;
  bool _isLoading = false;
  String _loadingMessage = '';
  List<SceneModel> _scenes = [];
  double _splitProgress = 0;

  // ── 인트로 관련 상태 ──
  bool _isGeneratingIntro = false;          // 인트로 생성 중
  List<String> _introVariants = [];         // 생성된 인트로 5가지
  int _selectedIntroIndex = -1;             // 선택된 인트로 인덱스 (-1=없음)
  String get _selectedIntroText =>
      _selectedIntroIndex >= 0 && _selectedIntroIndex < _introVariants.length
          ? _introVariants[_selectedIntroIndex]
              .replaceFirst(RegExp(r'^\[.*?\]\n'), '') // [스타일] 태그 제거
          : '';
  bool _showIntroPanel = false;             // 인트로 패널 표시 여부

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      if (provider.selectedChannel != null) {
        setState(() {
          _selectedChannel = provider.selectedChannel;
          _step = 1;
        });
      }
      if (provider.currentProject != null) {
        _loadProject(provider.currentProject!);
      }
    });
  }

  void _loadProject(ProjectModel p) {
    setState(() {
      _project = p;
      _titleCtrl.text = p.title;
      _scriptCtrl.text = p.script;
      _targetMinutes = p.targetMinutes;
      _scriptModel = p.scriptModel;
      _isDirectInput = p.isDirectInput;
      _scenes = List.from(p.scenes);
      _step = p.scenes.isNotEmpty ? 2 : 1;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _topicCtrl.dispose();
    _scriptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: Column(
            children: [
              _buildTopBar(provider),
              _buildStepIndicator(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingView()
                    : _buildStepContent(provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 24),
          const SizedBox(width: 12),
          Text('대본 작성',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          if (_selectedChannel != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedChannel!.type.emoji),
                  const SizedBox(width: 6),
                  Text(_selectedChannel!.name,
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.primaryLight, fontSize: 12)),
                ],
              ),
            ),
          ],
          const Spacer(),
          if (_step > 0)
            TextButton.icon(
              onPressed: () => setState(() {
                _step = 0;
                _selectedChannel = null;
                _scenes = [];
                _scriptCtrl.clear();
                _titleCtrl.clear();
                _topicCtrl.clear();
              }),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('새로 시작', style: GoogleFonts.notoSansKr(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['채널 선택', '대본 작성', '장면 분할', '미디어 생성'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final i = entry.key;
          final label = entry.value;
          final isActive = _step == i;
          final isDone = _step > i;
          // 완료된 단계 또는 현재 단계 이전은 클릭 가능
          final canNavigate = i < _step && !_isLoading;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: canNavigate ? () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.bgCard,
                          title: Text('${i + 1}단계로 돌아가기',
                              style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary)),
                          content: Text(
                            '"$label" 단계로 돌아갑니다.\n현재 단계 이후 작업은 유지되므로 언제든지 다시 진행할 수 있습니다.',
                            style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text('취소', style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary)),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => _step = i);
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                              child: Text('이동', style: GoogleFonts.notoSansKr(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    } : null,
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppTheme.success
                                : isActive
                                    ? AppTheme.primary
                                    : AppTheme.bgElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: isDone
                                    ? AppTheme.success
                                    : isActive
                                        ? AppTheme.primary
                                        : AppTheme.border),
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                : Text('${i + 1}',
                                    style: GoogleFonts.notoSansKr(
                                        color: isActive ? Colors.white : AppTheme.textHint,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: GoogleFonts.notoSansKr(
                                    color: isDone
                                        ? AppTheme.success
                                        : isActive
                                            ? AppTheme.textPrimary
                                            : AppTheme.textHint,
                                    fontSize: 13,
                                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
                            if (canNavigate)
                              Text('탭하여 돌아가기',
                                  style: GoogleFonts.notoSansKr(
                                      color: AppTheme.success.withValues(alpha: 0.7),
                                      fontSize: 9)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: isDone ? AppTheme.success : AppTheme.border,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(_loadingMessage,
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          if (_splitProgress > 0)
            Column(
              children: [
                const SizedBox(height: 12),
                SizedBox(
                  width: 300,
                  child: LinearProgressIndicator(
                    value: _splitProgress,
                    backgroundColor: AppTheme.border,
                    color: AppTheme.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${(_splitProgress * 100).toInt()}% 완료',
                    style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 12)),
              ],
            ),
          const SizedBox(height: 12),
          Text('AI가 작업 중이에요. 잠시만 기다려주세요...',
              style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _buildStepContent(AppProvider provider) {
    switch (_step) {
      case 0: return _buildChannelSelect(provider);
      case 1: return _buildScriptInput(provider);
      case 2: return _buildSceneSplit(provider);
      case 3: return _buildComplete(provider);
      default: return const SizedBox();
    }
  }

  // ═══════════════════════════════════════════
  // STEP 0: 채널 선택
  // ═══════════════════════════════════════════
  Widget _buildChannelSelect(AppProvider provider) {
    if (provider.channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.tv_off_rounded, color: AppTheme.textHint, size: 48),
            const SizedBox(height: 16),
            Text('먼저 채널을 만들어주세요',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('채널 관리에서 채널을 추가하세요',
                style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.setNavIndex(1),
              icon: const Icon(Icons.add_rounded),
              label: Text('채널 만들기', style: GoogleFonts.notoSansKr()),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('어떤 채널의 영상을 만들까요?',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('채널 선택 후 해당 채널의 프롬프트 설정이 자동으로 적용됩니다',
              style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: provider.channels.length,
            itemBuilder: (ctx, i) {
              final ch = provider.channels[i];
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedChannel = ch;
                    _step = 1;
                  });
                  provider.selectChannel(ch);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Text(ch.type.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(ch.name,
                                style: GoogleFonts.notoSansKr(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(ch.type.displayName,
                                style: GoogleFonts.notoSansKr(
                                    color: AppTheme.textHint, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: (i * 60).ms).slideX(begin: 0.05);
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // STEP 1: 대본 입력
  // ═══════════════════════════════════════════
  Widget _buildScriptInput(AppProvider provider) {
    final isLongScript = _selectedChannel?.type.isScriptBased ?? false;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 왼쪽: 설정 패널
        Container(
          width: 280,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppTheme.border)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('프로젝트 제목'),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(hintText: '영상 제목'),
                ),
                const SizedBox(height: 20),
                _sectionLabel('입력 방식'),
                const SizedBox(height: 8),
                _buildToggle(
                  leftLabel: 'AI 생성',
                  rightLabel: '직접 입력',
                  isRight: _isDirectInput,
                  onToggle: (v) => setState(() => _isDirectInput = v),
                ),
                if (isLongScript && !_isDirectInput) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '야담/역사/국뽕/사연은 3만자 대본이 일반적이에요. 직접 입력 권장!',
                            style: GoogleFonts.notoSansKr(color: AppTheme.warning, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_isDirectInput) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('대본 주제'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _topicCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        hintText: '예) 1997년 한국 IMF 외환위기의 숨겨진 진실'),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('AI 모델 선택'),
                  const SizedBox(height: 8),
                  // Gemini 2.5 그룹
                  _buildModelGroupHeader('🤖 Gemini 2.5', AppTheme.primary),
                  const SizedBox(height: 6),
                  ...[
                    ScriptAiModel.geminiFlash,
                    ScriptAiModel.geminiFlashLite,
                    ScriptAiModel.geminiPro,
                  ].map((m) => _buildModelOption(m, provider)),
                  const SizedBox(height: 10),
                  // Gemini 3.x 그룹
                  _buildModelGroupHeader('🚀 Gemini 3.x (최신)', AppTheme.accent),
                  const SizedBox(height: 6),
                  ...[
                    ScriptAiModel.gemini3Flash,
                    ScriptAiModel.gemini31FlashImage,
                    ScriptAiModel.gemini3ProImage,
                    ScriptAiModel.gemini31Pro,
                  ].map((m) => _buildModelOption(m, provider)),
                  const SizedBox(height: 10),
                  // Claude 4 그룹
                  _buildModelGroupHeader('🔥 Claude 4 (최신)', const Color(0xFFE8620A)),
                  const SizedBox(height: 6),
                  ...[
                    ScriptAiModel.claude4Sonnet,
                    ScriptAiModel.claudeSonnet45,
                    ScriptAiModel.claudeOpus4,
                    ScriptAiModel.claudeOpus45,
                  ].map((m) => _buildModelOption(m, provider)),
                  const SizedBox(height: 10),
                  // Claude 4.6 그룹
                  _buildModelGroupHeader('🚀 Claude 4.6 (최신)', const Color(0xFFB8320A)),
                  const SizedBox(height: 6),
                  ...[
                    ScriptAiModel.claudeSonnet46,
                    ScriptAiModel.claudeOpus46,
                  ].map((m) => _buildModelOption(m, provider)),
                  const SizedBox(height: 20),
                  _sectionLabel('목표 영상 길이'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              hintText: '1~180', suffixText: '분'),
                          controller: TextEditingController(text: '$_targetMinutes'),
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n >= 1 && n <= 180) {
                              setState(() => _targetMinutes = n);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('예상 글자수: ${_targetMinutes * 150}~${_targetMinutes * 200}자',
                      style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 11)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isDirectInput ? null : _generateScript,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text('AI 대본 생성', style: GoogleFonts.notoSansKr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      disabledBackgroundColor: AppTheme.bgElevated,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                // ── 인트로 생성 섹션 ──
                if (!_isDirectInput) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildIntroSection(),
                ],
              ],
            ),
          ),
        ),
        // 오른쪽: 대본 에디터
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    Text('📝 대본 에디터',
                        style: GoogleFonts.notoSansKr(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    if (_scriptCtrl.text.isNotEmpty)
                      Text(
                        '${_scriptCtrl.text.length}자',
                        style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 12),
                      ),
                    const Spacer(),
                    if (_scriptCtrl.text.isNotEmpty) ...[
                      TextButton.icon(
                        onPressed: () => setState(() => _scriptCtrl.clear()),
                        icon: const Icon(Icons.clear_rounded, size: 14),
                        label: Text('지우기', style: GoogleFonts.notoSansKr(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _scriptCtrl.text.isNotEmpty ? _goToSceneSplit : null,
                        icon: const Icon(Icons.content_cut_rounded, size: 16),
                        label: Text('장면 분할하기', style: GoogleFonts.notoSansKr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextField(
                    controller: _scriptCtrl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.textPrimary, fontSize: 14, height: 1.8),
                    decoration: InputDecoration(
                      hintText: _isDirectInput
                          ? '여기에 대본을 붙여넣기 하세요...\n\n3만자 이상도 OK! Ctrl+A, Ctrl+V로 전체 붙여넣기 하세요.'
                          : 'AI 생성 버튼을 누르거나 직접 입력하세요...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModelGroupHeader(String title, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Text(
        title,
        style: GoogleFonts.notoSansKr(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildModelOption(ScriptAiModel model, AppProvider provider) {
    final isSelected = _scriptModel == model;
    final needsKey = model.isClaude && !provider.apiKeys.hasClaude;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: needsKey ? null : () => setState(() => _scriptModel = model),
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: needsKey ? 0.4 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 16,
                  color: isSelected ? AppTheme.primary : AppTheme.textHint,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model.displayName,
                          style: GoogleFonts.notoSansKr(
                              color: isSelected ? AppTheme.primaryLight : AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                      if (needsKey)
                        Text('API 키 필요',
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.warning, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // STEP 2: 장면 분할
  // ═══════════════════════════════════════════
  Widget _buildSceneSplit(AppProvider provider) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Text('✂️ 장면 분할 결과',
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('총 ${_scenes.length}장면',
                    style: GoogleFonts.notoSansKr(color: AppTheme.primaryLight, fontSize: 12)),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _goToSceneSplit,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('재분할', style: GoogleFonts.notoSansKr(fontSize: 13)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _scenes.isNotEmpty ? () => _saveAndGoNext(provider) : null,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text('미디어 생성으로', style: GoogleFonts.notoSansKr()),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _scenes.length,
            itemBuilder: (ctx, i) => _SceneCard(
              scene: _scenes[i],
              index: i,
              onDelete: () => setState(() => _scenes.removeAt(i)),
              onEditScript: (text) => setState(() => _scenes[i].scriptText = text),
              onEditPrompt: (text) => setState(() => _scenes[i].imagePrompt = text),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // STEP 3: 완료
  // ═══════════════════════════════════════════
  Widget _buildComplete(AppProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 48),
          ),
          const SizedBox(height: 20),
          Text('대본 작업 완료!',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('총 ${_scenes.length}개 장면으로 분할되었습니다',
              style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 12),
          Text('잠시 후 미디어 생성 화면으로 이동합니다...',
              style: GoogleFonts.notoSansKr(color: AppTheme.accent, fontSize: 13)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => provider.setNavIndex(4),
            icon: const Icon(Icons.image_rounded),
            label: Text('미디어 생성으로 이동', style: GoogleFonts.notoSansKr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _step = 2),
            child: Text('장면 목록으로 돌아가기', style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary)),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }

  // ═══════════════════════════════════════════
  // 액션 메서드
  // ═══════════════════════════════════════════
  // ═══════════════════════════════════════════
  // 인트로 5가지 생성
  // ═══════════════════════════════════════════
  // ═══════════════════════════════════════════
  // 인트로 섹션 UI
  // ═══════════════════════════════════════════
  Widget _buildIntroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          children: [
            const Icon(Icons.record_voice_over_rounded, size: 14, color: AppTheme.accent),
            const SizedBox(width: 6),
            Text('🎬 인트로 생성',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (_introVariants.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _showIntroPanel = !_showIntroPanel),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(40, 24)),
                child: Text(_showIntroPanel ? '접기' : '펼치기',
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.textHint, fontSize: 10)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('주제에 맞는 인트로 5가지를 생성하고\n마음에 드는 것을 선택하세요.',
            style: GoogleFonts.notoSansKr(
                color: AppTheme.textHint, fontSize: 10, height: 1.4)),
        const SizedBox(height: 8),
        // 생성 버튼
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isGeneratingIntro ? null : _generateIntroVariants,
                icon: _isGeneratingIntro
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.flash_on_rounded, size: 16),
                label: Text(
                  _isGeneratingIntro ? '생성 중...' : '인트로 5가지 생성',
                  style: GoogleFonts.notoSansKr(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (_selectedIntroIndex >= 0) ...[
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: _applyIntroToScript,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                ),
                child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              ),
            ],
          ],
        ),
        // 선택된 인트로 표시
        if (_selectedIntroIndex >= 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selectedIntroText,
                    style: GoogleFonts.notoSansKr(
                        color: AppTheme.success, fontSize: 10, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        // 인트로 목록
        if (_introVariants.isNotEmpty && _showIntroPanel) ...[
          const SizedBox(height: 8),
          ..._introVariants.asMap().entries.map((entry) {
            final idx = entry.key;
            final raw = entry.value;
            // [스타일] 태그 파싱
            final styleMatch = RegExp(r'^\[(.*?)\]').firstMatch(raw);
            final styleLabel = styleMatch?.group(1) ?? '버전 ${idx + 1}';
            final bodyText = raw.replaceFirst(RegExp(r'^\[.*?\]\n?'), '').trim();
            final isSelected = _selectedIntroIndex == idx;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedIntroIndex = isSelected ? -1 : idx;
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accent.withValues(alpha: 0.12)
                      : AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accent
                        : AppTheme.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accent
                                : AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            styleLabel,
                            style: GoogleFonts.notoSansKr(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              size: 14, color: AppTheme.accent),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bodyText,
                      style: GoogleFonts.notoSansKr(
                        color: isSelected
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Future<void> _generateIntroVariants() async {
    final provider = context.read<AppProvider>();
    if (_topicCtrl.text.trim().isEmpty) {
      _showError('인트로 생성 전에 대본 주제를 먼저 입력해주세요.');
      return;
    }
    if (!provider.apiKeys.hasGemini) {
      _showError('Gemini API 키가 필요합니다.');
      return;
    }

    setState(() {
      _isGeneratingIntro = true;
      _introVariants = [];
      _selectedIntroIndex = -1;
      _showIntroPanel = true;
    });

    try {
      final service = GeminiService(provider.apiKeys.geminiApiKey);
      final variants = await service.generateIntroVariants(
        topic: _topicCtrl.text.trim(),
        channelType: _selectedChannel!.type,
        model: _scriptModel,
        introPrompt: _selectedChannel!.introPrompt,
      );
      setState(() => _introVariants = variants);
    } catch (e) {
      _showError('인트로 생성 실패: $e');
    } finally {
      setState(() => _isGeneratingIntro = false);
    }
  }

  // 선택된 인트로를 대본 앞에 삽입
  void _applyIntroToScript() {
    if (_selectedIntroText.isEmpty) return;
    final current = _scriptCtrl.text;
    final intro = _selectedIntroText.trim();
    if (current.startsWith(intro)) return; // 이미 삽입됨
    _scriptCtrl.text = '$intro\n\n$current';
    _showSnackBar('✅ 인트로가 대본 앞에 삽입되었습니다.');
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.notoSansKr()),
        backgroundColor: AppTheme.bgElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _generateScript() async {
    final provider = context.read<AppProvider>();
    if (!provider.apiKeys.hasGemini && _scriptModel.isGemini) {
      _showError('Gemini API 키가 설정되지 않았습니다.\n설정 화면에서 API 키를 입력해주세요.');
      return;
    }
    if (!provider.apiKeys.hasClaude && _scriptModel.isClaude) {
      _showError('Claude API 키가 설정되지 않았습니다.\n설정 화면에서 API 키를 입력해주세요.');
      return;
    }
    if (_topicCtrl.text.trim().isEmpty) {
      _showError('대본 주제를 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _isCancelled = false;
      _loadingMessage = 'AI가 대본을 작성 중입니다...';
    });

    try {
      String result;
      if (_scriptModel.isGemini) {
        final service = GeminiService(provider.apiKeys.geminiApiKey);
        result = await service.generateScript(
          prompt: _selectedChannel!.scriptPrompt,
          topic: _topicCtrl.text.trim(),
          targetMinutes: _targetMinutes,
          model: _scriptModel,
        );
      } else {
        final service = ClaudeService(provider.apiKeys.claudeApiKey);
        result = await service.generateScript(
          prompt: _selectedChannel!.scriptPrompt,
          topic: _topicCtrl.text.trim(),
          targetMinutes: _targetMinutes,
          model: _scriptModel,
        );
      }
      // 선택된 인트로가 있으면 대본 앞에 삽입
      if (_selectedIntroText.isNotEmpty) {
        result = '${_selectedIntroText.trim()}\n\n$result';
      }
      setState(() => _scriptCtrl.text = result);
    } catch (e) {
      _showError('대본 생성 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _goToSceneSplit() async {
    final provider = context.read<AppProvider>();
    if (!provider.apiKeys.hasGemini) {
      _showError('장면 분할에는 Gemini API 키가 필요합니다.\n설정 화면에서 API 키를 입력해주세요.');
      return;
    }
    if (_scriptCtrl.text.trim().isEmpty) {
      _showError('먼저 대본을 입력하거나 생성해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Gemini가 장면을 분할 중입니다...';
      _splitProgress = 0;
    });

    try {
      final service = GeminiService(provider.apiKeys.geminiApiKey);
      setState(() => _splitProgress = 0.3);
      final splitResult = await service.splitScenes(
        script: _scriptCtrl.text.trim(),
        channelType: _selectedChannel!.type,
      );
      setState(() => _splitProgress = 0.8);

      final videoSettings = _selectedChannel!.videoSettings;
      _scenes = splitResult.asMap().entries.map((entry) {
        final useAiVideo = entry.key < videoSettings.aiVideoSceneCount &&
            videoSettings.style != VideoStyle.slideshow;
        return SceneModel(
          id: const Uuid().v4(),
          order: entry.key,
          scriptText: entry.value['script'] ?? '',
          imagePrompt: entry.value['imagePrompt'] ?? '',
          useAiVideo: useAiVideo,
        );
      }).toList();

      setState(() {
        _splitProgress = 1.0;
        _step = 2;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('장면 분할 실패: $e');
    }
  }

  Future<void> _saveAndGoNext(AppProvider provider) async {
    if (_titleCtrl.text.trim().isEmpty) {
      _showError('프로젝트 제목을 입력해주세요.');
      return;
    }

    final project = ProjectModel(
      id: _project?.id ?? const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      channelId: _selectedChannel!.id,
      channelType: _selectedChannel!.type,
      status: ProjectStatus.sceneSplit,
      script: _scriptCtrl.text,
      scriptModel: _scriptModel,
      targetMinutes: _targetMinutes,
      isDirectInput: _isDirectInput,
      scenes: _scenes,
      updatedAt: DateTime.now(),
    );

    if (_project == null) {
      await provider.addProject(project);
    } else {
      await provider.updateProject(project);
    }
    provider.setCurrentProject(project);
    provider.addNotification('📝 "${project.title}" 장면 분할 완료 (${_scenes.length}개 장면)');

    setState(() => _step = 3);

    // 2초 후 자동으로 미디어 생성 화면으로 이동
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        provider.setNavIndex(4);
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.notoSansKr()),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: GoogleFonts.notoSansKr(
          color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600));

  Widget _buildToggle({
    required String leftLabel,
    required String rightLabel,
    required bool isRight,
    required Function(bool) onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !isRight ? AppTheme.primary : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                ),
                child: Text(leftLabel,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansKr(
                        color: !isRight ? Colors.white : AppTheme.textHint,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isRight ? AppTheme.primary : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                ),
                child: Text(rightLabel,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansKr(
                        color: isRight ? Colors.white : AppTheme.textHint,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// 장면 카드 위젯
// ═══════════════════════════════════════════
class _SceneCard extends StatefulWidget {
  final SceneModel scene;
  final int index;
  final VoidCallback onDelete;
  final Function(String) onEditScript;
  final Function(String) onEditPrompt;

  const _SceneCard({
    required this.scene,
    required this.index,
    required this.onDelete,
    required this.onEditScript,
    required this.onEditPrompt,
  });

  @override
  State<_SceneCard> createState() => _SceneCardState();
}

class _SceneCardState extends State<_SceneCard> {
  bool _isExpanded = false;
  late TextEditingController _scriptCtrl;
  late TextEditingController _promptCtrl;

  @override
  void initState() {
    super.initState();
    _scriptCtrl = TextEditingController(text: widget.scene.scriptText);
    _promptCtrl = TextEditingController(text: widget.scene.imagePrompt);
  }

  @override
  void dispose() {
    _scriptCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('${widget.index + 1}',
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.primaryLight,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.scene.scriptText,
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.textPrimary, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (widget.scene.useAiVideo)
                                _chip('AI 영상', AppTheme.accent),
                              if (!widget.scene.useAiVideo)
                                _chip('이미지', AppTheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.scene.scriptText.length}자',
                                style: GoogleFonts.notoSansKr(
                                    color: AppTheme.textHint, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.textHint),
                      visualDensity: VisualDensity.compact,
                    ),
                    Icon(
                      _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppTheme.textHint,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text('장면 대본',
                        style: GoogleFonts.notoSansKr(
                            color: AppTheme.textHint, fontSize: 11)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _scriptCtrl,
                      maxLines: 4,
                      style: GoogleFonts.notoSansKr(fontSize: 13, height: 1.6),
                      onChanged: widget.onEditScript,
                    ),
                    const SizedBox(height: 12),
                    Text('이미지 프롬프트 (영어)',
                        style: GoogleFonts.notoSansKr(
                            color: AppTheme.textHint, fontSize: 11)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _promptCtrl,
                      maxLines: 2,
                      style: GoogleFonts.notoSansKr(fontSize: 13),
                      onChanged: widget.onEditPrompt,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ).animate().fadeIn(duration: 200.ms, delay: (widget.index * 30).ms),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label,
        style: GoogleFonts.notoSansKr(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
  );
}
