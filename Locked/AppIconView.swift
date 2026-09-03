import SwiftUI

struct AppIconView: View {
    let appName: String
    @State private var iconImage: UIImage?

    var body: some View {
        ZStack {
            if let iconImage {
                Image(uiImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.lockedIndigo.opacity(0.12))
                    .overlay {
                        Text(String(appName.prefix(1)).uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.lockedIndigo)
                    }
            }
        }
        .task(id: appName) {
            await fetchAndCacheIcon()
        }
    }

    private func fetchAndCacheIcon() async {
        let safeName = appName.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? appName
        let cachePath = URL.cachesDirectory.appending(path: "\(safeName)_icon.png")

        if let cachedData = try? Data(contentsOf: cachePath), let image = UIImage(data: cachedData) {
            self.iconImage = image
        }

        guard let encodedTerm = appName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let apiURL = URL(string: "https://itunes.apple.com/search?entity=software&term=\(encodedTerm)")
        else { return }

        do {
            let (apiData, _) = try await URLSession.shared.data(from: apiURL)

            struct SearchResponse: Decodable {
                struct Result: Decodable { let artworkUrl100: String }
                let results: [Result]
            }

            if let imgUrlStr = try JSONDecoder().decode(SearchResponse.self, from: apiData).results.first?.artworkUrl100,
               let imgURL = URL(string: imgUrlStr) {

                let (imageData, _) = try await URLSession.shared.data(from: imgURL)

                if let newImage = UIImage(data: imageData) {
                    self.iconImage = newImage
                    try? imageData.write(to: cachePath)
                }
            }
        } catch {
            print("No Wi-Fi/API Failed. Relying on local image if it exists: \(error.localizedDescription)")
        }
    }
}
