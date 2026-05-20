import SwiftUI

struct AIOnboardingView: View {
    @Binding var isPresented: Bool
    var onActivated: () -> Void = {}

    @State private var page = 0
    @State private var apiKeyInput = ""
    @State private var showError = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    introPage.tag(0)
                    guidePage.tag(1)
                    keyInputPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)
            }
        }
    }

    // MARK: - Pages

    private var introPage: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.linearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom))
            VStack(spacing: 12) {
                Text("KI-Analysen aktivieren")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Erhalte personalisiertes Feedback zu deinen Workouts, Körperdaten und Trainingsfortschritt — powered by Google Gemini.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
            VStack(spacing: 12) {
                Button(action: { page = 1 }) {
                    Text("Jetzt einrichten")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Button(action: {
                    UserDefaults.standard.set(true, forKey: "hasSeenAIOnboarding")
                    isPresented = false
                }) {
                    Text("Überspringen")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
    }

    private var guidePage: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 12) {
                Text("So bekommst du deinen Key")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Der API Key ist kostenlos. Du brauchst nur ein Google-Konto.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 20) {
                guideStep(number: "1", text: "Google AI Studio öffnen")
                guideStep(number: "2", text: "\"Create API key\" tippen (Google-Konto nötig)")
                guideStep(number: "3", text: "Key kopieren und im nächsten Schritt einfügen")
            }
            .padding(.horizontal, 28)
            Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                Label("Google AI Studio öffnen", systemImage: "arrow.up.right")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 28)
            Spacer()
            Button(action: { page = 2 }) {
                Text("Weiter")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
    }

    private var keyInputPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.7))
            VStack(spacing: 8) {
                Text("API Key eingeben")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                Text("Füge deinen kopierten Key hier ein.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }
            TextField("AIza...", text: $apiKeyInput)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15)))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 28)
                .onChange(of: apiKeyInput) { _, _ in showError = false }
            if showError {
                Text("Bitte einen API Key eingeben.")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 28)
            }
            Spacer()
            Button(action: activate) {
                Text("Aktivieren")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(apiKeyInput.isEmpty ? .white.opacity(0.3) : .black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(apiKeyInput.isEmpty ? Color.white.opacity(0.08) : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(apiKeyInput.isEmpty)
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helpers

    private func guideStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 32, height: 32)
                .background(Color.white)
                .clipShape(Circle())
            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func activate() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { showError = true; return }
        KeychainService.save(trimmed)
        UserDefaults.standard.set(true, forKey: "hasSeenAIOnboarding")
        onActivated()
        isPresented = false
    }
}
