import SwiftUI

extension View {
    /// 삭제 실패 공용 알림 — 문구·버튼을 한 곳에서 관리한다 (서재/책 상세/기록).
    func deleteFailureAlert(isPresented: Binding<Bool>) -> some View {
        alert("삭제 실패", isPresented: isPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.")
        }
    }
}
