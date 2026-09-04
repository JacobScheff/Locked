import FamilyControls
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager

    var body: some View {
        ZStack {
            if screenTime.isReady && screenTime.shouldCollectUsage {
                UsageReportHost(
                    selection: screenTime.selection,
                    dayKey: screenTime.reportDayKey,
                    nonce: screenTime.usageReportNonce
                )
            }

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
            .opacity(screenTime.isReady ? 1 : 0)
            .allowsHitTesting(screenTime.isReady)

            if !screenTime.isReady {
                LockedLaunchOverlay()
                    .transition(.opacity)
            }
        }
        .tint(.lockedIndigo)
        .fontDesign(.rounded)
        .familyActivityPicker(isPresented: $screenTime.isPickerPresented, selection: $screenTime.selection)
        .animation(.easeOut(duration: 0.32), value: screenTime.isReady)
    }
}

#Preview {
    ContentView()
        .environmentObject(ScreenTimeManager.shared)
}
