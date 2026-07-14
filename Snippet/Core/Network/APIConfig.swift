import Foundation

/// API 환경 설정 (문서 §1.1).
enum APIConfig {
    /// Base URL — 모든 경로 상수는 `/api` 이후의 상대 경로.
    /// 디버그 + 시뮬레이터에서만 로컬 백엔드 사용. 실기기는 항상 프로덕션
    /// (실기기에서 로컬 백엔드를 쓰려면 백엔드를 띄우고 맥의 LAN IP로 교체).
    static var baseURL: URL {
        #if DEBUG && targetEnvironment(simulator)
        // 시뮬레이터는 맥과 네트워크를 공유하므로 localhost로 로컬 백엔드 접근
        URL(string: "http://localhost:8008/api")!
        #else
        URL(string: "https://snippetapi.gowoobro.com/api")!
        #endif
    }

    /// 요청 타임아웃 (Flutter connectTimeout 5초에 대응).
    static let requestTimeout: TimeInterval = 15

    /// iOS App Group (홈 위젯 공유).
    static let appGroupId = "group.com.gowoobro.snippet"

    /// 스와이프 카드 1회 fetch 개수.
    static let snippetFetchCount = 10

    /// 카드가 이 개수 이하로 남으면 추가 fetch.
    static let snippetLowThreshold = 3
}
