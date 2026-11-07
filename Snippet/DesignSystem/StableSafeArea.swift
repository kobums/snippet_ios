import SwiftUI

extension GeometryProxy {
    /// 플로팅 상단 바 레이아웃에서 패딩·여백 계산에 쓰는 안전 영역.
    ///
    /// iPhone Duo를 접은 상태에서 반쯤 펼칠 때, 그때 보이던 탭이 하단 안전 영역을 화면 높이 전체로
    /// 받은 채 남는 경우가 있다(iOS 27.2 시뮬레이터 — 다른 탭에 다녀오면 정상으로 돌아옴).
    /// 그 값을 그대로 쓰면 카드와 버튼이 위로 몰려 겹치므로, 높이를 넘는 값은 0으로 본다.
    var stableSafeAreaInsets: EdgeInsets {
        var insets = safeAreaInsets
        if insets.bottom >= size.height { insets.bottom = 0 }
        if insets.top >= size.height { insets.top = 0 }
        return insets
    }
}
