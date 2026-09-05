import SwiftUI

@main
struct AlistApp: App {
    @UIApplicationDelegateAdaptor(AlistAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
