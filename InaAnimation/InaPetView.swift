import Foundation
import SwiftUI

/// Native chibi Ina view — runs as a SwiftUI overlay, not in WebView.
/// Cycles through the pet spritesheet at 10fps. Zero lag.
struct InaPetView: View {
    let mood: InaMood
    @State private var col: Int = 0
    private let fps: TimeInterval = 0.1
    
    enum InaMood: Int {
        case idle = 0
        case thinking = 1
        case wave = 3
        case jump = 4
        
        var frames: Int { 8 }  // spritesheet has 8 columns
    }
    
    var body: some View {
        Canvas { ctx, size in
            let fw: CGFloat = 192
            let fh: CGFloat = 208
            let scale = size.width / fw
            
            guard let image = UIImage(named: "inasprite")?.cgImage else { return }
            
            ctx.draw(Image(uiImage: UIImage(cgImage: image)), in: CGRect(
                x: -CGFloat(col) * fw * scale,
                y: -CGFloat(mood.rawValue) * fh * scale,
                width: CGFloat(image.width) * scale,
                height: CGFloat(image.height) * scale
            ))
        }
        .frame(width: 48, height: 52)
        .onReceive(Timer.publish(every: fps, on: .main, in: .common).autoconnect()) { _ in
            col = (col + 1) % mood.frames
        }
    }
}
