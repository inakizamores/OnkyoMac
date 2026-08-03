import SwiftUI

@main
struct OnkyoMacApp: App {
    @State private var onkyo = OnkyoSystem()

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
