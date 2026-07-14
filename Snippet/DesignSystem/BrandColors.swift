import SwiftUI
import UIKit

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

    /// 텍스트/아이콘용 브랜드 액센트 — 라이트 검정(#1A1A1A), 다크 흰색.
    /// AccentColor 에셋과 동일한 모노크롬 정책. 다크 배경 위 글자·아이콘에 사용.
    static let accentText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white
            : UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1.0)
    })

    /// accent 배경 위 콘텐츠 색 — 라이트: 흰색(남색 배경 위), 다크: 검정(흰색 배경 위).
    /// `.background(Color.accentColor)` 위의 글자·아이콘은 `.white` 대신 반드시 이 색을 사용.
    static let onAccent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor.black : UIColor.white
    })

    /// 브랜드 다크 고정색(#1A1A1A) — 모드와 무관하게 어두워야 하는 배경(독서 타이머 등).
    static let brandDark = Color(snippetHex: 0x1A1A1A)

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
