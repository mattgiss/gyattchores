import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var code = ""
    @State private var showError = false
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.10),
                    Color(red: 0.12, green: 0.10, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo and title
                VStack(spacing: 16) {
                    Text("🏠")
                        .font(.system(size: 80))
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: isAnimating)

                    Text("GyattChores")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Family Chore Tracker")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Code input
                VStack(spacing: 20) {
                    SecureField("Enter Code", text: $code)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(showError ? Color.red : Color.clear, lineWidth: 2)
                                )
                        )
                        .frame(maxWidth: 200)

                    Button(action: login) {
                        Text("Enter")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: 200)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .cyan.opacity(0.4), radius: 12, y: 6)
                    }
                    .disabled(code.isEmpty)
                    .opacity(code.isEmpty ? 0.6 : 1.0)

                    if showError {
                        Text("Incorrect code")
                            .font(.caption)
                            .foregroundColor(.red)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer()
                Spacer()

                // Daily quote
                DailyQuoteView()
                    .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
        .onAppear {
            isAnimating = true
        }
    }

    private func login() {
        if authManager.login(with: code) {
            // Success - view will change automatically
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            // Error
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                showError = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            code = ""

            // Hide error after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showError = false
                }
            }
        }
    }
}

struct DailyQuoteView: View {
    private let quotes: [(quote: String, author: String)] = [
        ("Do or do not. There is no try.", "Yoda"),
        ("Just keep swimming!", "Dory"),
        ("Adventure is out there!", "Ellie"),
        ("To infinity and beyond!", "Buzz Lightyear"),
        ("Ohana means family.", "Stitch"),
        ("With great power comes great responsibility.", "Spider-Man")
    ]

    private var dailyQuote: (quote: String, author: String) {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return quotes[dayOfYear % quotes.count]
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("\"\(dailyQuote.quote)\"")
                .font(.subheadline)
                .italic()
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("— \(dailyQuote.author)")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
