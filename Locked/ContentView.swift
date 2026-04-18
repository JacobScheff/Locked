import SwiftUI
import WidgetKit

struct ContentView: View {
    var body: some View {
        TabView {
            // Home Page
            NavigationStack {
                MainPage()
                    .navigationTitle("Home")
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            
            // Courses + Assignments Pages
            NavigationStack {
                CoursesPage()
                    .navigationTitle("Courses")
            }
            .tabItem {
                Label("Courses", systemImage: "list.bullet")
            }
        }
    }
}

#Preview {
    ContentView()
}
