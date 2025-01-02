import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ExpenseStore
    
    @State private var name = ""
    @State private var amount = 0.0
    @State private var date = Date()
    @State private var selectedCategory: Category?
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryEmoji = ""
    @State private var receiptImage: UIImage?
    
    var expense: Expense?
    var isEditing = false
    
    init(expense: Expense? = nil, isEditing: Bool = false) {
        self.expense = expense
        self.isEditing = isEditing
        _name = State(initialValue: expense?.name ?? "")
        _amount = State(initialValue: expense?.amount ?? 0.0)
        _date = State(initialValue: expense?.date ?? Date())
        _selectedCategory = State(initialValue: expense?.category)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    ReceiptScannerView(
                        name: $name,
                        amount: $amount,
                        date: $date,
                        receiptImage: $receiptImage
                    )
                }
                
                Section {
                    TextField("Expense Name", text: $name)
                    
                    HStack {
                        Text(store.profile.currency.symbol)
                        TextField("Amount", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select Category").tag(nil as Category?)
                        ForEach(store.categories) { category in
                            Text("\(category.emoji) \(category.name)")
                                .tag(category as Category?)
                        }
                    }
                    
                    Button("Add New Category") {
                        showingAddCategory = true
                    }
                }
                
                if isEditing {
                    Section {
                        Button("Delete Expense", role: .destructive) {
                            if let expense = expense {
                                store.deleteExpense(expense)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Expense" : "New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Add") {
                        guard let category = selectedCategory else { return }
                        
                        let newExpense = Expense(
                            id: expense?.id ?? UUID(),
                            name: name,
                            amount: amount,
                            date: date,
                            category: category
                        )
                        
                        if isEditing {
                            store.updateExpense(newExpense)
                        } else {
                            store.addExpense(newExpense)
                        }
                        
                        // Save receipt image if available
                        if let image = receiptImage,
                           let imageData = image.jpegData(compressionQuality: 0.8) {
                            store.saveReceiptImage(imageData, for: newExpense.id)
                        }
                        
                        dismiss()
                    }
                    .disabled(name.isEmpty || amount == 0 || selectedCategory == nil)
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                NavigationView {
                    Form {
                        TextField("Category Name", text: $newCategoryName)
                        TextField("Emoji", text: $newCategoryEmoji)
                            .onChange(of: newCategoryEmoji) { oldValue, newValue in
                                if newValue.count > 1 {
                                    newCategoryEmoji = String(newValue.prefix(1))
                                }
                            }
                    }
                    .navigationTitle("New Category")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingAddCategory = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Add") {
                                let newCategory = Category(
                                    name: newCategoryName,
                                    emoji: newCategoryEmoji.isEmpty ? "📍" : newCategoryEmoji
                                )
                                store.addCategory(newCategory)
                                selectedCategory = newCategory
                                showingAddCategory = false
                                newCategoryName = ""
                                newCategoryEmoji = ""
                            }
                            .disabled(newCategoryName.isEmpty)
                        }
                    }
                }
            }
        }
    }
}
