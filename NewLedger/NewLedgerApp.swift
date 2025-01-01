//
//  NewLedgerApp.swift
//  NewLedger
//
//  Created by Fong Yu Lin on 12/30/24.
//

import SwiftUI

@main
struct NewLedgerApp: App {
    @StateObject private var store = ExpenseStore()
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var currencyService = CurrencyService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .inactive || newPhase == .background {
                        store.synchronize()
                    }
                }
        }
    }
}
