import SwiftUI

@main
struct CreamyCravingsKitchenApp: App {
    @State private var store = KitchenFinanceStore.sample

    var body: some Scene {
        WindowGroup {
            KitchenDashboardView(store: $store)
        }
    }
}
