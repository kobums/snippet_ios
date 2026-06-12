import SwiftUI

/// 회원가입 화면 (01-screens.md §1.3).
/// 이름/이메일/비밀번호/비밀번호 확인 + 이메일 인증코드 발송 → 6자리 코드 입력 플로우.
/// 가입 성공 시 토큰이 즉시 발급되어 `AuthSession`이 세션을 수립 → 루트가 메인 탭으로 전환.
struct RegisterView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var code = ""

    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false

    @State private var codeSent = false
    @State private var isSendingCode = false
    @State private var cooldown = 0
    @State private var cooldownTask: Task<Void, Never>?

    @State private var isRegistering = false
    @State private var didAttemptSubmit = false

    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case email
        case code
        case password
        case confirmPassword
    }

    private let codeLength = 6

    // MARK: - 검증 (Flutter 원본 규칙)

    private var nameError: String? {
        guard didAttemptSubmit else { return nil }
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return "이름을 입력해 주세요" }
        return nil
    }

    private var emailError: String? {
        guard didAttemptSubmit else { return nil }
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "이메일을 입력해 주세요" }
        if !trimmed.contains("@") { return "올바른 이메일을 입력해 주세요" }
        return nil
    }

    private var passwordError: String? {
        guard didAttemptSubmit else { return nil }
        if password.isEmpty { return "비밀번호를 입력해 주세요" }
        return nil
    }

    private var confirmPasswordError: String? {
        guard didAttemptSubmit else { return nil }
        if confirmPassword.isEmpty { return "비밀번호를 다시 입력해 주세요" }
        if confirmPassword != password { return "비밀번호가 일치하지 않습니다" }
        return nil
    }

    private var isFormValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        return !trimmedName.isEmpty
            && !trimmedEmail.isEmpty
            && trimmedEmail.contains("@")
            && !password.isEmpty
            && confirmPassword == password
            && !confirmPassword.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                logoHeader
                    .padding(.top, 24)
                    .padding(.bottom, 32)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Create Account")
                        .font(.title3)
                        .fontWeight(.semibold)

                    nameField
                    emailRow

                    if codeSent {
                        codeSection
                    }

                    passwordField(
                        title: "Password",
                        text: $password,
                        isVisible: $isPasswordVisible,
                        field: .password,
                        error: passwordError
                    )
                    passwordField(
                        title: "Confirm Password",
                        text: $confirmPassword,
                        isVisible: $isConfirmPasswordVisible,
                        field: .confirmPassword,
                        error: confirmPasswordError
                    )

                    registerButton
                        .padding(.top, 8)

                    loginLink
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .navigationBarTitleDisplayMode(.inline)
        .alert("회원가입 실패", isPresented: $showErrorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "알 수 없는 오류가 발생했습니다")
        }
        .onDisappear { cooldownTask?.cancel() }
    }

    // MARK: - 서브뷰

    private var logoHeader: some View {
        VStack(spacing: 8) {
            Image("SnippetLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)

            Text("Snippet")
                .font(.system(size: 28, weight: .semibold))
                .tracking(5)
                .foregroundStyle(.primary)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "person")
                    .foregroundStyle(.secondary)
                TextField("Name", text: $name)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .name)
                    .onSubmit { focusedField = .email }
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            if let nameError {
                inlineError(nameError)
            }
        }
    }

    /// 이메일 입력 + 인증코드 발송 버튼.
    private var emailRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
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
                        .onChange(of: email) { _, _ in resetCodeStateIfNeeded() }
                }
                .padding(14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                Button {
                    sendCode()
                } label: {
                    Group {
                        if isSendingCode {
                            ProgressView()
                                .controlSize(.small)
                        } else if cooldown > 0 {
                            Text("\(cooldown)초")
                        } else if codeSent {
                            Text("재발송")
                        } else {
                            Text("인증코드\n발송")
                                .multilineTextAlignment(.center)
                        }
                    }
                    .font(.caption)
                    .frame(minWidth: 52, minHeight: 36)
                }
                .buttonStyle(.bordered)
                .disabled(isSendingCode || cooldown > 0)
            }

            if let emailError {
                inlineError(emailError)
            }
        }
    }

    /// 6자리 인증코드 입력 — 숨겨진 단일 TextField + 박스 6개 렌더링.
    /// 붙여넣기/자동완성(oneTimeCode)/백스페이스가 단일 필드에서 자연스럽게 동작한다.
    private var codeSection: some View {
        VStack(spacing: 8) {
            Text("이메일로 발송된 6자리 코드를 입력하세요")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            ZStack {
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focusedField, equals: .code)
                    .frame(width: 1, height: 1)
                    .opacity(0.011)
                    .onChange(of: code) { _, newValue in
                        let filtered = String(newValue.filter(\.isNumber).prefix(codeLength))
                        if filtered != newValue { code = filtered }
                    }

                HStack(spacing: 8) {
                    ForEach(0..<codeLength, id: \.self) { index in
                        codeBox(at: index)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { focusedField = .code }
            }
        }
    }

    private func codeBox(at index: Int) -> some View {
        let characters = Array(code)
        let digit = index < characters.count ? String(characters[index]) : ""
        let isActive = focusedField == .code && index == min(code.count, codeLength - 1)

        return Text(digit)
            .font(.title3.weight(.semibold))
            .monospacedDigit()
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isActive ? Color.accentColor : Color(.separator), lineWidth: isActive ? 1.5 : 0.5)
            )
    }

    private func passwordField(
        title: String,
        text: Binding<String>,
        isVisible: Binding<Bool>,
        field: Field,
        error: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "lock")
                    .foregroundStyle(.secondary)

                Group {
                    if isVisible.wrappedValue {
                        TextField(title, text: text)
                    } else {
                        SecureField(title, text: text)
                    }
                }
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(field == .confirmPassword ? .done : .next)
                .focused($focusedField, equals: field)
                .onSubmit {
                    if field == .password {
                        focusedField = .confirmPassword
                    } else {
                        submit()
                    }
                }

                Button {
                    isVisible.wrappedValue.toggle()
                } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            if let error {
                inlineError(error)
            }
        }
    }

    private var registerButton: some View {
        Button {
            submit()
        } label: {
            Group {
                if isRegistering {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Register")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isRegistering)
    }

    private var loginLink: some View {
        HStack(spacing: 4) {
            Text("Already have an account?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Login") {
                dismiss()
            }
            .font(.subheadline)
            .fontWeight(.semibold)
        }
        .padding(.top, 8)
    }

    private func inlineError(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .padding(.leading, 4)
    }

    // MARK: - 액션

    /// POST /auth/emailcode — 발송 성공 시 코드 입력 영역 노출 + 60초 쿨다운.
    private func sendCode() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, trimmedEmail.contains("@") else {
            errorMessage = "올바른 이메일을 입력해 주세요."
            showErrorAlert = true
            return
        }
        guard !isSendingCode else { return }

        isSendingCode = true
        Task {
            defer { isSendingCode = false }
            do {
                try await session.sendEmailCode(email: trimmedEmail)
                codeSent = true
                code = ""
                startCooldown()
                focusedField = .code
            } catch {
                Haptics.error()
                errorMessage = APIError.wrap(error).userMessage
                showErrorAlert = true
            }
        }
    }

    private func startCooldown() {
        cooldownTask?.cancel()
        cooldown = 60
        cooldownTask = Task {
            while cooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                cooldown -= 1
            }
        }
    }

    /// 이메일 수정 시 코드 상태 리셋 (Flutter 원본 동작).
    private func resetCodeStateIfNeeded() {
        guard codeSent else { return }
        codeSent = false
        code = ""
        cooldown = 0
        cooldownTask?.cancel()
    }

    private func submit() {
        didAttemptSubmit = true
        guard isFormValid, !isRegistering else { return }

        guard codeSent else {
            errorMessage = "이메일 인증을 먼저 진행해 주세요."
            showErrorAlert = true
            return
        }
        guard code.count == codeLength else {
            errorMessage = "6자리 인증 코드를 입력해 주세요."
            showErrorAlert = true
            return
        }

        focusedField = nil
        isRegistering = true

        Task {
            defer { isRegistering = false }
            do {
                try await session.register(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    name: name.trimmingCharacters(in: .whitespaces),
                    code: code
                )
                Haptics.success()
                // 성공 → 토큰 즉시 발급, SnippetApp이 메인 탭으로 전환.
            } catch {
                Haptics.error()
                errorMessage = APIError.wrap(error).userMessage
                showErrorAlert = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
    }
    .environment(AuthSession())
}
