import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/project_model.dart';
import '../theme/app_theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/channels_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/script_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/media_screen.dart';
import '../screens/render_screen.dart';

// 현재 프로젝트 미니 상태 카드 (사이드바 하단)
class _CurrentProjectMini extends StatelessWidget {
  final AppProvider provider;
  const _CurrentProjectMini({required this.provider});

  @override
  Widget build(BuildContext context) {
    final project = provider.currentProject;
    if (project == null) return const SizedBox.shrink();

    Color sc;
    switch (project.status) {
      case ProjectStatus.uploaded: sc = const Color(0xFF4CAF50); break;
      case ProjectStatus.rendered:
      case ProjectStatus.thumbnailReady: sc = const Color(0xFF66BB6A); break;
      case ProjectStatus.rendering:
      case ProjectStatus.uploading:
      case ProjectStatus.mediaGenerating: sc = AppTheme.warning; break;
      case ProjectStatus.ttsReady:
      case ProjectStatus.subtitleReady:
      case ProjectStatus.mediaReady: sc = AppTheme.accent; break;
      default: sc = AppTheme.primary;
    }

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: sc.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sc.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.video_file_rounded, size: 13, color: sc),
              const SizedBox(width: 5),
              Text('현재 작업',
                  style: GoogleFonts.notoSansKr(
                      color: sc, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(project.title,
              style: GoogleFonts.notoSansKr(
                  color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(project.status.displayName,
                style: GoogleFonts.notoSansKr(color: sc, fontSize: 10)),
          ),
          if (project.totalScenes > 0) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: project.progress,
              backgroundColor: AppTheme.border,
              color: sc,
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ],
      ),
    );
  }
}

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: Row(
            children: [
              // 사이드바
              _Sidebar(provider: provider),
              // 메인 콘텐츠
              Expanded(
                child: _buildContent(provider.selectedNavIndex),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(int index) {
    switch (index) {
      case 0: return const DashboardScreen();
      case 1: return const ChannelsScreen();
      case 2: return const ProjectsScreen();
      case 3: return const ScriptScreen();
      case 4: return const MediaScreen();
      case 5: return const RenderScreen();
      case 6: return const SettingsScreen();
      default: return const DashboardScreen();
    }
  }
}

class _Sidebar extends StatelessWidget {
  final AppProvider provider;
  const _Sidebar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final expanded = provider.isSidebarExpanded;
    final width = expanded ? 240.0 : 72.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: width,
      decoration: const BoxDecoration(
        color: AppTheme.bgSurface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          // 로고 영역
          _buildLogo(expanded),
          const Divider(height: 1),
          // 메뉴 항목들
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildNavItem(context, 0, Icons.dashboard_rounded, '대시보드', expanded),
                  _buildNavItem(context, 1, Icons.tv_rounded, '채널 관리', expanded),
                  _buildNavItem(context, 2, Icons.video_library_rounded, '프로젝트', expanded),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Divider(),
                  ),
                  if (expanded)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        '제작 워크플로우',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 11,
                          color: AppTheme.textHint,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  _buildNavItem(context, 3, Icons.edit_note_rounded, '대본 작성', expanded),
                  _buildNavItem(context, 4, Icons.image_rounded, '미디어 생성', expanded),
                  _buildNavItem(context, 5, Icons.movie_creation_rounded, '렌더링/업로드', expanded),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Divider(),
                  ),
                  _buildNavItem(context, 6, Icons.settings_rounded, '설정', expanded),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // 현재 프로젝트 미니 카드
          _CurrentProjectMini(provider: provider),
          // 접기/펼치기 버튼
          const Divider(height: 1),
          InkWell(
            onTap: provider.toggleSidebar,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Icon(
                expanded ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(bool expanded) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.play_circle_rounded, color: Colors.white, size: 22),
          ),
          if (expanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tube Master',
                    style: GoogleFonts.notoSansKr(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'AI 영상 자동화',
                    style: GoogleFonts.notoSansKr(
                      color: AppTheme.textHint,
                      fontSize: 11,
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

  Widget _buildNavItem(
      BuildContext context, int index, IconData icon, String label, bool expanded) {
    final isSelected = provider.selectedNavIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: () => provider.setNavIndex(index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 12 : 0,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: AppTheme.primary.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              if (expanded) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.notoSansKr(
                    color: isSelected ? AppTheme.primaryLight : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
