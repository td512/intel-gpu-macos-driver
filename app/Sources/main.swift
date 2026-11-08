// SPDX-License-Identifier: MIT
import AppKit
import SwiftUI

struct ManagerApp: App {
    @StateObject var manager = Manager()
    var body: some Scene {
        WindowGroup("IntelXe Manager") {
            RootView().environmentObject(manager)
        }
        .windowToolbarStyle(.unified)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

if CommandLine.arguments.contains("--selftest") {
    selfTest()
} else if CommandLine.arguments.contains("--gputest") {   // the Report page's quick GPU test, in Terminal
    for r in runGPUTest(progress: { _ in }) {
        let mark = r.state == .good ? "ok  " : r.state == .warning ? "warn" : r.state == .bad ? "BAD " : "    "
        print("\(mark) \(r.title.padding(toLength: 26, withPad: " ", startingAt: 0)) \(r.value)\(r.help.isEmpty ? "" : "\n       " + r.help)")
    }
} else {
    ManagerApp.main()
}
