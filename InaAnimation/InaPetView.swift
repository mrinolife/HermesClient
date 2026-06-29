import SwiftUI

/// Simple static Ina pet — displays the inasprite as a small overlay.
struct InaPetView: View {
    let mood: InaMood
    
    enum InaMood: Int {
        case idle = 0, thinking = 1, wave = 3, jump = 4
    }
    
    var body: some View {
        Image("inasprite")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 48, height: 52)
            .opacity(0.9)
    }
}
