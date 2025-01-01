import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var store: ExpenseStore
    @State private var name: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var showingResetConfirmation = false
    @State private var showingBudgetSettings = false
    @State private var showingCurrencySettings = false
    
    // Calculate category totals
    var categoryTotals: [(Category, Double)] {
        store.categories.map { category in
            (category, store.totalForCategory(category))
        }.sorted { $0.1 > $1.1 }
    }
    
    // Refined, muted color palette
    let categoryColors: [Color] = [
        Color(red: 0.698, green: 0.463, blue: 0.475),  // Muted rose
        Color(red: 0.463, green: 0.549, blue: 0.612),  // Slate blue
        Color(red: 0.584, green: 0.647, blue: 0.545),  // Sage green
        Color(red: 0.729, green: 0.592, blue: 0.482),  // Warm taupe
        Color(red: 0.557, green: 0.506, blue: 0.631),  // Dusty purple
        Color(red: 0.608, green: 0.608, blue: 0.608)   // Warm gray
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack {
                            if let profileImage = profileImage {
                                profileImage
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.gray)
                            }
                            
                            PhotosPicker(selection: $selectedItem,
                                       matching: .images) {
                                Text("Change Photo")
                                    .font(.caption)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                    
                    TextField("Your Name", text: $name)
                        .textContentType(.name)
                        .onChange(of: name) { oldValue, newValue in
                            store.profile.name = newValue
                            store.synchronize()
                        }
                }
                
                Section("Statistics") {
                    HStack {
                        Text("Total Expenses")
                        Spacer()
                        Text(store.totalExpenses().formatted(.currency(code: store.profile.currency.rawValue)))
                            .bold()
                    }
                    
                    HStack {
                        Text("Number of Entries")
                        Spacer()
                        Text("\(store.expenses.count)")
                            .bold()
                    }
                }
                
                Section("Expense Distribution") {
                    if !store.expenses.isEmpty {
                        ChartView(data: categoryTotals, colors: categoryColors)
                            .frame(height: 300)
                            .padding(.vertical)
                        
                        // Category breakdown with matching text colors
                        ForEach(Array(categoryTotals.enumerated()), id: \.element.0.id) { index, categoryTotal in
                            let (category, total) = categoryTotal
                            let percentage = (total / store.totalExpenses()) * 100
                            let currentColor = categoryColors[index % categoryColors.count]
                            
                            HStack(spacing: 12) {
                                
                                // Category emoji and name with matching color
                                Text(category.emoji)
                                Text(category.name)
                                    .foregroundColor(currentColor)
                                    .bold()
                                
                                Spacer()
                                
                                // Amount and percentage
                                VStack(alignment: .trailing) {
                                    Text(total.formatted(.currency(code: store.profile.currency.rawValue)))
                                        .bold()
                                        .foregroundColor(currentColor)
                                    Text(String(format: "%.1f%%", percentage))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        Text("No expenses to display")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(action: {
                        showingBudgetSettings = true
                    }) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.blue)
                            Text("Budget Settings")
                            Spacer()
                            
                            // Show current period's budget status
                            let (message, color) = getBudgetStatus()
                            Text(message)
                                .font(.caption)
                                .foregroundColor(color)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        showingCurrencySettings = true
                    }) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.blue)
                            Text("Currency Settings")
                            Spacer()
                            Text(store.profile.currency.symbol)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                                
                Section {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset All Data")
                        }
                    }
                } footer: {
                    Text("This will delete all expenses and reset all settings to default.")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                name = store.profile.name
                if let imageData = store.profile.imageData,
                   let uiImage = UIImage(data: imageData) {
                    profileImage = Image(uiImage: uiImage)
                }
            }
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            if let compressedData = uiImage.jpegData(compressionQuality: 0.7) {
                                store.profile.imageData = compressedData
                                profileImage = Image(uiImage: uiImage)
                                store.synchronize()
                            }
                        }
                    }
                }
            }
            .confirmationDialog(
                "Reset All Data",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Everything", role: .destructive) {
                    store.resetToDefault()
                    name = store.profile.name
                    profileImage = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all your expenses and reset all settings. This action cannot be undone.")
            }
            .sheet(isPresented: $showingBudgetSettings) {
                BudgetSettingsView()
            }
            .sheet(isPresented: $showingCurrencySettings) {
                CurrencySettingsView(currentCurrency: store.profile.currency)
            }
        }
    }
    private func getBudgetStatus() -> (String, Color) {
            let settings = store.profile.budgetSettings
            switch settings.period {
            case .daily:
                guard let limit = settings.dailyLimit else { return ("Not set", .secondary) }
                return ("$\(String(format: "%.0f", limit))/day", .blue)
            case .monthly:
                guard let limit = settings.monthlyLimit else { return ("Not set", .secondary) }
                return ("$\(String(format: "%.0f", limit))/month", .blue)
            case .yearly:
                guard let limit = settings.yearlyLimit else { return ("Not set", .secondary) }
                return ("$\(String(format: "%.0f", limit))/year", .blue)
            }
        }
}

struct ChartView: View {
    let data: [(Category, Double)]
    let colors: [Color]
    
    var body: some View {
        GeometryReader { geometry in
            let total = data.reduce(0) { $0 + $1.1 }
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2.5
            
            ZStack {
                ForEach(data.indices, id: \.self) { index in
                    let (_, amount) = data[index]
                    let percentage = amount / total
                    let startAngle = data[..<index].reduce(0) { $0 + ($1.1 / total) } * 360
                    let endAngle = startAngle + (percentage * 360)
                    
                    PieSliceView(
                        center: center,
                        radius: radius,
                        startAngle: Angle(degrees: startAngle),
                        endAngle: Angle(degrees: endAngle)
                    )
                    .foregroundColor(colors[index % colors.count])
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
}

struct PieSliceView: Shape {
    var center: CGPoint
    var radius: CGFloat
    var startAngle: Angle
    var endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: center)
        path.addArc(center: center,
                   radius: radius,
                   startAngle: Angle(degrees: -90) + startAngle,
                   endAngle: Angle(degrees: -90) + endAngle,
                   clockwise: false)
        path.closeSubpath()
        return path
    }
}
