import Foundation

/// API 엔드포인트 기술자. path는 `/api` 이후의 상대 경로 (예: "/auth/login").
struct Endpoint: Sendable {
    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    let method: Method
    let path: String
    var queryItems: [URLQueryItem] = []
    var body: Data?
    var contentType: String?

    init(
        _ method: Method,
        _ path: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        contentType: String? = nil
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.body = body
        self.contentType = (body != nil && contentType == nil) ? "application/json" : contentType
    }

    /// JSON 바디를 가진 엔드포인트 생성.
    init(
        _ method: Method,
        _ path: String,
        queryItems: [URLQueryItem] = [],
        json: any Encodable
    ) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(json)
        } catch {
            throw APIError.unknown("요청 데이터 인코딩에 실패했습니다")
        }
        self.init(method, path, queryItems: queryItems, body: data, contentType: "application/json")
    }
}
