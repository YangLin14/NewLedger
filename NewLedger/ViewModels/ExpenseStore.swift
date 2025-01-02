import Foundation
import SwiftUI

class ExpenseStore: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var categories: [Category] = Category.defaultCategories
    @Published var profile = Profile(name: "User")
    
    private let expensesKey = "savedExpenses"
    private let categoriesKey = "savedCategories"
    private let profileKey = "savedProfile"
    
    init() {
        loadData()
    }
    
    func addExpense(_ expense: Expense) {
        expenses.append(expense)
        synchronize()  // Changed from saveExpenses() to synchronize()
    }
    
    func deleteExpense(_ expense: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses.remove(at: index)
            synchronize()  // Changed from saveExpenses() to synchronize()
        }
    }
    
    func updateExpense(_ expense: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
            synchronize()  // Changed from saveExpenses() to synchronize()
        }
    }
    
    func totalForCategory(_ category: Category) -> Double {
        expenses
            .filter { $0.category.id == category.id }
            .reduce(0) { $0 + $1.amount }
    }
    
    func totalExpenses() -> Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    private func loadData() {
        // Load expenses
        if let data = UserDefaults.standard.data(forKey: expensesKey) {
            do {
                let decoder = JSONDecoder()
                let decoded = try decoder.decode([Expense].self, from: data)
                self.expenses = decoded
            } catch {
                print("Error decoding expenses: \(error)")
                self.expenses = []
            }
        }
        
        // Load categories
        if let data = UserDefaults.standard.data(forKey: categoriesKey) {
            do {
                let decoder = JSONDecoder()
                let decoded = try decoder.decode([Category].self, from: data)
                self.categories = decoded
            } catch {
                print("Error decoding categories: \(error)")
                self.categories = Category.defaultCategories
            }
        }
        
        // Load profile
        if let data = UserDefaults.standard.data(forKey: profileKey) {
            do {
                let decoder = JSONDecoder()
                let decoded = try decoder.decode(Profile.self, from: data)
                self.profile = decoded
            } catch {
                print("Error decoding profile: \(error)")
            }
        }
    }
    
    private func saveExpenses() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(expenses)
            UserDefaults.standard.set(data, forKey: expensesKey)
        } catch {
            print("Error encoding expenses: \(error)")
        }
    }
    
    private func saveCategories() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(categories)
            UserDefaults.standard.set(data, forKey: categoriesKey)
        } catch {
            print("Error encoding categories: \(error)")
        }
    }
    
    func saveProfile() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(profile)
            UserDefaults.standard.set(data, forKey: profileKey)
        } catch {
            print("Error encoding profile: \(error)")
        }
    }
    
    func synchronize() {
        saveExpenses()
        saveCategories()
        saveProfile()
        UserDefaults.standard.synchronize()
    }
    
    func resetToDefault() {
        expenses = []
        categories = Category.defaultCategories
        profile = Profile(name: "User")
        profile.imageData = nil
        synchronize()
    }
    
    func addCategory(_ category: Category) {
        categories.append(category)
        synchronize()
    }

    func deleteCategory(_ category: Category) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories.remove(at: index)
            synchronize()
        }
    }
}

extension ExpenseStore {
    func saveReceiptImage(_ imageData: Data, for expenseId: UUID) {
        let receiptsFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("receipts")
        
        try? FileManager.default.createDirectory(at: receiptsFolder, withIntermediateDirectories: true)
        
        let imageUrl = receiptsFolder.appendingPathComponent("\(expenseId.uuidString).jpg")
        try? imageData.write(to: imageUrl)
    }
    
    func getReceiptImage(for expenseId: UUID) -> Data? {
        guard let imageUrl = Expense(id: expenseId, name: "", amount: 0, date: Date(), category: Category(name: "", emoji: "")).receiptImageURL,
              let imageData = try? Data(contentsOf: imageUrl) else {
            return nil
        }
        return imageData
    }
}
