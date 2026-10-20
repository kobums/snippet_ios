import Foundation

extension String {
    /// 표지 이미지 URL의 `http://`를 `https://`로 올린다.
    ///
    /// 표지는 알라딘(image.aladin.co.kr) 등 외부 CDN에서 오며 일부 데이터가 http로 저장돼 있다.
    /// ATS의 NSAllowsArbitraryLoads 없이도 로드되도록 디코딩 시점에 https로 바꾼다.
    /// (https를 지원하지 않는 호스트면 로드 실패 → BookCoverView 플레이스홀더로 표시)
    var httpsUpgradedURLString: String {
        guard hasPrefix("http://") else { return self }
        return "https://" + dropFirst("http://".count)
    }
}
