import SwiftUI

/// 계정 화면 — 프로필 탭의 사용자 카드로 진입.
/// 로그아웃·회원 탈퇴 같은 계정 액션은 주 화면에서 숨기고 이 화면에만 둔다.
/// 회원 탈퇴는 파괴적·비가역이므로 각주 스타일로 가장 조용한 위치에 배치하되,
/// 경로 자체는 유지한다(계정 삭제 경로는 항상 발견 가능해야 함).
struct AccountView: View {

    @Environment(AuthSession.self) private var session

    @State private var showLogoutConfirm    = false
    @State private var showDeleteConfirm    = false
    @State private var isDeleting           = false
    @State private var deleteError: String? = nil

    var body: some View {
        List {
            // MARK: 아바타 + 이름 + 이메일
            Section {
                if let user = session.currentUser {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.accentColor, .accentColor.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 88, height: 88)
                            Text(String(user.name.prefix(1)))
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(Color.onAccent)
                        }

                        VStack(spacing: 2) {
                            Text(user.name)
                                .font(.title2.weight(.semibold))
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }
            }

            // MARK: 로그아웃 (+ 각주형 회원 탈퇴)
            Section {
                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    if isDeleting {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("처리 중...")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    } else {
                        Text("로그아웃")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isDeleting)
            } footer: {
                // 회원 탈퇴 — 의도적으로 가장 낮은 시각 위계(각주)로 격하
                Button {
                    showDeleteConfirm = true
                } label: {
                    Text("회원 탈퇴")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .underline()
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
            }
        }
        .navigationTitle("계정")
        .navigationBarTitleDisplayMode(.inline)
        // 로그아웃 확인
        .confirmationDialog("로그아웃", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("로그아웃", role: .destructive) {
                session.logout()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("로그아웃하시겠습니까?")
        }
        // 회원탈퇴 확인
        .confirmationDialog("회원 탈퇴", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("탈퇴하기", role: .destructive) {
                Task { await performDeleteAccount() }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("탈퇴하면 모든 데이터가 삭제되며 되돌릴 수 없습니다. 정말 탈퇴하시겠습니까?")
        }
        // 회원탈퇴 에러
        .alert("오류", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("확인", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: - 회원탈퇴

    private func performDeleteAccount() async {
        isDeleting = true
        do {
            try await session.deleteAccount()
        } catch {
            deleteError = error.localizedDescription
        }
        isDeleting = false
    }
}

#Preview {
    NavigationStack {
        AccountView()
            .environment(AuthSession())
    }
}
