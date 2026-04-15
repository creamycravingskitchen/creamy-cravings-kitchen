import Foundation

struct KitchenFinanceStore {
    var connectedInstitution: String
    var receipts: [ReceiptRecord]
    var transactions: [BankTransaction]

    private let currentYear = Calendar.current.component(.year, from: .now)

    var salesTransactions: [BankTransaction] {
        transactions
            .filter { $0.direction == .credit }
            .sorted { $0.date > $1.date }
    }

    var expenseTransactions: [BankTransaction] {
        transactions
            .filter { $0.direction == .debit }
            .sorted { $0.date > $1.date }
    }

    var salesByMonth: [MonthlyTransactionGroup] {
        groupedTransactions(from: salesTransactions)
    }

    var expensesByMonth: [MonthlyTransactionGroup] {
        groupedTransactions(from: expenseTransactions)
    }

    var currentYearSalesByMonth: [MonthlyTransactionGroup] {
        salesByMonth.filter { $0.year == currentYear }
    }

    var currentYearExpensesByMonth: [MonthlyTransactionGroup] {
        expensesByMonth.filter { $0.year == currentYear }
    }

    var previousYearSalesSnapshot: YearlyTransactionSnapshot {
        yearlySnapshot(from: salesByMonth, year: currentYear - 1)
    }

    var previousYearExpensesSnapshot: YearlyTransactionSnapshot {
        yearlySnapshot(from: expensesByMonth, year: currentYear - 1)
    }

    var currentYearSalesTotal: Double {
        currentYearSalesByMonth.reduce(0) { $0 + $1.absoluteTotal }
    }

    var currentYearExpensesTotal: Double {
        currentYearExpensesByMonth.reduce(0) { $0 + $1.absoluteTotal }
    }

    var totalSales: Double {
        salesTransactions.reduce(0) { $0 + abs($1.amount) }
    }

    var totalExpenses: Double {
        expenseTransactions.reduce(0) { $0 + $1.amount }
    }

    var currentMonthSalesTotal: Double {
        salesByMonth.first?.absoluteTotal ?? 0
    }

    var currentMonthExpenseTotal: Double {
        expensesByMonth.first?.absoluteTotal ?? 0
    }

    mutating func addImportedReceipt(name: String, source: ReceiptSource) {
        receipts.insert(
            ReceiptRecord(name: name, importedAt: .now, source: source),
            at: 0
        )
    }

    mutating func replaceTransactions(with transactions: [BankTransaction], institutionName: String?) {
        self.transactions = transactions.sorted { $0.date > $1.date }
        if let institutionName, !institutionName.isEmpty {
            connectedInstitution = institutionName
        }
    }

    func currency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    private func groupedTransactions(from transactions: [BankTransaction]) -> [MonthlyTransactionGroup] {
        let grouped = Dictionary(grouping: transactions) { transaction in
            Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: transaction.date)) ?? transaction.date
        }

        return grouped
            .map { key, value in
                MonthlyTransactionGroup(
                    month: key,
                    transactions: value.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.month > $1.month }
    }

    private func yearlySnapshot(from groups: [MonthlyTransactionGroup], year: Int) -> YearlyTransactionSnapshot {
        YearlyTransactionSnapshot(
            year: year,
            months: groups.filter { $0.year == year }.sorted { $0.month > $1.month }
        )
    }
}

extension KitchenFinanceStore {
    static let sample = KitchenFinanceStore(
        connectedInstitution: "Bank of America",
        receipts: [
            ReceiptRecord(name: "Produce Supplier Invoice.jpg", importedAt: .now.addingTimeInterval(-7_200), source: .fileUpload),
            ReceiptRecord(name: "Dairy Run Receipt.pdf", importedAt: .now.addingTimeInterval(-86_400), source: .camera),
            ReceiptRecord(name: "Packaging Order.png", importedAt: .now.addingTimeInterval(-172_800), source: .photoLibrary)
        ],
        transactions: [
            BankTransaction(title: "Holiday Dessert Box", date: sampleDate(year: 2025, month: 12, day: 19), amount: -1780.00),
            BankTransaction(title: "Winter Market Sales", date: sampleDate(year: 2025, month: 11, day: 9), amount: -1325.40),
            BankTransaction(title: "Cream & Milk Supply", date: sampleDate(year: 2025, month: 11, day: 5), amount: 284.60),
            BankTransaction(title: "Event Catering Deposit", date: sampleDate(year: 2025, month: 10, day: 24), amount: -940.00),
            BankTransaction(title: "Packaging Materials", date: sampleDate(year: 2025, month: 10, day: 16), amount: 147.18),
            BankTransaction(title: "Summer Gelato Sales", date: sampleDate(year: 2025, month: 7, day: 14), amount: -2210.35),
            BankTransaction(title: "Kitchen Equipment Repair", date: sampleDate(year: 2025, month: 7, day: 10), amount: 398.00),
            BankTransaction(title: "Catering Payout", date: sampleDate(year: 2026, month: 4, day: 11), amount: -1860.00),
            BankTransaction(title: "Weekend Dessert Sales", date: sampleDate(year: 2026, month: 4, day: 8), amount: -1245.55),
            BankTransaction(title: "Restaurant Depot", date: sampleDate(year: 2026, month: 4, day: 7), amount: 436.18),
            BankTransaction(title: "Beverage Distributor", date: sampleDate(year: 2026, month: 4, day: 5), amount: 212.40),
            BankTransaction(title: "Private Order Deposit", date: sampleDate(year: 2026, month: 3, day: 28), amount: -980.00),
            BankTransaction(title: "Flour & Sugar Supply", date: sampleDate(year: 2026, month: 3, day: 22), amount: 318.75),
            BankTransaction(title: "Monthly Bakery Sales", date: sampleDate(year: 2026, month: 3, day: 16), amount: -2430.20),
            BankTransaction(title: "Kitchen Utilities", date: sampleDate(year: 2026, month: 3, day: 10), amount: 189.32)
        ]
    )

    private static func sampleDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
}
