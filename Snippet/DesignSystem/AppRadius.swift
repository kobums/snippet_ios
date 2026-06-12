import CoreGraphics

// MARK: - AppRadius

/// 코너 반경 토큰 (03-design-system.md §3.4).
///
/// 화면마다 산재하던 하드코딩 반경(4/6/8/12/16/20)을 의미 단위로 통일한다.
/// 새 UI는 아래 토큰을 사용하고, 기존 코드도 점진적으로 이관한다.
enum AppRadius {
    /// 뱃지·태그 pill (4)
    static let badge: CGFloat = 4
    /// 작은 표지 (6)
    static let coverSmall: CGFloat = 6
    /// 표지·기본 카드 (8)
    static let card: CGFloat = 8
    /// 큰 카드·그리드 셀 (12)
    static let cardLarge: CGFloat = 12
    /// 시트·다이얼로그 (16)
    static let sheet: CGFloat = 16
    /// 스와이프 카드 (20)
    static let swipeCard: CGFloat = 20
}
