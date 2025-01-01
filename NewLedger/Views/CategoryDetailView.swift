import SwiftUI

struct CategoryDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ExpenseStore
    let category: Category
    @State private var showingDeleteAlert = false
    @State private var isEditingName = false
    @State private var editedName: String
    
    init(category: Category) {
        self.category = category
        // Initialize the edited name with the current category name
        _editedName = State(initialValue: category.name)
    }
    
    var categoryExpenses: [Expense] {
        store.expenses
            .filter { $0.category.id == category.id }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    if isEditingName {
                        HStack {
                            Text(category.emoji)
                            TextField("Category Name", text: $editedName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .submitLabel(.done)
                                .onSubmit {
                                    saveNameChange()
                                }
                            
                            Button("Save") {
                                saveNameChange()
                            }
                            .disabled(editedName.isEmpty)
                        }
                    } else {
                        HStack {
                            Text("\(category.emoji) \(category.name)")
                                .font(.headline)
                            Spacer()
                            if category.name != "Others" {  // Prevent editing of "Others" category
                                Button(action: {
                                    isEditingName = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        HStack {
                            Text("Total")
                            Spacer()
                            Text(store.totalForCategory(category).formatted(.currency(code: store.profile.currency.rawValue)))
                                .font(.title2)
                                .bold()
                        }
                    }
                }
                
                Section("Expenses") {
                    if categoryExpenses.isEmpty {
                        Text("No expenses in this category")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(categoryExpenses) { expense in
                            ExpenseRowView(expense: expense)
                        }
                    }
                }
                
                if category.name != "Others" {  // Prevent deletion of default "Others" category
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Category")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Category Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Category", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    // Move all expenses to "Others" category
                    if let othersCategory = store.categories.first(where: { $0.name == "Others" }) {
                        for expense in categoryExpenses {
                            let updatedExpense = Expense(
                                id: expense.id,
                                name: expense.name,
                                amount: expense.amount,
                                date: expense.date,
                                category: othersCategory
                            )
                            store.updateExpense(updatedExpense)
                        }
                    }
                    
                    // Delete the category
                    store.deleteCategory(category)
                    dismiss()
                }
            } message: {
                Text("All expenses in this category will be moved to 'Others'. This action cannot be undone.")
            }
        }
    }
    
    private func saveNameChange() {
        guard !editedName.isEmpty else { return }
        
        // Create updated category
        let updatedCategory = Category(id: category.id, name: editedName, emoji: category.emoji)
        
        // Update all expenses that use this category
        for expense in categoryExpenses {
            let updatedExpense = Expense(
                id: expense.id,
                name: expense.name,
                amount: expense.amount,
                date: expense.date,
                category: updatedCategory
            )
            store.updateExpense(updatedExpense)
        }
        
        // Update the category in the store
        if let index = store.categories.firstIndex(where: { $0.id == category.id }) {
            store.categories[index] = updatedCategory
            store.synchronize()
        }
        
        isEditingName = false
    }
}

struct ExpenseRowView: View {
    @EnvironmentObject var store: ExpenseStore
    let expense: Expense
    @State private var showingEditSheet = false
    
    var body: some View {
        Button(action: { showingEditSheet = true }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(expense.name)
                        .font(.headline)
                    Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(expense.amount.formatted(.currency(code: store.profile.currency.rawValue)))
                    .font(.subheadline)
                    .bold()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddExpenseView(expense: expense, isEditing: true)
        }
    }
}
