import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────
// 채널별 테마 색상 (각 채널 특성을 색으로 표현)
// ─────────────────────────────────────────────────────────
class ChannelTheme {
  final Color primary;
  final Color secondary;
  final Color bgAccent;
  final String icon;

  const ChannelTheme({
    required this.primary,
    required this.secondary,
    required this.bgAccent,
    required this.icon,
  });
}

// 채널 타입에 따른 테마 매핑
// 사용 방법: ChannelThemes.get(channelType).primary
class ChannelThemes {
  // 경제 채널: 파란색 계열 - 신뢰, 안정감
  static const ChannelTheme economy = ChannelTheme(
    primary: Color(0xFF1565C0),
    secondary: Color(0xFF42A5F5),
    bgAccent: Color(0xFF0D2744),
    icon: '📊',
  );

  // 국뽕 채널: 빨간색 계열 - 열정, 애국
  static const ChannelTheme patriot = ChannelTheme(
    primary: Color(0xFFC62828),
    secondary: Color(0xFFEF5350),
    bgAccent: Color(0xFF3B0A0A),
    icon: '🇰🇷',
  );

  // 야담 채널: 보라색 계열 - 신비, 전통
  static const ChannelTheme folklore = ChannelTheme(
    primary: Color(0xFF4A148C),
    secondary: Color(0xFFAB47BC),
    bgAccent: Color(0xFF1A0830),
    icon: '📖',
  );

  // 사연 채널: 핑크색 계열 - 감정, 공감
  static const ChannelTheme story = ChannelTheme(
    primary: Color(0xFFAD1457),
    secondary: Color(0xFFF06292),
    bgAccent: Color(0xFF300514),
    icon: '💌',
  );

  // 성경 채널: 초록색 계열 - 성스러움, 평화
  static const ChannelTheme bible = ChannelTheme(
    primary: Color(0xFF1B5E20),
    secondary: Color(0xFF66BB6A),
    bgAccent: Color(0xFF071509),
    icon: '✝️',
  );

  // 불교 채널: 황금색 계열 - 지혜, 평온
  static const ChannelTheme buddhism = ChannelTheme(
    primary: Color(0xFFE65100),
    secondary: Color(0xFFFFB74D),
    bgAccent: Color(0xFF3E1800),
    icon: '☸️',
  );

  // 심리학 채널: 청록색 계열 - 지성, 분석
  static const ChannelTheme psychology = ChannelTheme(
    primary: Color(0xFF006064),
    secondary: Color(0xFF4DD0E1),
    bgAccent: Color(0xFF001A1B),
    icon: '🧠',
  );

  // 역사 채널: 갈색/금색 계열 - 고전, 무게감
  static const ChannelTheme history = ChannelTheme(
    primary: Color(0xFF4E342E),
    secondary: Color(0xFFD7CCC8),
    bgAccent: Color(0xFF150E0C),
    icon: '🏛️',
  );

  // ASMR 채널: 네이비 계열 - 편안함, 수면
  static const ChannelTheme asmr = ChannelTheme(
    primary: Color(0xFF1A237E),
    secondary: Color(0xFF7986CB),
    bgAccent: Color(0xFF060820),
    icon: '🎧',
  );

  // 플레이리스트 채널: 어두운 회색 계열 - 음악, 세련됨
  static const ChannelTheme playlist = ChannelTheme(
    primary: Color(0xFF212121),
    secondary: Color(0xFF9E9E9E),
    bgAccent: Color(0xFF0A0A0A),
    icon: '🎵',
  );

  static const Map<String, ChannelTheme> _map = {
    'economy': economy,
    'patriot': patriot,
    'folklore': folklore,
    'story': story,
    'bible': bible,
    'buddhism': buddhism,
    'psychology': psychology,
    'history': history,
    'asmr': asmr,
    'playlist': playlist,
  };

  // ChannelType.index → 테마 가져오기
  static ChannelTheme fromIndex(int index) {
    const keys = [
      'economy', 'patriot', 'folklore', 'story', 'bible',
      'buddhism', 'psychology', 'history', 'asmr', 'playlist',
    ];
    if (index < 0 || index >= keys.length) return economy;
    return _map[keys[index]]!;
  }

  static ChannelTheme fromName(String name) {
    return _map[name] ?? economy;
  }
}

class AppTheme {
  // 메인 컬러
  static const Color primary = Color(0xFF6C3CE1);      // 딥 퍼플
  static const Color primaryLight = Color(0xFF9B6FF5);
  static const Color primaryDark = Color(0xFF4A1DB3);
  static const Color accent = Color(0xFFFF6B35);        // 오렌지 액센트
  static const Color accentLight = Color(0xFFFF9563);
  static const Color success = Color(0xFF00C896);       // 성공 그린
  static const Color warning = Color(0xFFFFB020);       // 경고 옐로우
  static const Color error = Color(0xFFFF4444);         // 에러 레드
  
  // 배경
  static const Color bgDark = Color(0xFF0F0F1A);        // 최어두운 배경
  static const Color bgCard = Color(0xFF1A1A2E);        // 카드 배경
  static const Color bgSurface = Color(0xFF16213E);     // 서피스
  static const Color bgElevated = Color(0xFF1E1E3A);    // 높은 카드
  
  // 텍스트
  static const Color textPrimary = Color(0xFFEEEEFF);
  static const Color textSecondary = Color(0xFF9999BB);
  static const Color textHint = Color(0xFF555577);
  
  // 보더
  static const Color border = Color(0xFF2A2A4A);
  static const Color borderLight = Color(0xFF3A3A5A);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: bgSurface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: bgDark,
      cardColor: bgCard,
      textTheme: GoogleFonts.notoSansKrTextTheme().copyWith(
        headlineLarge: GoogleFonts.notoSansKr(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.notoSansKr(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: GoogleFonts.notoSansKr(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.notoSansKr(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.notoSansKr(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.notoSansKr(
          color: textPrimary,
          fontSize: 14,
        ),
        bodyMedium: GoogleFonts.notoSansKr(
          color: textSecondary,
          fontSize: 13,
        ),
        bodySmall: GoogleFonts.notoSansKr(
          color: textHint,
          fontSize: 12,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.notoSansKr(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: bgSurface,
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.notoSansKr(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: GoogleFonts.notoSansKr(color: textHint, fontSize: 14),
        labelStyle: GoogleFonts.notoSansKr(color: textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgElevated,
        selectedColor: primary.withValues(alpha: 0.3),
        labelStyle: GoogleFonts.notoSansKr(color: textPrimary, fontSize: 12),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primary : textHint),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) 
                ? primary.withValues(alpha: 0.3) 
                : bgElevated),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: border,
        overlayColor: primary.withValues(alpha: 0.2),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: primary,
        labelStyle: GoogleFonts.notoSansKr(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.notoSansKr(fontWeight: FontWeight.normal),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
      ),
      iconTheme: const IconThemeData(color: textSecondary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgElevated,
        contentTextStyle: GoogleFonts.notoSansKr(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.notoSansKr(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: GoogleFonts.notoSansKr(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: border,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        textStyle: GoogleFonts.notoSansKr(color: textPrimary, fontSize: 12),
      ),
    );
  }
}
