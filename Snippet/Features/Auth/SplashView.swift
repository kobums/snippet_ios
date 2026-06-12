import SwiftUI

/// 스플래시 (01-screens.md §1.1).
/// 로고 + 브랜드 텍스트 + 스피너. 최소 1초 노출 + 자동 로그인 체크(`checkAuth`) 후 `onFinished` 호출.
/// 인증 분기 자체는 `SnippetApp`이 담당한다.
struct SplashView: View {
    @Environment(AuthSession.self) private var session

    /// 최소 노출 시간 + 인증 체크가 끝나면 호출 — 루트가 로그인/메인으로 전환.
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("SnippetLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)

                Text("Snippet")
                    .font(.system(size: 34, weight: .semibold))
                    .tracking(6)
                    .foregroundStyle(.primary)

                Text("Blind Book Curation")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 24)
            }
        }
        .task {
            // 자동 로그인: 서버 호출 없이 로컬(Keychain + UserDefaults)만 확인.
            session.checkAuth()
            // 최소 1초 노출 (Flutter 원본 동작).
            try? await Task.sleep(for: .seconds(1))
            onFinished()
        }
    }
}

#Preview {
    SplashView(onFinished: {})
        .environment(AuthSession())
}
