import SwiftUI
import Foundation

struct SplashView: View {
    @State private var isActive = false
    @State private var opacity = 0.0
    @State private var sparkleScale: CGFloat = 0.0
    @State private var sparkleRotation: Double = 0.0
    @EnvironmentObject var store: ExpenseStore
    @EnvironmentObject var currencyService: CurrencyService
    
    // Custom colors to match the logo
    private let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 135/255, green: 206/255, blue: 235/255),
            Color(red: 51/255, green: 153/255, blue: 204/255)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    private let tealColor = Color(red: 64/255, green: 224/255, blue: 208/255)
    private let navyBlue = Color(red: 28/255, green: 67/255, blue: 110/255)
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack {
                    Text("NewLedger")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        .padding(.top, 150)
                    
                    Spacer()
                    
                    ZStack {
                        // Centered Logo
                        Image("Image")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                        
                        // Animated sparkles
                        ForEach(0..<8) { index in
                            Image(systemName: "sparkle")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .offset(
                                    x: sparklePosition(index).x * sparkleScale,
                                    y: sparklePosition(index).y * sparkleScale
                                )
                                .rotationEffect(.degrees(sparkleRotation))
                                .opacity(opacity)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Text("Developed by")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Fong-Yu (Yang) Lin")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("YuYu")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(tealColor)
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 70)
                }
                .opacity(opacity)
            }
            .onAppear {
                // Initial fade in
                withAnimation(.easeIn(duration: 0.8)) {
                    self.opacity = 1.0
                }
                
                // Sparkle animation
                withAnimation(
                    .spring(
                        response: 1.2,
                        dampingFraction: 0.8,
                        blendDuration: 0
                    )
                ) {
                    sparkleScale = 1.0
                }
                
                // Rotation animation
                withAnimation(
                    .easeOut(duration: 1.5)
                ) {
                    sparkleRotation = 360.0
                }
                
                // Transition to main view
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
    
    private func sparklePosition(_ index: Int) -> CGPoint {
        let radius: CGFloat = 120
        let angle = Double(2 * Double.pi / 8) * Double(index)
        return CGPoint(
            x: CGFloat(cos(angle)) * radius,
            y: CGFloat(sin(angle)) * radius
        )
    }
}

#Preview {
    SplashView()
        .environmentObject(ExpenseStore())
        .environmentObject(CurrencyService.shared)
}
