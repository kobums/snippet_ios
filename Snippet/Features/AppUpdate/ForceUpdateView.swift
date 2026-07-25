import SwiftUI

/// 강제 업데이트 차단 화면.
///
/// 닫기·취소 수단을 일부러 두지 않는다 — 업데이트 외에는 진행할 방법이 없어야 한다.
struct ForceUpdateView: View {
    let policy: AppVersionDto

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("업데이트가 필요합니다")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(policy.message ?? "원활한 사용을 위해 최신 버전으로 업데이트해주세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let latest = policy.latestVersion {
                    Text("현재 \(AppVersionInfo.current) → 최신 \(latest)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    openURL(policy.resolvedStoreURL)
                } label: {
                    Text("App Store에서 업데이트")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

#Preview {
    ForceUpdateView(
        policy: AppVersionDto(
            platform: "ios",
            currentVersion: "1.0.20",
            minVersion: "1.0.28",
            latestVersion: "1.0.29",
            updateRequired: true,
            updateAvailable: true,
            storeUrl: nil,
            message: nil
        )
    )
}
