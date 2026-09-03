import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                MainPage()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                CoursesPage()
            }
            .tabItem {
                Label("Courses", systemImage: "book.fill")
            }

            NavigationStack {
                HowToUseView()
            }
            .tabItem {
                Label("Guide", systemImage: "questionmark.circle.fill")
            }
        }
        .tint(.lockedIndigo)
        .fontDesign(.rounded)
    }
}

#Preview {
    ContentView()
}
