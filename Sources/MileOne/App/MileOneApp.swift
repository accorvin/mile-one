#if canImport(UIKit)
import SwiftUI
import SwiftData

// MARK: - MileOneApp

@main
struct MileOneApp: App {

    private let container: ModelContainer

    init() {
        let useCloud = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")

        let config: ModelConfiguration
        if useCloud {
            config = ModelConfiguration(
                "MileOne",
                cloudKitDatabase: .automatic
            )
        } else {
            config = ModelConfiguration(
                "MileOne",
                cloudKitDatabase: .none
            )
        }

        do {
            container = try ModelContainer(
                for: UserProfile.self,
                      CompletedRun.self,
                      GPSPoint.self,
                      SavedRoute.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(dataStore: DataStore(modelContainer: container))
        }
        .modelContainer(container)
    }
}
#endif
