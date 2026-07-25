import Foundation

/// 앱 버전 정책 게이트 — 강제 업데이트 차단 여부를 앱 전역에 노출한다.
///
/// 조회 실패(네트워크 끊김·서버 장애·응답 형식 변경)는 전부 "차단 안 함"으로 처리한다.
/// 서버가 죽었다는 이유로 앱 전체가 잠기면 안 되기 때문 (fail-open).
@MainActor
@Observable
final class AppVersionGate {

    /// 마지막으로 받아온 정책. 조회 전/실패 시 `.notRequired`.
    private(set) var policy: AppVersionDto = .notRequired

    /// 권장 업데이트 안내 노출 여부 (강제 아님, 사용자가 닫을 수 있음).
    var isShowingSoftPrompt = false

    /// true면 앱 사용을 막고 업데이트 화면만 띄운다.
    var isBlocked: Bool { policy.updateRequired }

    private let service: AppVersionService
    private let defaults: UserDefaults

    /// 중복 요청 방지 — 포그라운드 복귀가 연속으로 들어와도 1개만 수행.
    /// (@MainActor 격리라 별도 동기화 없이 안전)
    private var isChecking = false

    init(service: AppVersionService = AppVersionService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
    }

    /// 정책을 조회해 상태를 갱신한다. 실패해도 예외를 던지지 않는다.
    func check() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            apply(try await service.check())
        } catch {
            // fail-open: 이미 차단 중이면 그대로 두고(차단 해제는 성공 응답으로만),
            // 아니면 새로 차단하지 않는다.
            if !policy.updateRequired {
                policy = .notRequired
            }
        }
    }

    /// 권장 업데이트 안내를 이 버전에 한해 다시 띄우지 않는다.
    func skipSoftPrompt() {
        isShowingSoftPrompt = false
        guard let latest = policy.latestVersion else { return }
        defaults.set(true, forKey: Self.skipKey(for: latest))
    }

    private func apply(_ result: AppVersionDto) {
        policy = result

        guard !result.updateRequired,
              result.updateAvailable,
              let latest = result.latestVersion,
              !defaults.bool(forKey: Self.skipKey(for: latest))
        else {
            isShowingSoftPrompt = false
            return
        }
        isShowingSoftPrompt = true
    }

    private static func skipKey(for version: String) -> String {
        "com.gowoobro.snippet.softUpdateSkipped.\(version)"
    }
}
