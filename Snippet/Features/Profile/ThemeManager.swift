import SwiftUI

/// 앱 테마 모드 — 시스템/라이트/다크 3종.
enum AppThemeMode: String, CaseIterable, Sendable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var label: String {
        switch self {
        case .system: return "시스템"
        case .light:  return "라이트"
        case .dark:   return "다크"
        }
    }

    /// SwiftUI `preferredColorScheme` 값. `.system` 은 nil — OS 기본.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// 앱 전역 테마 매니저.
/// - UserDefaults `app_theme_mode` 키에 영속 저장.
/// - RootView에서 1개 생성 → environment 주입 → `.preferredColorScheme(themeManager.colorScheme)` 적용.
@MainActor
@Observable
final class ThemeManager {
    private static let key = "app_theme_mode"

    /// 현재 선택된 테마 모드. 변경 즉시 UserDefaults에 저장.
    var mode: AppThemeMode {
        didSet { save() }
    }

    /// SwiftUI `preferredColorScheme` 에 직접 전달할 값.
    var colorScheme: ColorScheme? { mode.colorScheme }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.key),
           let saved = AppThemeMode(rawValue: raw) {
            mode = saved
        } else {
            mode = .system
        }
    }

    private func save() {
        UserDefaults.standard.set(mode.rawValue, forKey: Self.key)
    }
}
