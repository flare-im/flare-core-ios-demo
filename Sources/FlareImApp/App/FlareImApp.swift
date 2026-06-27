import SwiftUI

public struct FlareImRootView: View {
    @StateObject private var store = FlareAppStore()

    public init() {}

    public var body: some View {
        RootWorkbenchView()
            .environmentObject(store)
            .environmentObject(store.environment)
            .environmentObject(store.messagingViewModel)
            .environmentObject(store.sdkLabViewModel)
            .environmentObject(store.searchViewModel)
            .environmentObject(store.authViewModel)
            .environmentObject(store.settingsViewModel)
    }
}
