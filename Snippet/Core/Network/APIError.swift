import Foundation

/// 에러 규약 매핑 (문서 §8).
/// - 401/403 → `.auth`
/// - 400~499(401/403 제외) → `.validation`
/// - 500+ → `.server` (statusCode 보존)
/// - 타임아웃/오프라인 → `.network`
/// - 디코딩 실패 → `.decoding`
enum APIError: Error, LocalizedError, Sendable {
    case network(String)
    case auth(String)
    case validation(String)
    case server(statusCode: Int?, message: String)
    case decoding(String)
    case cache(String)
    case unknown(String)

    /// 사용자 노출 메시지.
    var userMessage: String {
        switch self {
        case .network(let message): return message
        case .auth(let message): return message
        case .validation(let message): return message
        case .server(_, let message): return message
        case .decoding: return "알 수 없는 오류가 발생했습니다"
        case .cache(let message): return message
        case .unknown(let message): return message
        }
    }

    var errorDescription: String? { userMessage }

    /// HTTP 상태 코드 + 응답 바디 → APIError (서버 message 우선 사용).
    static func from(statusCode: Int, data: Data) -> APIError {
        let serverMessage = extractServerMessage(from: data)
        switch statusCode {
        case 401, 403:
            return .auth(serverMessage ?? "인증에 실패했습니다")
        case 400...499:
            return .validation(serverMessage ?? "요청이 잘못되었습니다")
        default:
            return .server(statusCode: statusCode, message: serverMessage ?? "서버 오류가 발생했습니다")
        }
    }

    /// URLSession 에러 → APIError.
    static func from(urlError: URLError) -> APIError {
        switch urlError.code {
        case .timedOut:
            return .network("연결 시간이 초과되었습니다")
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .internationalRoamingOff:
            return .network("네트워크 연결을 확인해주세요")
        default:
            return .network("네트워크 연결을 확인해주세요")
        }
    }

    /// 임의 Error → APIError (이미 APIError면 그대로).
    static func wrap(_ error: Error) -> APIError {
        if let apiError = error as? APIError { return apiError }
        if let urlError = error as? URLError { return .from(urlError: urlError) }
        if error is DecodingError { return .decoding(String(describing: error)) }
        return .unknown("알 수 없는 오류가 발생했습니다")
    }

    /// 에러 바디 `{"message": "..."}` 에서 message 추출 (문서 §2.3).
    private static func extractServerMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = object["message"] as? String,
            !message.isEmpty
        else { return nil }
        return message
    }
}
