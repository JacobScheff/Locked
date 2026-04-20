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
                Color.gray.opacity(0.1)
                    .overlay(
                        Image(systemName: "app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
                
                // Loading spinner
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .task(id: appName) {
            await fetchAndCacheIcon()
        }
    }

    private func fetchAndCacheIcon() async {
        let safeName = appName.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? appName
        let cachePath = URL.cachesDirectory.appending(path: "\(safeName)_icon.png")
        
        // Load image from cache if it exists
        if let cachedData = try? Data(contentsOf: cachePath), let image = UIImage(data: cachedData) {
            self.iconImage = image
        }
        
        // Fetch from API to get the App's latest Icon URL
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
                
                // Download the Image Bytes
                let (imageData, _) = try await URLSession.shared.data(from: imgURL)
                
                // Cache the image to local storage
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
