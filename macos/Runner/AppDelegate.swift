import Cocoa
import FlutterMacOS
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate {
  private var sleepAssertion: NSObjectProtocol?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if let error = error {
        print("Notification permission error: \(error)")
      }
    }

    setupMethodChannel()
    preventSleep()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  private func setupMethodChannel() {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.teams.app/settings",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "preventSleep":
        self?.preventSleep()
        result(true)
      case "allowSleep":
        self?.allowSleep()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func preventSleep() {
    if sleepAssertion == nil {
      sleepAssertion = ProcessInfo.processInfo.beginActivity(
        options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled],
        reason: "Microsoft Teams - manter status ativo"
      )
    }
  }

  private func allowSleep() {
    if let assertion = sleepAssertion {
      ProcessInfo.processInfo.endActivity(assertion)
      sleepAssertion = nil
    }
  }
}
