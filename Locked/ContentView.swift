import FamilyControls
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager

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
        .familyActivityPicker(isPresented: $screenTime.isPickerPresented, selection: $screenTime.selection)
    }
}

#Preview {
    ContentView()
        .environmentObject(ScreenTimeManager.shared)
}
