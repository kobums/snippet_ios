import SwiftUI

// MARK: - SnippetViewModel

/// 스니펫 스와이프 탭 상태 — @Observable 싱글 ViewModel.
/// 아키텍처: Screen → ViewModel → SnippetService
@MainActor
@Observable
final class SnippetViewModel {

    // MARK: - 카드 큐

    private(set) var cards: [SnippetCard] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// 오늘 남은 카드 (-1=무제한, 0=한도 소진)
    private(set) var remainingToday: Int = -1

    /// 처음 로드 완료 여부 (초기 스피너 제어용)
    private(set) var hasFetched = false

    // MARK: - 보관함

    private(set) var archiveItems: [SnippetArchive] = []
    private(set) var isArchiveLoading = false
    private(set) var archiveError: String?

    // MARK: - Reveal 시트

    var revealItem: SnippetArchive?     // 보여줄 책 정보

    // MARK: - 의존성

    private let service: SnippetService
    /// 이미 봤거나 처리한 카드 ID (중복 제외 fetch 용)
    private var seenIds: [Int] = []

    init(service: SnippetService = SnippetService()) {
        self.service = service
    }

    // MARK: - 카드 로드

    func fetchSnippets() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        // 이미 처리한 카드(seenIds) + 아직 화면에 남아있는 카드를 모두 제외한다.
        // 화면에 남은 카드를 빼지 않으면 서버가 같은 카드를 다시 내려줘 cards에
        // 중복 id가 생기고, ForEach가 중복 id 경고/고스트 렌더링을 일으킨다.
        let excludeIds = seenIds + cards.map(\.id)
        if let response = try? await service.fetchCards(count: 10, excludeIds: excludeIds.isEmpty ? nil : excludeIds) {
            let known = Set(excludeIds)
            let fresh = response.cards.filter { !known.contains($0.id) }
            cards.append(contentsOf: fresh)
            remainingToday = response.remainingToday
            syncWidget()
        } else {
            errorMessage = "카드를 불러오지 못했습니다."
        }

        isLoading = false
        hasFetched = true
    }

    /// 최상단 카드를 홈 위젯 공유 저장소에 반영
    private func syncWidget() {
        if let top = cards.first {
            SharedSnippetStore.save(text: top.text, tag: top.tag)
        } else {
            // 남은 카드가 없으면 위젯에 이전 스니펫이 계속 남지 않도록 비운다.
            SharedSnippetStore.clear()
        }
    }

    // MARK: - 스와이프 처리

    /// 오른쪽 = Like(archive), 왼쪽 = Pass(skip)
    func handleSwipe(card: SnippetCard, isLike: Bool) async {
        // 낙관적으로 즉시 제거
        removeTopCard(card)
        seenIds.append(card.id)

        syncWidget()

        // 남은 카드 < 3 이면 자동 추가 fetch
        if cards.count < 3 && remainingToday != 0 {
            await fetchSnippets()
        }

        // API 호출
        if isLike {
            _ = try? await service.addArchive(snippetId: card.id)
        } else {
            try? await service.skip(snippetId: card.id)
        }
    }

    private func removeTopCard(_ card: SnippetCard) {
        cards.removeAll { $0.id == card.id }
    }

    // MARK: - 보관함 로드

    func fetchArchive() async {
        guard !isArchiveLoading else { return }
        isArchiveLoading = true
        archiveError = nil

        if let items = try? await service.fetchArchive() {
            archiveItems = items
        } else {
            archiveError = "보관함을 불러오지 못했습니다."
        }

        isArchiveLoading = false
    }

    func removeFromArchive(item: SnippetArchive) async {
        archiveItems.removeAll { $0.id == item.id }
        try? await service.removeArchive(snippetId: item.id)
    }

    // MARK: - Reveal

    func showReveal(for item: SnippetArchive) {
        revealItem = item
    }

    func dismissReveal() {
        revealItem = nil
    }
}
