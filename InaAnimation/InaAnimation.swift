import SwiftUI

/// Animated chibi Ina — native CALayer animation, zero lag.
/// Uses the pet spritesheet frames directly: 192×208 px each, 8 cols × 9 rows.
struct InaAnimation: View {
    let size: CGFloat
    @State private var frame: Int = 0
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    // Animation rows: 0=idle, 1=run, 2=review, 3=wave, 4=jump, 5=waiting, 6=failed
    let row: Int
    
    init(size: CGFloat = 48, mood: Mood = .idle) {
        self.size = size
        self.row = mood.rawValue
    }
    
    enum Mood: Int {
        case idle = 0
        case run = 1
        case review = 2
        case wave = 3
        case jump = 4
        case waiting = 5
        case failed = 6
    }
    
    var body: some View {
        Canvas { context, _ in
            let col = frame % 8
            let sx = CGFloat(col) * 192
            let sy = CGFloat(row) * 208
            
            context.draw(
                Image("inasprite"), // spritesheet in asset catalog
                in: CGRect(x: -sx * (size/192), y: -sy * (size/208),
                          width: 1536 * (size/192), height: 1872 * (size/208))
            )
        }
        .frame(width: size, height: size * (208/192))
        .onReceive(timer) { _ in
            frame = (frame + 1) % 8
        }
    }
}

#Preview {
    InaAnimation(size: 80, mood: .idle)
        .preferredColorScheme(.dark)
}
