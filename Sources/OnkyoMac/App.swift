import SwiftUI

@main
struct OnkyoMacApp: App {
    @State private var onkyo = OnkyoSystem()

    init() {
        ScreenshotRenderer.runIfRequested()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environment(onkyo)
        } label: {
            Image(systemName: "hifireceiver")
        }
        .menuBarExtraStyle(.window)
    }
}
