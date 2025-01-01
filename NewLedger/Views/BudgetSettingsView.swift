import SwiftUI

struct BudgetSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ExpenseStore
    
    @State private var selectedPeriod: BudgetPeriod = .monthly
    @State private var dailyLimit: String = ""
    @State private var monthlyLimit: String = ""
    @State private var yearlyLimit: String = ""
    
    private var budgetStatus: [(String, Color)] {
        let calendar = Calendar.current
        let now = Date()
        var statuses: [(String, Color)] = []
        
        // Daily status
        if let dailyLimitValue = store.profile.budgetSettings.dailyLimit {
            let dailyExpenses = store.expenses
                .filter { calendar.isDate($0.date, inSameDayAs: now) }
                .reduce(0) { $0 + $1.amount }
            let dailyDifference = dailyLimitValue - dailyExpenses
            statuses.append(getStatusMessage(difference: dailyDifference, period: "Daily"))
        }
        
        // Monthly status
        if let monthlyLimitValue = store.profile.budgetSettings.monthlyLimit {
            let monthlyExpenses = store.expenses
                .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
                .reduce(0) { $0 + $1.amount }
            let monthlyDifference = monthlyLimitValue - monthlyExpenses
            statuses.append(getStatusMessage(difference: monthlyDifference, period: "Monthly"))
        }
        
        // Yearly status
        if let yearlyLimitValue = store.profile.budgetSettings.yearlyLimit {
            let yearlyExpenses = store.expenses
                .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .year) }
                .reduce(0) { $0 + $1.amount }
            let yearlyDifference = yearlyLimitValue - yearlyExpenses
            statuses.append(getStatusMessage(difference: yearlyDifference, period: "Yearly"))
        }
        
        return statuses
    }
    
    private func getStatusMessage(difference: Double, period: String) -> (String, Color) {
        if difference > 0 {
            return ("\(period): Saved \(difference.formatted(.currency(code: "USD")))", .green)
        } else if difference < 0 {
            return ("\(period): Over budget by \(abs(difference).formatted(.currency(code: "USD")))", .red)
        } else {
            return ("\(period): Exactly on budget", .blue)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Budget Limits") {
                    HStack {
                        Text("Daily")
                        Spacer()
                        Text("$")
                        TextField("Daily Limit", text: $dailyLimit)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Monthly")
                        Spacer()
                        Text("$")
                        TextField("Monthly Limit", text: $monthlyLimit)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Yearly")
                        Spacer()
                        Text("$")
                        TextField("Yearly Limit", text: $yearlyLimit)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                if !budgetStatus.isEmpty {
                    Section("Current Status") {
                        ForEach(budgetStatus, id: \.0) { status in
                            Text(status.0)
                                .foregroundColor(status.1)
                        }
                    }
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
