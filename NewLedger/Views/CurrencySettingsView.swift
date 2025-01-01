import SwiftUI

// MARK: - Currency Models
struct ExchangeRateResponse: Codable {
    let result: String?
    let documentation: String?
    let terms_of_use: String?
    let time_last_update_unix: TimeInterval?
    let time_next_update_unix: TimeInterval?
    let base_code: String?
    let conversion_rates: [String: Double]
    
    enum CodingKeys: String, CodingKey {
        case result
        case documentation
        case terms_of_use
        case time_last_update_unix
        case time_next_update_unix
        case base_code
        case conversion_rates
    }
}

enum Currency: String, CaseIterable {
    case USD = "USD"
    case TWD = "TWD"
    case EUR = "EUR"
    case JPY = "JPY"
    case GBP = "GBP"
    
    var symbol: String {
        switch self {
        case .USD: return "$"
        case .TWD: return "NT$"
        case .EUR: return "€"
        case .JPY: return "¥"
        case .GBP: return "£"
        }
    }
    
    var fullName: String {
        switch self {
        case .USD: return "US Dollar"
        case .TWD: return "New Taiwan Dollar"
        case .EUR: return "Euro"
        case .JPY: return "Japanese Yen"
        case .GBP: return "British Pound"
        }
    }
    
    var fallbackRate: Double {
        switch self {
        case .USD: return 1.0
        case .TWD: return 31.0
        case .EUR: return 0.91
        case .JPY: return 148.0
        case .GBP: return 0.79
        }
    }
}

// Add currency to Profile model
extension Profile {
    var currency: Currency {
        get {
            if let storedCurrency = UserDefaults.standard.string(forKey: "selectedCurrency"),
               let currency = Currency(rawValue: storedCurrency) {
                return currency
            }
            return .USD
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "selectedCurrency")
        }
    }
}

// Custom error enum to provide more specific error cases
enum CurrencyServiceError: LocalizedError {
    case invalidResponse
    case decodingError(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from the server"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

@MainActor
class CurrencyService: ObservableObject, @unchecked Sendable {
    static let shared = CurrencyService()
    @Published var lastUpdated: Date?
    @Published var rates: [String: Double] = [:]
    
    private let apiKey = "3407a8a179f3568855977454"
    private let baseURL = "https://v6.exchangerate-api.com/v6"
    
    func fetchLatestRates() async throws {
        let url = URL(string: "\(baseURL)/\(apiKey)/latest/USD")!
        
        do {
            // Add debugging print
            print("Fetching rates from: \(url.absoluteString)")
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
//            // Print raw response for debugging
//            if let responseString = String(data: data, encoding: .utf8) {
//                print("Raw API Response: \(responseString)")
//            }
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CurrencyServiceError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw CurrencyServiceError.networkError("HTTP Status: \(httpResponse.statusCode)")
            }
            
            do {
                let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
                rates = response.conversion_rates
                lastUpdated = Date()
            } catch {
                print("Decoding error: \(error)")
                throw CurrencyServiceError.decodingError(error.localizedDescription)
            }
        } catch {
            if let currencyError = error as? CurrencyServiceError {
                throw currencyError
            } else {
                throw CurrencyServiceError.networkError(error.localizedDescription)
            }
        }
    }
    
    func convert(amount: Double, from: Currency, to: Currency) -> Double {
        guard let fromRate = rates[from.rawValue],
              let toRate = rates[to.rawValue] else {
            // Fallback to hardcoded rates if API fails
            return amount * (to.fallbackRate / from.fallbackRate)
        }
        
        // Convert to USD first, then to target currency
        let amountInUSD = amount / fromRate
        return amountInUSD * toRate
    }
}

// MARK: - Currency Row View
struct CurrencyRowView: View {
    let currency: Currency
    let isSelected: Bool
    let currentRate: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(currency.symbol)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                Text(currency.rawValue)
                    .fontWeight(.medium)
                Text("- \(currency.fullName)")
                    .foregroundColor(.secondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            
            Text(currentRate)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Refresh Rates Section
struct RefreshRatesSection: View {
    let lastUpdated: Date?
    let isLoading: Bool
    let onRefresh: () -> Void
    
    var body: some View {
        if let lastUpdated = lastUpdated {
            Section(footer: Text("Rates last updated: \(lastUpdated.formatted())")) {
                Button(action: onRefresh) {
                    HStack {
                        Text("Refresh Rates")
                        if isLoading {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isLoading)
            }
        }
    }
}

// MARK: - Apply Changes Section
struct ApplyChangesSection: View {
    let isLoading: Bool
    let onApply: () -> Void
    
    var body: some View {
        Section(
            footer: Text("Changing currency will convert all existing amounts using current exchange rates.")
        ) {
            Button("Apply Changes", action: onApply)
                .disabled(isLoading)
        }
    }
}

// MARK: - Main View
struct CurrencySettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: ExpenseStore
    @StateObject private var currencyService = CurrencyService.shared
    @State private var selectedCurrency: Currency
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(currentCurrency: Currency) {
        _selectedCurrency = State(initialValue: currentCurrency)
    }
    
    private func formatRate(_ rate: Double) -> String {
        return String(format: "%.4f", rate)
    }
    
    private func getCurrentRate(for currency: Currency) -> String {
        if let rate = currencyService.rates[currency.rawValue] {
            return "1 USD = \(formatRate(rate)) \(currency.rawValue)"
        } else {
            return "1 USD = \(formatRate(currency.fallbackRate)) \(currency.rawValue) (fallback)"
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Currency Selection Section
                Section(header: Text("Select Currency")) {
                    ForEach(Currency.allCases, id: \.self) { currency in
                        CurrencyRowView(
                            currency: currency,
                            isSelected: currency == selectedCurrency,
                            currentRate: getCurrentRate(for: currency)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCurrency = currency
                        }
                    }
                }
                
                // Refresh Rates Section
                RefreshRatesSection(
                    lastUpdated: currencyService.lastUpdated,
                    isLoading: isLoading
                ) {
                    Task {
                        await refreshRates()
                    }
                }
                
                // Apply Changes Section
                ApplyChangesSection(
                    isLoading: isLoading,
                    onApply: convertAmounts
                )
            }
            .navigationTitle("Currency Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await refreshRates()
            }
        }
    }
    
    private func refreshRates() async {
        isLoading = true
        do {
            try await currencyService.fetchLatestRates()
        } catch {
            errorMessage = "Failed to fetch latest rates: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }
    
    private func convertAmounts() {
        guard selectedCurrency != store.profile.currency else {
            dismiss()
            return
        }
        
        // Convert all expenses
        for index in store.expenses.indices {
            store.expenses[index].amount = currencyService.convert(
                amount: store.expenses[index].amount,
                from: store.profile.currency,
                to: selectedCurrency
            )
        }
        
        // Convert budget limits
        if let daily = store.profile.budgetSettings.dailyLimit {
            store.profile.budgetSettings.dailyLimit = currencyService.convert(
                amount: daily,
                from: store.profile.currency,
                to: selectedCurrency
            )
        }
        
        if let monthly = store.profile.budgetSettings.monthlyLimit {
            store.profile.budgetSettings.monthlyLimit = currencyService.convert(
                amount: monthly,
                from: store.profile.currency,
                to: selectedCurrency
            )
        }
        
        if let yearly = store.profile.budgetSettings.yearlyLimit {
            store.profile.budgetSettings.yearlyLimit = currencyService.convert(
                amount: yearly,
                from: store.profile.currency,
                to: selectedCurrency
            )
        }
        
        store.profile.currency = selectedCurrency
        store.synchronize()
        dismiss()
    }
}
