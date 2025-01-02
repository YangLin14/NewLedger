import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var store: ExpenseStore
    @State private var name: String = ""
    @State private var profileImage: Image?
    @State private var backgroundImage: Image?
    @State private var selectedProfileItem: PhotosPickerItem?
    @State private var selectedBackgroundItem: PhotosPickerItem?
    @State private var showingProfilePopup = false
    @State private var showingBackgroundPopup = false
    @State private var showingResetConfirmation = false
    @State private var showingBudgetSettings = false
    @State private var showingCurrencySettings = false
    @State private var showingProfileEditSheet = false

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
    
    var defaultBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.4, green: 0.5, blue: 0.6),
                Color(red: 0.2, green: 0.3, blue: 0.4)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        NavigationView {
            List {
                // Header Section
                Section {
                    VStack(spacing: 0) {
                        // Background Image Section
                        ZStack(alignment: .bottomLeading) {
                            // Background Image
                            if let backgroundImage = backgroundImage {
                                backgroundImage
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .clipped()
                            } else {
                                defaultBackground
                                    .frame(height: 200)
                            }
                            
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.4),
                                    Color.black.opacity(0)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .frame(height: 200)
                            
                            // Profile Info Container
                            HStack(spacing: 12) {
                                // Profile Picture
                                if let profileImage = profileImage {
                                    profileImage
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 70, height: 70)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .padding(12)
                                        .frame(width: 70, height: 70)
                                        .background(Color.gray.opacity(0.3))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                
                                // Name
                                TextField("Your Name", text: $name)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                                    .onChange(of: name) { oldValue, newValue in
                                        store.profile.name = newValue
                                        store.synchronize()
                                    }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .onTapGesture {
                    showingProfileEditSheet = true
                }
                
                // Statistics Section
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
                
                // Expense Distribution Section
                Section("Expense Distribution") {
                    if !store.expenses.isEmpty {
                        ChartView(data: categoryTotals, colors: categoryColors)
                            .frame(height: 300)
                            .padding(.vertical)
                        
                        ForEach(Array(categoryTotals.enumerated()), id: \.element.0.id) { index, categoryTotal in
                            let (category, total) = categoryTotal
                            let percentage = (total / store.totalExpenses()) * 100
                            let currentColor = categoryColors[index % categoryColors.count]
                            
                            HStack(spacing: 12) {
                                Text(category.emoji)
                                Text(category.name)
                                    .foregroundColor(currentColor)
                                    .bold()
                                
                                Spacer()
                                
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
                
                // Settings Sections
                Section {
                    Button(action: {
                        showingBudgetSettings = true
                    }) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.blue)
                            Text("Budget Settings")
                            Spacer()
                            
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
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingProfileEditSheet) {
                ProfileEditSheet(
                    name: $name,
                    profileImage: $profileImage,
                    backgroundImage: $backgroundImage,
                    selectedProfileItem: $selectedProfileItem,
                    selectedBackgroundItem: $selectedBackgroundItem,
                    onProfilePhotoChange: { item in
                        handleProfilePhotoSelection(item)
                    },
                    onBackgroundPhotoChange: { item in
                        handleBackgroundPhotoSelection(item)
                    }
                )
            }
            .sheet(isPresented: $showingBudgetSettings) {
                BudgetSettingsView()
            }
            .sheet(isPresented: $showingCurrencySettings) {
                CurrencySettingsView(currentCurrency: store.profile.currency)
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
            .onAppear {
                loadStoredData()
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
    
    private func loadStoredData() {
        name = store.profile.name
        
        // Load profile image
        if let imageData = store.profile.imageData,
           let uiImage = UIImage(data: imageData) {
            profileImage = Image(uiImage: uiImage)
        }
        
        // Load background image
        if let backgroundData = store.profile.backgroundImageData,
           let uiImage = UIImage(data: backgroundData) {
            backgroundImage = Image(uiImage: uiImage)
        }
    }
    
    private func handleProfilePhotoSelection(_ item: PhotosPickerItem?) {
        Task {
            if let data = try? await item?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data),
               let compressedData = uiImage.compressedForStorage() {
                store.profile.imageData = compressedData
                profileImage = Image(uiImage: uiImage)
                store.synchronize()
            }
        }
    }
    
    private func handleBackgroundPhotoSelection(_ item: PhotosPickerItem?) {
        Task {
            if let data = try? await item?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data),
               let compressedData = uiImage.compressedForStorage() {
                store.profile.backgroundImageData = compressedData
                backgroundImage = Image(uiImage: uiImage)
                store.synchronize()
            }
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

struct ImagePopupView: View {
    let image: Image?
    let title: String
    @Binding var selectedItem: PhotosPickerItem?
    let changePhotoAction: (PhotosPickerItem?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Image Display
                if let image = image {
                    image
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                } else {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    
                    Image(systemName: "photo.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                }
                
                // Change Photo Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedItem,
                                   matching: .images) {
                            Image(systemName: "camera.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .onChange(of: selectedItem) { oldValue, newValue in
                            changePhotoAction(newValue)
                            dismiss()
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

extension UIImage {
    func compressedForStorage() -> Data? {
        // Start with high compression
        var compression: CGFloat = 0.3
        var imageData = self.jpegData(compressionQuality: compression)
        
        // Maximum size in bytes (3MB to be safe)
        let maxBytes = 3 * 1024 * 1024
        
        // Reduce image quality until it's under maxBytes
        while imageData?.count ?? 0 > maxBytes && compression > 0.1 {
            compression -= 0.1
            imageData = self.jpegData(compressionQuality: compression)
        }
        
        // If still too large, resize the image
        if imageData?.count ?? 0 > maxBytes {
            let scale = sqrt(Double(maxBytes) / Double(imageData?.count ?? 1))
            let newSize = CGSize(
                width: Double(size.width) * scale,
                height: Double(size.height) * scale
            )
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
            draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return resizedImage?.jpegData(compressionQuality: compression)
        }
        
        return imageData
    }
}

struct ProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    @Binding var profileImage: Image?
    @Binding var backgroundImage: Image?
    @Binding var selectedProfileItem: PhotosPickerItem?
    @Binding var selectedBackgroundItem: PhotosPickerItem?
    let onProfilePhotoChange: (PhotosPickerItem?) -> Void
    let onBackgroundPhotoChange: (PhotosPickerItem?) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Profile Picture") {
                    HStack {
                        if let profileImage = profileImage {
                            profileImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "person.fill")
                                .resizable()
                                .padding(20)
                                .frame(width: 100, height: 100)
                                .background(Color.gray.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Spacer()
                        
                        PhotosPicker(selection: $selectedProfileItem,
                                   matching: .images) {
                            Text("Change")
                                .foregroundColor(.blue)
                        }
                        .onChange(of: selectedProfileItem) { oldValue, newValue in
                            onProfilePhotoChange(newValue)
                        }
                    }
                }
                
                Section("Name") {
                    TextField("Your Name", text: $name)
                }
                
                Section("Background Picture") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let backgroundImage = backgroundImage {
                            backgroundImage
                                .resizable()
                                .scaledToFill()
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        PhotosPicker(selection: $selectedBackgroundItem,
                                   matching: .images) {
                            Text("Change Background")
                                .foregroundColor(.blue)
                        }
                        .onChange(of: selectedBackgroundItem) { oldValue, newValue in
                            onBackgroundPhotoChange(newValue)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
