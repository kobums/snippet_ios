import SwiftUI

extension View {
    /// 줌 전환(`navigationTransition(.zoom)`)의 소스를 선택적으로 지정한다.
    /// 네임스페이스가 nil이면 아무 것도 하지 않아, 공용 컴포넌트가 전환 없는 화면에서도 그대로 쓰인다.
    @ViewBuilder
    func zoomTransitionSource(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}
