import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_provider.dart';
import '../models/project_model.dart';
import '../models/channel_model.dart';
import '../theme/app_theme.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  String _filterStatus = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final filtered = _getFiltered(provider);
        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: Column(
            children: [
              _buildHeader(context, provider),
              _buildFilterBar(provider),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmpty(context, provider)
                    : _buildProjectList(context, provider, filtered),
              ),
            ],
          ),
        );
      },
    );
  }

  List<ProjectModel> _getFiltered(AppProvider provider) {
    return provider.projects.where((p) {
      final statusOk = _filterStatus == 'all' || p.status.name == _filterStatus;
      final searchOk = _searchQuery.isEmpty ||
          p.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return statusOk && searchOk;
    }).toList();
  }

  Widget _buildHeader(BuildContext context, AppProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.video_library_rounded, color: AppTheme.primary, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('프로젝트 관리',
                  style: GoogleFonts.notoSansKr(
                      color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              Text('총 ${provider.projects.length}개 프로젝트',
                  style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 220,
            child: TextField(
              decoration: const InputDecoration(
                hintText: '프로젝트 검색...',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => provider.setNavIndex(3),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('새 프로젝트', style: GoogleFonts.notoSansKr()),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AppProvider provider) {
    // 상태별 카운트
    final counts = <String, int>{'all': provider.projects.length};
    for (final p in provider.projects) {
      counts[p.status.name] = (counts[p.status.name] ?? 0) + 1;
    }

    final filters = [
      ('all', '전체', null),
      ('draft', '초안', AppTheme.textHint),
      ('sceneSplit', '장면분할', AppTheme.primary),
      ('mediaGenerating', '생성중', AppTheme.warning),
      ('mediaReady', '미디어완료', AppTheme.accent),
      ('ttsReady', 'TTS완료', AppTheme.accent),
      ('rendered', '렌더완료', AppTheme.success),
      ('uploaded', '업로드완료', AppTheme.success),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: filters.map((f) {
          final selected = _filterStatus == f.$1;
          final count = counts[f.$1] ?? 0;
          if (f.$1 != 'all' && count == 0) return const SizedBox.shrink();
          final color = f.$3 ?? AppTheme.primary;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _filterStatus = f.$1),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: selected ? color : AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(f.$2,
                        style: GoogleFonts.notoSansKr(
                            color: selected ? color : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: selected ? color.withValues(alpha: 0.25) : AppTheme.bgElevated,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$count',
                            style: GoogleFonts.notoSansKr(
                                color: selected ? color : AppTheme.textHint,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.video_library_outlined, color: AppTheme.textHint, size: 36),
          ),
          const SizedBox(height: 16),
          Text('프로젝트가 없어요',
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('대본 작성에서 새 프로젝트를 만들어보세요',
              style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => provider.setNavIndex(3),
            icon: const Icon(Icons.edit_note_rounded),
            label: Text('대본 작성 시작', style: GoogleFonts.notoSansKr()),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildProjectList(
      BuildContext context, AppProvider provider, List<ProjectModel> projects) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: projects.length,
      itemBuilder: (ctx, i) {
        final channel = provider.getChannelById(projects[i].channelId);
        return _ProjectCard(
          project: projects[i],
          channel: channel,
          onOpen: () {
            provider.setCurrentProject(projects[i]);
            final idx = projects[i].status.index;
            if (idx < ProjectStatus.sceneSplit.index) {
              provider.setNavIndex(3);
            } else if (idx < ProjectStatus.ttsReady.index) {
              provider.setNavIndex(4);
            } else {
              provider.setNavIndex(5);
            }
          },
          onDelete: () => _confirmDelete(context, provider, projects[i]),
          onDuplicate: () => _duplicateProject(provider, projects[i]),
        ).animate().fadeIn(duration: 250.ms, delay: (i * 40).ms).slideY(begin: 0.05);
      },
    );
  }

  void _confirmDelete(BuildContext context, AppProvider provider, ProjectModel project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('프로젝트 삭제', style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary)),
        content: Text('"${project.title}" 프로젝트를 삭제할까요?\n이 작업은 되돌릴 수 없습니다.',
            style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('취소', style: GoogleFonts.notoSansKr(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () {
              provider.deleteProject(project.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('삭제', style: GoogleFonts.notoSansKr()),
          ),
        ],
      ),
    );
  }

  void _duplicateProject(AppProvider provider, ProjectModel project) {
    final copy = ProjectModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '${project.title} (복사)',
      channelId: project.channelId,
      channelType: project.channelType,
      status: ProjectStatus.draft,
      script: project.script,
      scriptModel: project.scriptModel,
      targetMinutes: project.targetMinutes,
      isDirectInput: project.isDirectInput,
      scenes: [],
    );
    provider.addProject(copy);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('프로젝트가 복사되었습니다.', style: GoogleFonts.notoSansKr()),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─── 워크플로우 단계 정의 ─────────────────────────────
class _WorkflowStep {
  final String label;
  final IconData icon;
  final List<ProjectStatus> statuses;
  final int navIndex;
  const _WorkflowStep(this.label, this.icon, this.statuses, this.navIndex);
}

final _workflowSteps = [
  _WorkflowStep('대본', Icons.edit_note_rounded,
      [ProjectStatus.draft, ProjectStatus.scriptReady, ProjectStatus.sceneSplit], 3),
  _WorkflowStep('미디어', Icons.image_rounded,
      [ProjectStatus.mediaGenerating, ProjectStatus.mediaReady, ProjectStatus.ttsReady, ProjectStatus.subtitleReady], 4),
  _WorkflowStep('렌더링', Icons.movie_creation_rounded,
      [ProjectStatus.rendering, ProjectStatus.rendered, ProjectStatus.thumbnailReady], 5),
  _WorkflowStep('업로드', Icons.upload_rounded,
      [ProjectStatus.uploading, ProjectStatus.uploaded], 5),
];

// ─── 프로젝트 카드 ────────────────────────────────────
class _ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final ChannelModel? channel;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const _ProjectCard({
    required this.project,
    required this.channel,
    required this.onOpen,
    required this.onDelete,
    required this.onDuplicate,
  });

  Color get _statusColor {
    switch (project.status) {
      case ProjectStatus.uploaded: return AppTheme.success;
      case ProjectStatus.rendered:
      case ProjectStatus.thumbnailReady: return const Color(0xFF4CAF50);
      case ProjectStatus.rendering:
      case ProjectStatus.uploading:
      case ProjectStatus.mediaGenerating: return AppTheme.warning;
      case ProjectStatus.ttsReady:
      case ProjectStatus.subtitleReady:
      case ProjectStatus.mediaReady: return AppTheme.accent;
      case ProjectStatus.sceneSplit:
      case ProjectStatus.scriptReady: return AppTheme.primary;
      default: return AppTheme.textHint;
    }
  }

  int get _currentStepIndex {
    for (int i = 0; i < _workflowSteps.length; i++) {
      if (_workflowSteps[i].statuses.contains(project.status)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor;
    final stepIdx = _currentStepIndex;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sc.withValues(alpha: 0.3)),
        ),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 상단 행: 이모지 + 제목 + 상태배지 + 메뉴
                Row(
                  children: [
                    // 채널 이모지
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: sc.withValues(alpha: 0.25)),
                      ),
                      child: Center(
                        child: Text(
                          channel?.type.emoji ?? '🎬',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(project.title,
                              style: GoogleFonts.notoSansKr(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(channel?.name ?? '알 수 없는 채널',
                                  style: GoogleFonts.notoSansKr(
                                      color: AppTheme.textHint, fontSize: 11)),
                              if (project.totalScenes > 0) ...[
                                const SizedBox(width: 6),
                                const Text('·', style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                                const SizedBox(width: 6),
                                Text('${project.totalScenes}장면',
                                    style: GoogleFonts.notoSansKr(
                                        color: AppTheme.textHint, fontSize: 11)),
                              ],
                              const SizedBox(width: 6),
                              const Text('·', style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                              const SizedBox(width: 6),
                              Text(_formatDate(project.updatedAt),
                                  style: GoogleFonts.notoSansKr(
                                      color: AppTheme.textHint, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 상태 배지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sc.withValues(alpha: 0.35)),
                      ),
                      child: Text(project.status.displayName,
                          style: GoogleFonts.notoSansKr(
                              color: sc, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: AppTheme.textHint, size: 18),
                      color: AppTheme.bgElevated,
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          onTap: onOpen,
                          child: Row(children: [
                            const Icon(Icons.open_in_new_rounded,
                                size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text('열기', style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary)),
                          ]),
                        ),
                        PopupMenuItem(
                          onTap: onDuplicate,
                          child: Row(children: [
                            const Icon(Icons.copy_rounded,
                                size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text('복사', style: GoogleFonts.notoSansKr(color: AppTheme.textPrimary)),
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

                // ── 이미지 진행률 바 (장면이 있을 때)
                if (project.totalScenes > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: project.progress,
                            backgroundColor: AppTheme.border,
                            color: sc,
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${(project.progress * 100).toInt()}%',
                          style: GoogleFonts.notoSansKr(
                              color: AppTheme.textHint, fontSize: 11)),
                    ],
                  ),
                ],

                // ── 워크플로우 스텝 인디케이터
                const SizedBox(height: 12),
                _WorkflowIndicator(currentStep: stepIdx),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}

// ─── 워크플로우 단계 인디케이터 ──────────────────────
class _WorkflowIndicator extends StatelessWidget {
  final int currentStep; // 0~3
  const _WorkflowIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_workflowSteps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // 연결선
          final stepIdx = i ~/ 2;
          final done = stepIdx < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: done ? AppTheme.primary.withValues(alpha: 0.6) : AppTheme.border,
            ),
          );
        }
        final stepIdx = i ~/ 2;
        final done = stepIdx < currentStep;
        final active = stepIdx == currentStep;
        final step = _workflowSteps[stepIdx];
        Color c = done
            ? AppTheme.success
            : active
                ? AppTheme.primary
                : AppTheme.textHint;
        return Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: done
                    ? AppTheme.success.withValues(alpha: 0.15)
                    : active
                        ? AppTheme.primary.withValues(alpha: 0.2)
                        : AppTheme.bgElevated,
                shape: BoxShape.circle,
                border: Border.all(
                    color: done
                        ? AppTheme.success.withValues(alpha: 0.5)
                        : active
                            ? AppTheme.primary
                            : AppTheme.border,
                    width: active ? 2 : 1),
              ),
              child: Icon(
                done ? Icons.check_rounded : step.icon,
                size: 14,
                color: c,
              ),
            ),
            const SizedBox(height: 3),
            Text(step.label,
                style: GoogleFonts.notoSansKr(
                    fontSize: 10,
                    color: c,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ],
        );
      }),
    );
  }
}
