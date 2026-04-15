import Foundation

enum KitchenTab: Hashable {
    case uploadReceipt
    case transactions
    case sales
    case expenses
}

enum ReceiptSource: String, Hashable {
    case fileUpload
    case camera
    case photoLibrary

    var label: String {
        switch self {
        case .fileUpload:
            return "File Upload"
        case .camera:
            return "Camera"
        case .photoLibrary:
            return "Photo Library"
        }
    }
}

struct ReceiptRecord: Identifiable, Hashable {
    let id: UUID
    var name: String
    var importedAt: Date
    var source: ReceiptSource

    init(id: UUID = UUID(), name: String, importedAt: Date, source: ReceiptSource) {
        self.id = id
        self.name = name
        self.importedAt = importedAt
        self.source = source
    }
}

enum TransactionDirection: Hashable {
    case credit
    case debit
}

struct BankTransaction: Identifiable, Hashable {
    let id: UUID
    var title: String
    var date: Date
    var amount: Double

    init(id: UUID = UUID(), title: String, date: Date, amount: Double) {
        self.id = id
        self.title = title
        self.date = date
        self.amount = amount
    }

    var direction: TransactionDirection {
        amount < 0 ? .credit : .debit
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let absolute = abs(amount)
        let value = formatter.string(from: NSNumber(value: absolute)) ?? "$0.00"
        return direction == .credit ? "+\(value)" : "-\(value)"
    }
}

struct MonthlyTransactionGroup: Identifiable, Hashable {
    let id = UUID()
    let month: Date
    let transactions: [BankTransaction]

    var total: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }

    var absoluteTotal: Double {
        abs(total)
    }

    var monthTitle: String {
        month.formatted(.dateTime.month(.wide).year())
    }

    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: absoluteTotal)) ?? "$0.00"
    }

    var year: Int {
        Calendar.current.component(.year, from: month)
    }
}

struct YearlyTransactionSnapshot: Identifiable, Hashable {
    let year: Int
    let months: [MonthlyTransactionGroup]

    var id: Int { year }

    var total: Double {
        months.reduce(0) { $0 + $1.absoluteTotal }
    }
}

struct PlaidConnectionHealth: Decodable {
    let configured: Bool
    let environment: String
    let products: [String]
    let redirectUriConfigured: Bool
    let webhookURLConfigured: Bool
    let storedItems: Int

    enum CodingKeys: String, CodingKey {
        case configured
        case environment
        case products
        case redirectUriConfigured = "redirect_uri_configured"
        case webhookURLConfigured = "webhook_url_configured"
        case storedItems = "stored_items"
    }
}

struct PlaidSyncPayload: Decodable {
    let institutionName: String?
    let itemId: String?
    let transactions: [PlaidTransactionPayload]
}

struct PlaidTransactionPayload: Decodable {
    let transactionId: String
    let name: String
    let date: String
    let amount: Double

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case name
        case date
        case amount
    }

    var bankTransaction: BankTransaction {
        let formatter = ISO8601DateFormatter()
        let parsedDate = formatter.date(from: date) ?? DateFormatter.plaidDateFormatter.date(from: date) ?? .now
        return BankTransaction(title: name, date: parsedDate, amount: amount)
    }
}

struct PlaidStoredItemPayload: Decodable, Identifiable, Hashable {
    let itemId: String
    let institutionName: String?
    let createdAt: String?
    let lastCursor: String?

    var id: String { itemId }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case institutionName = "institution_name"
        case createdAt = "created_at"
        case lastCursor = "last_cursor"
    }
}

struct PlaidStoredItemsResponse: Decodable {
    let items: [PlaidStoredItemPayload]
}

private extension DateFormatter {
    static let plaidDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
