import SwiftUI
import AVFoundation

struct FlashcardView: View {
    let card: Card
    let isFlipped: Bool
    let showTermFirst: Bool
    let themeGradient: LinearGradient
    let onTap: () -> Void
    
    var frontText: String { showTermFirst ? card.term : card.definition }
    var backText: String { showTermFirst ? card.definition : card.term }
    
    var body: some View {
        ZStack {
            CardFace(text: frontText, isBack: false, themeGradient: themeGradient)
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            
            CardFace(text: backText, isBack: true, themeGradient: themeGradient)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .animation(nil, value: isFlipped)
        .onTapGesture {
            onTap()
        }
    }
}

struct CardFace: View {
    let text: String
    let isBack: Bool
    let themeGradient: LinearGradient
    let synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        ZStack {
            // Glassy Background
            RoundedRectangle(cornerRadius: 32)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
            
            VStack(spacing: 25) {
                // Label (Term vs Definition)
                Text(isBack ? "DEFINITION" : "TERM")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(themeGradient)
                    .opacity(0.8)
                
                // Main Text
                Text(text)
                    .font(.system(size: 48, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .minimumScaleFactor(0.5)
                
                Spacer().frame(height: 10)
                
                // Action Buttons
                HStack {
                    Button(action: speak) {
                        Image(systemName: "speaker.wave.2.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 32))
                            .foregroundStyle(themeGradient)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(40)
        }
        .frame(width: 500, height: 350)
    }
    
    func speak() {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
}
