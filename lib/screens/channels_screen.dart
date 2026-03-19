import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/channel_model.dart';
import '../theme/app_theme.dart';

class ChannelsScreen extends StatelessWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, provider),
                const SizedBox(height: 24),
                Expanded(
                  child: provider.channels.isEmpty
                      ? _buildEmpty(context, provider)
                      : _buildChannelGrid(context, provider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AppProvider provider) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('채널 관리',
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
              Text('${provider.channels.length}개 채널',
                  style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 14)),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showAddChannelDialog(context, provider),
          icon: const Icon(Icons.add_rounded),
          label: Text('새 채널 추가', style: GoogleFonts.notoSansKr()),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context, AppProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.tv_rounded, color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 20),
          Text('아직 채널이 없어요', style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('채널을 추가하고 AI 설정을 저장해두세요', style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddChannelDialog(context, provider),
            icon: const Icon(Icons.add_rounded),
            label: Text('첫 채널 만들기', style: GoogleFonts.notoSansKr()),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildChannelGrid(BuildContext context, AppProvider provider) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        childAspectRatio: 1.1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: provider.channels.length,
      itemBuilder: (context, index) => _ChannelCard(
        channel: provider.channels[index],
        onEdit: () => _showEditChannelDialog(context, provider, provider.channels[index]),
        onDelete: () => _confirmDelete(context, provider, provider.channels[index]),
        onSelect: () {
          provider.selectChannel(provider.channels[index]);
          provider.setNavIndex(3);
        },
      ).animate().fadeIn(duration: 300.ms, delay: (index * 60).ms).scale(begin: const Offset(0.95, 0.95)),
    );
  }

  void _showAddChannelDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => _ChannelDialog(
        onSave: (channel) => provider.addChannel(channel),
      ),
    );
  }

  void _showEditChannelDialog(BuildContext context, AppProvider provider, ChannelModel channel) {
    showDialog(
      context: context,
      builder: (ctx) => _ChannelDialog(
        channel: channel,
        onSave: (updated) => provider.updateChannel(updated),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppProvider provider, ChannelModel channel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('채널 삭제', style: GoogleFonts.notoSansKr()),
        content: Text('"${channel.name}" 채널을 삭제할까요?', style: GoogleFonts.notoSansKr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('취소', style: GoogleFonts.notoSansKr())),
          ElevatedButton(
            onPressed: () {
              provider.deleteChannel(channel.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('삭제', style: GoogleFonts.notoSansKr()),
          ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final ChannelModel channel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSelect;

  const _ChannelCard({
    required this.channel,
    required this.onEdit,
    required this.onDelete,
    required this.onSelect,
  });

  Color get _themeColor {
    switch (channel.type) {
      case ChannelType.economy: return const Color(0xFF4CAF50);
      case ChannelType.patriot: return const Color(0xFF2196F3);
      case ChannelType.folklore: return const Color(0xFFFF9800);
      case ChannelType.story: return const Color(0xFF9C27B0);
      case ChannelType.bible: return const Color(0xFFFFD700);
      case ChannelType.buddhism: return const Color(0xFFFF7043);
      case ChannelType.psychology: return const Color(0xFF00BCD4);
      case ChannelType.history: return const Color(0xFF795548);
      case ChannelType.asmr: return const Color(0xFF607D8B);
      case ChannelType.playlist: return const Color(0xFFE91E63);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = _themeColor;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tc.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(channel.type.emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textHint, size: 18),
                    color: AppTheme.bgElevated,
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        onTap: onEdit,
                        child: Row(children: [
                          const Icon(Icons.edit_rounded, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text('편집', style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary)),
                        ]),
                      ),
                      PopupMenuItem(
                        onTap: onDelete,
                        child: Row(children: [
                          const Icon(Icons.delete_rounded, size: 16, color: AppTheme.error),
                          const SizedBox(width: 8),
                          Text('삭제', style: GoogleFonts.notoSansKr(color: AppTheme.error)),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(channel.name,
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tc.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(channel.type.displayName,
                    style: GoogleFonts.notoSansKr(color: tc, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    channel.youtubeChannelId.isNotEmpty ? Icons.check_circle_rounded : Icons.link_off_rounded,
                    size: 14,
                    color: channel.youtubeChannelId.isNotEmpty ? AppTheme.success : AppTheme.textHint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    channel.youtubeChannelId.isNotEmpty ? 'YouTube 연결됨' : 'YouTube 미연결',
                    style: GoogleFonts.notoSansKr(
                        color: channel.youtubeChannelId.isNotEmpty ? AppTheme.success : AppTheme.textHint,
                        fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelDialog extends StatefulWidget {
  final ChannelModel? channel;
  final Function(ChannelModel) onSave;

  const _ChannelDialog({this.channel, required this.onSave});

  @override
  State<_ChannelDialog> createState() => _ChannelDialogState();
}

class _ChannelDialogState extends State<_ChannelDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _scriptPromptCtrl;
  late TextEditingController _imagePromptCtrl;
  late TextEditingController _musicPromptCtrl;
  late TextEditingController _lyricsPromptCtrl;
  late TextEditingController _introPromptCtrl;
  late TextEditingController _ytChannelIdCtrl;
  late ChannelType _selectedType;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    final ch = widget.channel;
    _selectedType = ch?.type ?? ChannelType.economy;
    _nameCtrl = TextEditingController(text: ch?.name ?? '');
    _scriptPromptCtrl = TextEditingController(text: ch?.scriptPrompt ?? _selectedType.defaultScriptPrompt);
    _imagePromptCtrl = TextEditingController(text: ch?.imagePrompt ?? '');
    _musicPromptCtrl = TextEditingController(text: ch?.musicPrompt ?? '');
    _lyricsPromptCtrl = TextEditingController(text: ch?.lyricsPrompt ?? '');
    _introPromptCtrl = TextEditingController(text: ch?.introPrompt ?? '');
    _ytChannelIdCtrl = TextEditingController(text: ch?.youtubeChannelId ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scriptPromptCtrl.dispose();
    _imagePromptCtrl.dispose();
    _musicPromptCtrl.dispose();
    _lyricsPromptCtrl.dispose();
    _introPromptCtrl.dispose();
    _ytChannelIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.channel == null;
    return Dialog(
      child: Container(
        width: 680,
        height: 620,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(isNew ? '새 채널 추가' : '채널 편집',
                    style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 16),
            // 탭
            Row(
              children: ['기본 설정', '대본 프롬프트', '이미지/음악 프롬프트', 'YouTube'].asMap().entries.map((e) {
                final selected = _tabIndex == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () => setState(() => _tabIndex = e.key),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: selected ? Border.all(color: AppTheme.primary.withValues(alpha: 0.5)) : null,
                      ),
                      child: Text(e.value,
                          style: GoogleFonts.notoSansKr(
                              color: selected ? AppTheme.primaryLight : AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildTabContent()),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('취소', style: GoogleFonts.notoSansKr())),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _save,
                  child: Text(isNew ? '추가' : '저장', style: GoogleFonts.notoSansKr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tabIndex) {
      case 0: return _buildBasicTab();
      case 1: return _buildScriptPromptTab();
      case 2: return _buildMediaPromptTab();
      case 3: return _buildYoutubeTab();
      default: return const SizedBox();
    }
  }

  Widget _buildBasicTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('채널 이름'),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(hintText: '채널 이름을 입력하세요'),
          ),
          const SizedBox(height: 20),
          _label('채널 유형'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ChannelType.values.map((type) {
              final selected = _selectedType == type;
              return InkWell(
                onTap: () => setState(() {
                  _selectedType = type;
                  if (_scriptPromptCtrl.text.isEmpty || _scriptPromptCtrl.text == _selectedType.defaultScriptPrompt) {
                    _scriptPromptCtrl.text = type.defaultScriptPrompt;
                  }
                }),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected ? AppTheme.primary : AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(type.emoji),
                      const SizedBox(width: 6),
                      Text(type.displayName,
                          style: GoogleFonts.notoSansKr(
                              color: selected ? AppTheme.primaryLight : AppTheme.textSecondary,
                              fontSize: 13)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptPromptTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _label('대본 생성 프롬프트'),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _scriptPromptCtrl.text = _selectedType.defaultScriptPrompt),
              child: Text('기본값으로 복원', style: GoogleFonts.notoSansKr(fontSize: 12, color: AppTheme.textHint)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('AI가 대본 생성 시 사용할 시스템 프롬프트입니다',
            style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 12)),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: _scriptPromptCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: '대본 생성에 사용할 프롬프트를 입력하세요...',
              alignLabelWithHint: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaPromptTab() {
    final isAsmrOrPlaylist = _selectedType == ChannelType.asmr || _selectedType == ChannelType.playlist;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('이미지 생성 프롬프트 (기본 스타일)'),
          const SizedBox(height: 4),
          Text('각 장면 이미지 생성 시 추가되는 스타일 프롬프트',
              style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _imagePromptCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '예) cinematic, high quality, 8K, dramatic lighting...',
            ),
          ),
          const SizedBox(height: 20),
          // ── 인트로 프롬프트 ──
          _label('🎬 인트로 생성 프롬프트'),
          const SizedBox(height: 4),
          Text(
            '비워두면 AI가 채널 유형에 맞는 인트로를 자동 생성합니다.\n'
            '원하는 인트로 스타일을 자유롭게 기술하세요.',
            style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _introPromptCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText:
                  '예) 시청자를 충격에 빠뜨리는 반전 사실로 시작. "당신이 몰랐던" 형식. '
                  '강렬한 질문으로 끝내기. 말투는 친근한 구어체.',
            ),
          ),
          if (isAsmrOrPlaylist) ...[
            const SizedBox(height: 20),
            _label('음악 생성 프롬프트'),
            const SizedBox(height: 8),
            TextField(
              controller: _musicPromptCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '예) lofi hip hop, relaxing piano, 90 BPM, C minor...',
              ),
            ),
            const SizedBox(height: 20),
            _label('가사 생성 프롬프트'),
            const SizedBox(height: 8),
            TextField(
              controller: _lyricsPromptCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '가사 생성을 위한 프롬프트 (플레이리스트 채널용)...',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildYoutubeTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('YouTube 채널 ID'),
          const SizedBox(height: 4),
          Text('설정 > API 키에서 YouTube OAuth를 먼저 설정해주세요',
              style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _ytChannelIdCtrl,
            decoration: const InputDecoration(
              hintText: 'UCxxxxxxxxxxxxxxxxxxxxxxxx',
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppTheme.textHint, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'YouTube 업로드 기능을 사용하려면 Google Cloud Console에서 YouTube Data API v3를 활성화하고 OAuth 2.0 자격증명을 설정해야 합니다.',
                    style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(text,
        style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600));
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final ch = widget.channel;
    final updated = ChannelModel(
      id: ch?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      type: _selectedType,
      youtubeChannelId: _ytChannelIdCtrl.text.trim(),
      scriptPrompt: _scriptPromptCtrl.text.trim(),
      imagePrompt: _imagePromptCtrl.text.trim(),
      musicPrompt: _musicPromptCtrl.text.trim(),
      lyricsPrompt: _lyricsPromptCtrl.text.trim(),
      introPrompt: _introPromptCtrl.text.trim(),
      ttsSettings: ch?.ttsSettings ?? TtsSettings(),
      videoSettings: ch?.videoSettings ?? VideoSettings(),
      thumbnailSettings: ch?.thumbnailSettings ?? ThumbnailSettings(),
      createdAt: ch?.createdAt ?? DateTime.now(),
    );
    widget.onSave(updated);
    Navigator.pop(context);
  }
}
