// placeholder_screens.dart - 더 이상 사용하지 않지만 호환성을 위해 유지
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// 이 파일은 더 이상 MediaScreen, RenderScreen을 포함하지 않습니다.
// 각각의 전용 파일을 사용합니다:
//   - media_screen.dart
//   - render_screen.dart

class _LegacyPlaceholder extends StatelessWidget {
  const _LegacyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(color: AppTheme.bgDark);
  }
}
