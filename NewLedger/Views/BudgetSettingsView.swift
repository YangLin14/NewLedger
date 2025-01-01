import SwiftUI

struct BudgetSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ExpenseStore
    
    @State private var selectedPeriod: BudgetPeriod = .monthly
    @State private var dailyLimit: String = ""
    @State private var monthlyLimit: String = ""
    @State private var yearlyLimit: String = ""
    
    private var savingsMessage: (String, Color) {
        let calendar = Calendar.current
        let now = Date()
        
        let currentLimit: Double?
        let totalExpenses: Double
        
        switch selectedPeriod {
        case .daily:
            currentLimit = store.profile.budgetSettings.dailyLimit
            totalExpenses = store.expenses
                .filter { calendar.isDate($0.date, inSameDayAs: now) }
                .reduce(0) { $0 + $1.amount }
        case .monthly:
            currentLimit = store.profile.budgetSettings.monthlyLimit
            totalExpenses = store.expenses
                .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
                .reduce(0) { $0 + $1.amount }
        case .yearly:
            currentLimit = store.profile.budgetSettings.yearlyLimit
            totalExpenses = store.expenses
                .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .year) }
                .reduce(0) { $0 + $1.amount }
        }
        
        guard let limit = currentLimit else {
            return ("No budget limit set", .secondary)
        }
        
        let difference = limit - totalExpenses
        
        if difference > 0 {
            return ("You've saved \(difference.formatted(.currency(code: "USD"))) so far!", .green)
        } else if difference < 0 {
            return ("You've exceeded your budget by \(abs(difference).formatted(.currency(code: "USD")))", .red)
        } else {
            return ("You've exactly met your budget", .blue)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Budget Period", selection: $selectedPeriod) {
                        ForEach(BudgetPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .onChange(of: selectedPeriod) { _, _ in
                        store.profile.budgetSettings.period = selectedPeriod
                        store.synchronize()
                    }
                }
                
                Section("Set Budget Limit") {
                    switch selectedPeriod {
                    case .daily:
                        HStack {
                            Text("$")
                            TextField("Daily Limit", text: $dailyLimit)
                                .keyboardType(.decimalPad)
                        }
                    case .monthly:
                        HStack {
                            Text("$")
                            TextField("Monthly Limit", text: $monthlyLimit)
                                .keyboardType(.decimalPad)
                        }
                    case .yearly:
                        HStack {
                            Text("$")
                            TextField("Yearly Limit", text: $yearlyLimit)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .center, spacing: 8) {
                        Text(savingsMessage.0)
                            .foregroundColor(savingsMessage.1)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Budget Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBudgetSettings()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedPeriod = store.profile.budgetSettings.period
                if let daily = store.profile.budgetSettings.dailyLimit {
                    dailyLimit = String(format: "%.2f", daily)
                }
                if let monthly = store.profile.budgetSettings.monthlyLimit {
                    monthlyLimit = String(format: "%.2f", monthly)
                }
                if let yearly = store.profile.budgetSettings.yearlyLimit {
                    yearlyLimit = String(format: "%.2f", yearly)
                }
            }
        }
    }
    
    private func saveBudgetSettings() {
        store.profile.budgetSettings.dailyLimit = Double(dailyLimit)
        store.profile.budgetSettings.monthlyLimit = Double(monthlyLimit)
        store.profile.budgetSettings.yearlyLimit = Double(yearlyLimit)
        store.profile.budgetSettings.period = selectedPeriod
        store.synchronize()
    }
}