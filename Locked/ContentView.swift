#if !targetEnvironment(macCatalyst)
import FamilyControls
#endif
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @State private var canMountInterface = false
    @State private var canStartUsageReport = false

    private var showsLaunchCover: Bool {
        !screenTime.isReady || !canMountInterface
    }

    var body: some View {
        ZStack {
            if canMountInterface {
                if canStartUsageReport && screenTime.shouldCollectUsage {
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

                    NavigationStack {
                        SettingsPage()
                    }
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
                .opacity(screenTime.isReady ? 1 : 0)
                .allowsHitTesting(screenTime.isReady)
            }

            if showsLaunchCover {
                LockedLaunchOverlay()
                    .transition(.opacity)
            }
        }
        .tint(.lockedIndigo)
        .fontDesign(.rounded)
        .familyActivityPicker(isPresented: $screenTime.isPickerPresented, selection: $screenTime.selection)
        .animation(.easeOut(duration: 0.28), value: showsLaunchCover)
        .onAppear {
            // Paint the overlay first, then build tabs underneath it.
            DispatchQueue.main.async {
                canMountInterface = true
                if screenTime.isReady {
                    canStartUsageReport = true
                }
            }
        }
        .onChange(of: screenTime.isReady) { _, ready in
            guard ready, !canStartUsageReport else { return }
            // Start the hidden Screen Time report after the first screen is up
            // so its remote view does not hitch the opening fade.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                canStartUsageReport = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ScreenTimeManager.shared)
        .environmentObject(ExternalSourceController.shared)
}
