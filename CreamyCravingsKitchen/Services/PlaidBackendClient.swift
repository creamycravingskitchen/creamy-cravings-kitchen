import Foundation

struct PlaidBackendClient {
    let baseURL: URL

    init(baseURL: URL = URL(string: "http://127.0.0.1:8080")!) {
        self.baseURL = baseURL
    }

    func health() async throws -> PlaidConnectionHealth {
        let (data, _) = try await URLSession.shared.data(from: baseURL.appending(path: "health"))
        return try JSONDecoder().decode(PlaidConnectionHealth.self, from: data)
    }

    func linkEntryURL() -> URL {
        baseURL.appending(path: "plaid/link")
    }

    func items() async throws -> [PlaidStoredItemPayload] {
        let (data, response) = try await URLSession.shared.data(from: baseURL.appending(path: "api/plaid/items"))
        try validate(response: response, data: data)
        return try JSONDecoder().decode(PlaidStoredItemsResponse.self, from: data).items
    }

    func loadSandboxTransactions() async throws -> PlaidSyncPayload {
        var request = URLRequest(url: baseURL.appending(path: "api/plaid/sandbox/bootstrap"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [:])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(PlaidSyncPayload.self, from: data)
    }

    func syncTransactions(itemId: String) async throws -> PlaidSyncPayload {
        var request = URLRequest(url: baseURL.appending(path: "api/plaid/transactions/sync"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["item_id": itemId])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(PlaidSyncPayload.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, 200 ..< 300 ~= http.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown Plaid backend error"
            throw PlaidBackendError.server(message)
        }
    }
}

enum PlaidBackendError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case let .server(message):
            return message
        }
    }
}
