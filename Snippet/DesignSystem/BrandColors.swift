import SwiftUI

// MARK: - 브랜드 컬러
//
// 원칙(docs/native-migration/03-design-system.md §7.2):
// 시스템 시맨틱 컬러를 기본으로 쓰고, 시스템에 없는 브랜드 색만 여기에 정의한다.
//
// Flutter 토큰 → iOS 매핑 가이드 (화면 코드에서 그대로 사용):
//   primary / textPrimary   → Color.primary  (라이트 #1A1A1A ≈ .label, 다크 흰색 자동 반전)
//   textSecondary           → Color.secondary 또는 Color(.secondaryLabel)
//   textTertiary            → Color(.tertiaryLabel)
//   textDisabled            → Color(.quaternaryLabel)
//   surface                 → Color(.systemBackground)
//   surfaceSecondary        → Color(.secondarySystemBackground)
//   surfaceTertiary         → Color(.tertiarySystemBackground)
//   border / divider        → Color(.separator)
//   secondaryMain #34C759   → Color(.systemGreen)  (동일값)
//   error   #FF3B30         → Color(.systemRed)    (버튼은 role: .destructive)
//   warning #FFCC00         → Color(.systemYellow)
//   info    #007AFF         → Color(.systemBlue)
//   글래스(subtle/medium/strong) → .thinMaterial / .regularMaterial / .ultraThinMaterial

extension Color {

    // MARK: 브랜드 액센트

    /// 보조(그린) 브랜드 컬러 — iOS systemGreen과 동일값(#34C759)이므로 시스템 컬러 사용.
    static let brandGreen = Color(.systemGreen)

    /// 보라 포인트 액센트 (#B794F4).
    static let accentPurple = Color(snippetHex: 0xB794F4)

    // MARK: 차트 컬러 (카테고리 분포 등 — Swift Charts에 사용)

    /// 핑크 (#FF6B9D)
    static let chart1 = Color(snippetHex: 0xFF6B9D)
    /// 틸 (#4ECDC4)
    static let chart2 = Color(snippetHex: 0x4ECDC4)
    /// 살몬 (#FFA07A)
    static let chart3 = Color(snippetHex: 0xFFA07A)
    /// 민트 (#98D8C8)
    static let chart4 = Color(snippetHex: 0x98D8C8)
    /// 로즈브라운 (#B5838D)
    static let chart5 = Color(snippetHex: 0xB5838D)

    /// 차트 색상 팔레트 (인덱스 순환 사용: `chartPalette[index % chartPalette.count]`)
    static let chartPalette: [Color] = [.chart1, .chart2, .chart3, .chart4, .chart5]
}

// MARK: - Hex 이니셜라이저 (내부 전용)

extension Color {
    /// 0xRRGGBB 형식의 hex 값으로 Color 생성.
    init(snippetHex hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
