// SPDX-License-Identifier: MIT
import AppKit
import SwiftUI

struct ManagerApp: App {
    @StateObject var manager = Manager()
    @StateObject var menuModel = MonitorModel()
    @AppStorage("menuBarItem") var menuBarItem = false
    var body: some Scene {
        WindowGroup("IntelXe Manager", id: "main") {
            RootView().environmentObject(manager)
        }
        .windowToolbarStyle(.unified)
        .commands { CommandGroup(replacing: .newItem) {} }
        MenuBarExtra(isInserted: $menuBarItem) {
            MenuBarContent(model: menuModel).onAppear { menuModel.start() }
        } label: {
            Image(systemName: "gauge.with.dots.needle.33percent")
        }
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
