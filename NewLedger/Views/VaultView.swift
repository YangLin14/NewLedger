import SwiftUI

enum TimePeriod: String, CaseIterable {
    case daily = "Daily"
    case monthly = "Monthly"
    case yearly = "Yearly"
}

// Convert BudgetPeriod to TimePeriod for comparison
extension BudgetPeriod {
    func toTimePeriod() -> TimePeriod {
        switch self {
        case .daily:
            return .daily
        case .monthly:
            return .monthly
        case .yearly:
            return .yearly
        }
    }
}

struct VaultView: View {
    @EnvironmentObject var store: ExpenseStore
    @State private var selectedCategory: Category?
    @Binding var showingAddExpense: Bool
    @State private var selectedPeriod: TimePeriod = .daily
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    
    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = store.profile.name
        if hour < 12 {
            return "Good Morning, \(name)"
        } else if hour < 18 {
            return "Good Afternoon, \(name)"
        } else {
            return "Good Evening, \(name)"
        }
    }
    
    // Helper computed property to check if any categories are visible
    private var hasVisibleCategories: Bool {
        store.categories.contains { category in
            expenseCountForCategory(category) > 0 || selectedPeriod != .daily
        }
    }
    
    var dailyExpenses: [Expense] {
        let calendar = Calendar.current
        return store.expenses.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    var monthlyExpenses: [Expense] {
        let calendar = Calendar.current
        return store.expenses.filter { calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .month) }
    }
    
    var yearlyExpenses: [Expense] {
        let calendar = Calendar.current
        return store.expenses.filter { calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .year) }
    }
    
    func getBudgetStatus(for period: TimePeriod) -> (String, Color) {
        let expenses: [Expense]
        let limit: Double?
        let periodName: String
        
        switch period {
        case .daily:
            expenses = dailyExpenses
            limit = store.profile.budgetSettings.dailyLimit
            periodName = "Daily"
        case .monthly:
            expenses = monthlyExpenses
            limit = store.profile.budgetSettings.monthlyLimit
            periodName = "Monthly"
        case .yearly:
            expenses = yearlyExpenses
            limit = store.profile.budgetSettings.yearlyLimit
            periodName = "Yearly"
        }
        
        let total = expenses.reduce(0) { $0 + $1.amount }
        
        guard let budgetLimit = limit else {
            return ("\(periodName): No budget set", .secondary)
        }
        
        let difference = budgetLimit - total
        
        if difference > 0 {
            return ("\(periodName): \(total.formatted(.currency(code: "USD"))) of \(budgetLimit.formatted(.currency(code: "USD")))", .green)
        } else if difference < 0 {
            return ("\(periodName): Over by \(abs(difference).formatted(.currency(code: "USD")))", .red)
        } else {
            return ("\(periodName): Budget met", .blue)
        }
    }
    
    var currentPeriodText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: selectedDate)
    }
    
    var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        
        return store.expenses.filter { expense in
            switch selectedPeriod {
            case .daily:
                return calendar.isDate(expense.date, inSameDayAs: selectedDate)
            case .monthly:
                return calendar.isDate(expense.date, equalTo: selectedDate, toGranularity: .month)
            case .yearly:
                return calendar.isDate(expense.date, equalTo: selectedDate, toGranularity: .year)
            }
        }
    }
    
    var totalForPeriod: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var budgetStatus: (String, Color)? {
        let settings = store.profile.budgetSettings
        
        // Only show budget status if the selected period matches the budget period
        guard settings.period.toTimePeriod() == selectedPeriod else {
            return nil
        }
        
        let currentLimit: Double?
        switch selectedPeriod {
        case .daily:
            currentLimit = settings.dailyLimit
        case .monthly:
            currentLimit = settings.monthlyLimit
        case .yearly:
            currentLimit = settings.yearlyLimit
        }
        
        guard let limit = currentLimit else {
            return ("No budget limit set", .secondary)
        }
        
        let difference = limit - totalForPeriod
        
        if difference > 0 {
            return ("You've saved \(difference.formatted(.currency(code: "USD"))) so far!", .green)
        } else if difference < 0 {
            return ("You've exceeded your budget by \(abs(difference).formatted(.currency(code: "USD")))", .red)
        } else {
            return ("You've exactly met your budget", .blue)
        }
    }
    
    func totalForCategory(_ category: Category) -> Double {
        filteredExpenses
            .filter { $0.category.id == category.id }
            .reduce(0) { $0 + $1.amount }
    }
    
    func expenseCountForCategory(_ category: Category) -> Int {
        filteredExpenses.filter { $0.category.id == category.id }.count
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(spacing: 12) {
                        Picker("Time Period", selection: $selectedPeriod) {
                            ForEach(TimePeriod.allCases, id: \.self) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        HStack {
                            Button(action: { moveDate(by: -1) }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.blue)
                            }
                            
                            Button(action: { showingDatePicker = true }) {
                                Text(currentPeriodText)
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            
                            Button(action: { moveDate(by: 1) }) {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // Budget Status Section
                Section("Budget Status") {
                    let status = getBudgetStatus(for: selectedPeriod)
                    HStack {
                        Text(status.0)
                            .foregroundColor(status.1)
                    }
                }
                
                // Total expenses section
                Section {
                    HStack {
                        Text("Total Expenses")
                            .font(.headline)
                        Spacer()
                        Text(totalForPeriod.formatted(.currency(code: "USD")))
                            .font(.title2)
                            .bold()
                    }
                }
                
                // Categories section
                Section("Categories") {
                    if !hasVisibleCategories {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue.opacity(0.8))
                                Text("No Categories Yet!")
                                    .font(.headline)
                                Text("Start tracking your expenses from clicking on the plus icon")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        ForEach(store.categories) { category in
                            if expenseCountForCategory(category) > 0 || selectedPeriod != .daily {
                                CategoryRowView(
                                    category: category,
                                    total: totalForCategory(category),
                                    count: expenseCountForCategory(category)
                                )
                                .onTapGesture {
                                    selectedCategory = category
                                }
                            }
                        }
                        .onMove { from, to in
                            store.categories.move(fromOffsets: from, toOffset: to)
                            store.synchronize()
                        }
                    }
                }
            }
            .navigationTitle("NewLedger 🏦")
            .sheet(item: $selectedCategory) { category in
                CategoryDetailView(category: category)
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationView {
                    DatePickerView(selectedDate: $selectedDate, period: selectedPeriod)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddExpense = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
    }
    
    private func moveDate(by value: Int) {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .daily:
            if let newDate = calendar.date(byAdding: .day, value: value, to: selectedDate) {
                selectedDate = newDate
            }
        case .monthly:
            if let newDate = calendar.date(byAdding: .month, value: value, to: selectedDate) {
                selectedDate = newDate
            }
        case .yearly:
            if let newDate = calendar.date(byAdding: .year, value: value, to: selectedDate) {
                selectedDate = newDate
            }
        }
    }
}

// MARK: - CategoryRowView
struct CategoryRowView: View {
    let category: Category
    let total: Double
    let count: Int
    
    var body: some View {
        HStack {
            Text(category.emoji)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text(category.name)
                    .font(.headline)
                Text("\(count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(total.formatted(.currency(code: "USD")))
                .font(.subheadline)
                .bold()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - DatePickerView
struct DatePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDate: Date
    let period: TimePeriod
    
    // Current selections for month/year pickers
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    
    var body: some View {
        List {
            switch period {
            case .daily:
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                
            case .monthly:
                VStack {
                    HStack {
                        // Month Picker
                        Picker("Month", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(monthName(month))
                                    .tag(month)
                            }
                        }
                        .pickerStyle(.wheel)
                        
                        // Year Picker
                        Picker("Year", selection: $selectedYear) {
                            ForEach(-5...5, id: \.self) { yearOffset in
                                Text(String(Calendar.current.component(.year, from: Date()) + yearOffset))
                                    .tag(Calendar.current.component(.year, from: Date()) + yearOffset)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                }
                .onChange(of: selectedMonth) { _, _ in
                    updateSelectedDate()
                }
                .onChange(of: selectedYear) { _, _ in
                    updateSelectedDate()
                }
                
            case .yearly:
                Picker("Select Year", selection: $selectedYear) {
                    ForEach(-5...5, id: \.self) { yearOffset in
                        Text(String(Calendar.current.component(.year, from: Date()) + yearOffset))
                            .tag(Calendar.current.component(.year, from: Date()) + yearOffset)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: selectedYear) { _, _ in
                    updateSelectedDate()
                }
            }
        }
        .navigationTitle("Select \(period.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            // Initialize the pickers with the current selection
            let calendar = Calendar.current
            selectedMonth = calendar.component(.month, from: selectedDate)
            selectedYear = calendar.component(.year, from: selectedDate)
        }
    }
    
    private func monthName(_ month: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        guard let date = Calendar.current.date(from: DateComponents(year: 2000, month: month)) else {
            return ""
        }
        return dateFormatter.string(from: date)
    }
    
    private func updateSelectedDate() {
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1 // First day of the month
        
        if let newDate = Calendar.current.date(from: components) {
            selectedDate = newDate
        }
    }
}
