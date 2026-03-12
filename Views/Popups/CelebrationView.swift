import SwiftUI

struct CelebrationView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var onDismiss: () -> Void

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 25) {
                Text("🎉")
                    .font(.system(size: 80))
                    .phaseAnimator([0, -20, 0]) { content, offset in
                        content.offset(y: offset)
                    } animation: { _ in
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                    }

                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: onDismiss) {
                    Text("Awesome!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Capsule().fill(Color.blue))
                        .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
            .background(.ultraThinMaterial)
            .cornerRadius(30)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, 40)
            .scaleEffect(isAnimating ? 1.0 : 0.8)
            .opacity(isAnimating ? 1.0 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    CelebrationView(
        title: "Champion! 🏆",
        message: "You crossed the finish line first in Croatia Trip!",
        onDismiss: {}
    )
}
