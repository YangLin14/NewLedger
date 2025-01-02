import Foundation

struct Profile: Codable {
    var name: String
    var imageData: Data?
    var backgroundImageData: Data?
    var budgetSettings: BudgetSettings
    
    init(name: String = "User", imageData: Data? = nil) {
        self.name = name
        self.imageData = imageData
        self.budgetSettings = BudgetSettings()
    }
}

struct BudgetSettings: Codable {
    var dailyLimit: Double?
    var monthlyLimit: Double?
    var yearlyLimit: Double?
    var period: BudgetPeriod
    
    init(dailyLimit: Double? = nil, monthlyLimit: Double? = nil, yearlyLimit: Double? = nil, period: BudgetPeriod = .monthly) {
        self.dailyLimit = dailyLimit
        self.monthlyLimit = monthlyLimit
        self.yearlyLimit = yearlyLimit
        self.period = period
    }
}

enum BudgetPeriod: String, Codable, CaseIterable {
    case daily = "Daily"
    case monthly = "Monthly"
    case yearly = "Yearly"
}
