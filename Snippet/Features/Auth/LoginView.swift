import SwiftUI

/// 로그인 화면 (01-screens.md §1.2).
/// 로그아웃 상태의 루트 — NavigationStack을 소유하고 회원가입을 push한다.
/// 성공 시 `AuthSession.isAuthenticated`가 true가 되어 `SnippetApp`이 메인 탭으로 전환.
struct LoginView: View {
    @Environment(AuthSession.self) private var session

    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isLoading = false

    /// 검증 시도 후에만 인라인 에러 노출 (Flutter validator 동작).
    @State private var didAttemptSubmit = false

    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    // MARK: - 검증 (Flutter 원본 규칙)

    private var emailError: String? {
        guard didAttemptSubmit else { return nil }
        if email.trimmingCharacters(in: .whitespaces).isEmpty { return "Please enter your email" }
        if !email.contains("@") { return "Please enter a valid email" }
        return nil
    }

    private var passwordError: String? {
        guard didAttemptSubmit else { return nil }
        if password.isEmpty { return "Please enter your password" }
        return nil
    }

    private var isFormValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.contains("@") && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    logoHeader
                        .padding(.top, 48)
                        .padding(.bottom, 40)

                    VStack(spacing: 16) {
                        if session.wasForcedLogout {
                            sessionExpiredBanner
                        }

                        emailField
                        passwordField

                        loginButton
                            .padding(.top, 8)

                        registerLink
                    }
                    .padding(.horizontal, 24)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .register:
                    RegisterView()
                }
            }
            .alert("로그인 실패", isPresented: $showErrorAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "알 수 없는 오류가 발생했습니다")
            }
        }
    }

    // MARK: - 서브뷰

    private var logoHeader: some View {
        VStack(spacing: 8) {
            Image("SnippetLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)

            Text("Snippet")
                .font(.system(size: 34, weight: .semibold))
                .tracking(6)
                .foregroundStyle(.primary)
        }
    }

    /// refresh 실패로 강제 로그아웃된 경우 안내 배너.
    private var sessionExpiredBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("세션이 만료되었습니다. 다시 로그인해주세요.")
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "envelope")
                    .foregroundStyle(.secondary)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit { focusedField = .password }
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            if let emailError {
                Text(emailError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 4)
            }
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "lock")
                    .foregroundStyle(.secondary)

                Group {
                    if isPasswordVisible {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                }
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focusedField, equals: .password)
                .onSubmit { submit() }

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            if let passwordError {
                Text(passwordError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 4)
            }
        }
    }

    private var loginButton: some View {
        Button {
            submit()
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Login")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isLoading)
    }

    private var registerLink: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            NavigationLink(value: AuthRoute.register) {
                Text("Register")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - 액션

    private func submit() {
        didAttemptSubmit = true
        guard isFormValid, !isLoading else { return }

        focusedField = nil
        session.acknowledgeForcedLogout()
        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                try await session.login(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                Haptics.success()
                // 성공 → SnippetApp이 isAuthenticated 변화를 감지해 RootView로 전환.
            } catch {
                Haptics.error()
                errorMessage = APIError.wrap(error).userMessage
                showErrorAlert = true
            }
        }
    }
}

/// 인증 플로우 내 push 라우트.
enum AuthRoute: Hashable {
    case register
}

#Preview {
    LoginView()
        .environment(AuthSession())
}
