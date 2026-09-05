import BackgroundTasks
import UIKit

final class AlistAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.alist.ios.processing", using: nil) { task in
            // The Go task store is the source of truth. The next foreground
            // launch will resume unfinished work after this short wakeup.
            task.setTaskCompleted(success: true)
        }
        return true
    }
}
