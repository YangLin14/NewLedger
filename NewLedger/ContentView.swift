//
//  ContentView.swift
//  NewLedger
//
//  Created by Fong Yu Lin on 12/30/24.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showingAddExpense = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            VaultView(showingAddExpense: $showingAddExpense)
                .tabItem {
                    Label("Vault", systemImage: "clipboard.fill")
                }
                .tag(0)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(1)
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
