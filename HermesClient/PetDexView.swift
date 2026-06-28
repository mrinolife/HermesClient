import SwiftUI

/// Native PetDex viewer — loads spritesheets from Hermes server, animates them.
/// Fetches pet list from /api/pet/list, loads spritesheets from /api/pet/spritesheet/<slug>.
struct PetDexView: View {
    @EnvironmentObject var appState: AppState
    @State private var pets: [PetEntry] = []
    @State private var selectedSlug: String = ""
    @State private var currentState: String = "idle"
    @State private var frame: Int = 0
    @State private var spritesheet: UIImage?
    @State private var loading = true
    @State private var showPicker = false
    
    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    
    struct PetEntry: Identifiable {
        let slug: String
        let hasSpritesheet: Bool
        var displayName: String { slug.split(separator: "-").map(String.init).joined(separator: " ").capitalized }
        var id: String { slug }
    }
    
    // 8 cols × 9 rows, 192×208 per frame
    let cols = 8
    let states: [(name: String, row: Int)] = [
        ("idle", 0), ("run", 1), ("review", 2), ("wave", 3),
        ("jump", 4), ("waiting", 5), ("failed", 6)
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            // Pet canvas
            ZStack {
                if let img = spritesheet {
                    let fw = img.size.width / CGFloat(cols)
                    let fh = img.size.height / 9
                    let row = states.first(where: { $0.name == currentState })?.row ?? 0
                    
                    Image(uiImage: img)
                        .resizable()
                        .frame(width: 64, height: 70)
                        .clipped()
                        .offset(x: -CGFloat(frame) * fw * (64/fw),
                                y: -CGFloat(row) * fh * (70/fh))
                        .frame(width: 64, height: 70, alignment: .topLeading)
                } else if loading {
                    ProgressView()
                        .frame(width: 64, height: 70)
                } else {
                    Image(systemName: "pawprint")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(width: 64, height: 70)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Pet name
            Text(pets.first(where: { $0.slug == selectedSlug })?.displayName ?? "")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // Quick state indicator
            Text(currentState)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.purple.opacity(0.7))
                .textCase(.uppercase)
        }
        .frame(width: 80)
        .onTapGesture { showPicker.toggle() }
        .confirmationDialog("Choose Pet", isPresented: $showPicker) {
            ForEach(pets.filter(\.hasSpritesheet)) { pet in
                Button(pet.displayName) { selectPet(pet.slug) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task { await loadPetList() }
        .onReceive(timer) { _ in
            frame = (frame + 1) % cols
        }
    }
    
    func selectPet(_ slug: String) {
        selectedSlug = slug
        UserDefaults.standard.set(slug, forKey: "selected_pet")
        Task { await loadSpritesheet(slug) }
    }
    
    func loadPetList() async {
        guard let url = URL(string: "\(appState.serverURL)/api/pet/list") else { return }
        loading = true
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let list = json["pets"] as? [[String: Any]] {
                pets = list.compactMap { d in
                    guard let slug = d["slug"] as? String else { return nil }
                    return PetEntry(slug: slug, hasSpritesheet: d["hasSpritesheet"] as? Bool ?? false)
                }
                let saved = UserDefaults.standard.string(forKey: "selected_pet") ?? pets.first?.slug ?? ""
                selectedSlug = saved
                if !saved.isEmpty { await loadSpritesheet(saved) }
            }
        } catch { }
        loading = false
    }
    
    func loadSpritesheet(_ slug: String) async {
        guard let url = URL(string: "\(appState.serverURL)/api/pet/spritesheet/\(slug)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            spritesheet = UIImage(data: data)
        } catch { }
    }
}
