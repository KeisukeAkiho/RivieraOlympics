import SwiftUI

@main
struct RivieraOlympicsApp: App {
    @StateObject private var store = RoundStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
