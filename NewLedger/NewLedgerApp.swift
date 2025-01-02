import SwiftUI

@main
struct NewLedgerApp: App {
    @StateObject private var store = ExpenseStore()
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var currencyService = CurrencyService.shared
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(store)
                .environmentObject(currencyService)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .inactive || newPhase == .background {
                        store.synchronize()
                    }
                }
        }
    }
}
