import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_provider.dart';
import '../models/project_model.dart';
import '../models/channel_model.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildStatsRow(provider),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildRecentProjects(context, provider)),
                    const SizedBox(width: 20),
                    Expanded(child: _buildQuickStart(context, provider)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildWorkflowGuide(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting = hour < 12 ? '좋은 아침이에요!' : hour < 18 ? '안녕하세요!' : '수고하셨어요!';

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final hasNotifications = provider.notifications.isNotEmpty;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting,
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Tube Master',
                      style: GoogleFonts.notoSansKr(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      )),
                  Text('AI 유튜브 영상 자동화 시스템',
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.textSecondary, fontSize: 14)),
                ],
              ),
            ),
            // 알림 버튼
            Stack(
              children: [
                IconButton(
                  onPressed: () => _showNotificationsDialog(context, provider),
                  icon: const Icon(Icons.notifications_rounded),
                  color: hasNotifications ? AppTheme.warning : AppTheme.textSecondary,
                  iconSize: 24,
                  tooltip: '알림',
                ),
                if (hasNotifications)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppTheme.warning,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          provider.notifications.length > 9 ? '9+' : '${provider.notifications.length}',
                          style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            _buildNewProjectButton(context),
          ],
        );
      },
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1);
  }

  void _showNotificationsDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 480),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_rounded, color: AppTheme.warning, size: 20),
                  const SizedBox(width: 8),
                  Text('활동 알림',
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (provider.notifications.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        provider.clearNotifications();
                        Navigator.pop(ctx);
                      },
                      child: Text('모두 지우기', style: GoogleFonts.notoSansKr(fontSize: 12, color: AppTheme.textHint)),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 8),
              Flexible(
                child: provider.notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.notifications_none_rounded, color: AppTheme.textHint, size: 48),
                            const SizedBox(height: 12),
                            Text('새 알림이 없습니다',
                                style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: provider.notifications.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                        itemBuilder: (ctx, i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 8,
                                height: 8,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  provider.notifications[i],
                                  style: GoogleFonts.notoSansKr(
                                      color: AppTheme.textPrimary, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewProjectButton(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 워크플로우 안내 버튼
        OutlinedButton.icon(
          onPressed: () => _showWorkflowDialog(context),
          icon: const Icon(Icons.help_outline_rounded, size: 16),
          label: Text('사용 방법', style: GoogleFonts.notoSansKr(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            side: const BorderSide(color: AppTheme.border),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () {
            context.read<AppProvider>().setNavIndex(2);
          },
          icon: const Icon(Icons.add_rounded),
          label: Text('새 프로젝트', style: GoogleFonts.notoSansKr()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ],
    );
  }

  void _showWorkflowDialog(BuildContext context) {
    final steps = [
      {'icon': Icons.settings_rounded, 'color': const Color(0xFF9C27B0), 'title': '1단계: API 키 설정', 'desc': '설정 화면에서 Gemini API 키를 입력합니다. Gemini Flash는 무료로 사용 가능합니다.'},
      {'icon': Icons.tv_rounded, 'color': const Color(0xFF2196F3), 'title': '2단계: 채널 만들기', 'desc': '채널 유형(경제, 역사, 동화 등)을 선택하고 채널을 생성합니다. 채널별 AI 프롬프트를 커스텀할 수 있습니다.'},
      {'icon': Icons.article_rounded, 'color': const Color(0xFF4CAF50), 'title': '3단계: 대본 작성', 'desc': 'AI로 대본을 자동 생성하거나 직접 입력합니다. 생성된 대본을 10~30초 단위 장면으로 자동 분할합니다.'},
      {'icon': Icons.image_rounded, 'color': const Color(0xFFFF9800), 'title': '4단계: 미디어 생성', 'desc': '각 장면에 맞는 이미지를 AI로 생성합니다. Gemini Flash Image 모델은 무료 티어를 지원합니다.'},
      {'icon': Icons.volume_up_rounded, 'color': const Color(0xFF00BCD4), 'title': '5단계: TTS 음성 생성', 'desc': '대본을 AI 음성으로 변환합니다. Gemini TTS, ElevenLabs, 네이버 CLOVA 중 선택 가능합니다.'},
      {'icon': Icons.movie_rounded, 'color': const Color(0xFFE91E63), 'title': '6단계: 렌더링 & 업로드', 'desc': '생성된 미디어와 음성을 합쳐 최종 영상을 만들고 YouTube에 업로드합니다.'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: 560,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tube Master 사용 방법',
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('AI로 YouTube 영상을 자동 제작하는 6단계 워크플로우',
                            style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: steps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final step = steps[i];
                    final color = step['color'] as Color;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(step['icon'] as IconData, color: color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(step['title'] as String,
                                    style: GoogleFonts.notoSansKr(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 3),
                                Text(step['desc'] as String,
                                    style: GoogleFonts.notoSansKr(
                                        color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.read<AppProvider>().setNavIndex(2);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('시작하기 →', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(AppProvider provider) {
    final stats = [
      {'label': '전체 채널', 'value': '${provider.channels.length}', 'icon': Icons.tv_rounded, 'color': AppTheme.primary},
      {'label': '전체 프로젝트', 'value': '${provider.projects.length}', 'icon': Icons.video_library_rounded, 'color': AppTheme.accent},
      {'label': '완료된 영상', 'value': '${provider.projects.where((p) => p.status == ProjectStatus.uploaded).length}', 'icon': Icons.check_circle_rounded, 'color': AppTheme.success},
      {'label': '제작 중', 'value': '${provider.projects.where((p) => p.status != ProjectStatus.uploaded && p.status != ProjectStatus.draft).length}', 'icon': Icons.pending_rounded, 'color': AppTheme.warning},
    ];

    return Row(
      children: stats.asMap().entries.map((entry) {
        final stat = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: entry.key < stats.length - 1 ? 16 : 0),
            child: _StatCard(
              label: stat['label'] as String,
              value: stat['value'] as String,
              icon: stat['icon'] as IconData,
              color: stat['color'] as Color,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: (entry.key * 100).ms).slideY(begin: 0.2),
        );
      }).toList(),
    );
  }

  Widget _buildRecentProjects(BuildContext context, AppProvider provider) {
    final recent = provider.projects.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('최근 프로젝트',
                style: GoogleFonts.notoSansKr(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => context.read<AppProvider>().setNavIndex(2),
              child: Text('전체 보기', style: GoogleFonts.notoSansKr(color: AppTheme.primary, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          _buildEmptyState('아직 프로젝트가 없어요', '새 프로젝트를 만들어 시작해보세요!')
        else
          ...recent.map((p) => _ProjectListItem(project: p, provider: provider)),
      ],
    );
  }

  Widget _buildQuickStart(BuildContext context, AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('빠른 시작',
            style: GoogleFonts.notoSansKr(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (provider.channels.isEmpty)
          _buildSetupGuide(context)
        else
          _buildChannelQuickList(context, provider),
      ],
    );
  }

  Widget _buildSetupGuide(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.rocket_launch_rounded, color: AppTheme.primary, size: 40),
          const SizedBox(height: 12),
          Text('시작하기', style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('먼저 채널을 만들고\n설정을 완료해주세요', textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.read<AppProvider>().setNavIndex(1),
              child: Text('채널 만들기', style: GoogleFonts.notoSansKr()),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.read<AppProvider>().setNavIndex(6),
              child: Text('API 키 설정', style: GoogleFonts.notoSansKr()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelQuickList(BuildContext context, AppProvider provider) {
    return Column(
      children: provider.activeChannels.take(5).map((ch) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () {
            provider.selectChannel(ch);
            provider.setNavIndex(3);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Text(ch.type.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(ch.name,
                      style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary, fontSize: 13)),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textHint),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildWorkflowGuide(BuildContext context) {
    final steps = [
      {'icon': Icons.tv_rounded, 'title': '채널 설정', 'desc': '채널별 AI 프롬프트 저장', 'color': AppTheme.primary},
      {'icon': Icons.edit_note_rounded, 'title': '대본 입력', 'desc': 'AI 생성 또는 직접 입력', 'color': Color(0xFF9B6FF5)},
      {'icon': Icons.content_cut_rounded, 'title': '장면 분할', 'desc': 'Gemini가 자동 분할', 'color': AppTheme.accent},
      {'icon': Icons.image_rounded, 'title': '미디어 생성', 'desc': 'AI 이미지/영상 생성', 'color': Color(0xFFFF9563)},
      {'icon': Icons.record_voice_over_rounded, 'title': 'TTS + 자막', 'desc': '음성과 자막 자동 생성', 'color': AppTheme.success},
      {'icon': Icons.movie_creation_rounded, 'title': '렌더링', 'desc': 'FFmpeg 영상 합성', 'color': Color(0xFF00C896)},
      {'icon': Icons.upload_rounded, 'title': '유튜브 업로드', 'desc': '예약 업로드 지원', 'color': Color(0xFFFF4444)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('제작 워크플로우',
            style: GoogleFonts.notoSansKr(
                color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: steps.asMap().entries.map((entry) {
            final step = entry.value;
            final isLast = entry.key == steps.length - 1;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          Icon(step['icon'] as IconData,
                              color: step['color'] as Color, size: 24),
                          const SizedBox(height: 6),
                          Text(step['title'] as String,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.notoSansKr(
                                  color: AppTheme.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          Text(step['desc'] as String,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.notoSansKr(
                                  color: AppTheme.textHint, fontSize: 10)),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: (entry.key * 80).ms),
                  ),
                  if (!isLast)
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: AppTheme.textHint),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.inbox_rounded, color: AppTheme.textHint, size: 40),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.notoSansKr(color: AppTheme.textHint, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectListItem extends StatelessWidget {
  final ProjectModel project;
  final AppProvider provider;

  const _ProjectListItem({required this.project, required this.provider});

  @override
  Widget build(BuildContext context) {
    final channel = provider.getChannelById(project.channelId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          provider.setCurrentProject(project);
          provider.setNavIndex(3);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(channel?.type.emoji ?? '🎬', style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.title,
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(project.status.displayName,
                            style: GoogleFonts.notoSansKr(
                                color: AppTheme.textHint, fontSize: 11)),
                      ],
                    ),
                  ),
                  _StatusBadge(status: project.status),
                ],
              ),
              if (project.totalScenes > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: project.progress,
                          backgroundColor: AppTheme.border,
                          color: project.progress >= 1.0
                              ? AppTheme.success
                              : AppTheme.primary,
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${project.generatedScenes}/${project.totalScenes} 장면',
                      style: GoogleFonts.notoSansKr(
                          color: AppTheme.textHint, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ProjectStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ProjectStatus.uploaded: color = AppTheme.success; break;
      case ProjectStatus.draft: color = AppTheme.textHint; break;
      case ProjectStatus.rendering:
      case ProjectStatus.uploading:
      case ProjectStatus.mediaGenerating: color = AppTheme.warning; break;
      default: color = AppTheme.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(status.displayName,
          style: GoogleFonts.notoSansKr(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}
