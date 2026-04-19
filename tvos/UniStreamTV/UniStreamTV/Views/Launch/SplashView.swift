import SwiftUI

/// Animated splash screen shown while checking auth state.
struct SplashView: View {
    @State private var scale = 0.8
    @State private var opacity = 0.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0E0B1E), Color(hex: 0x161230)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: Color(hex: 0x1B6B8A).opacity(0.5), radius: 24, y: 8)

                Text("UniStream")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
