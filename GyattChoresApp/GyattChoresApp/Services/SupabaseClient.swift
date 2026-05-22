import Foundation

/// Supabase API client for GyattChores
/// Note: In production, move credentials to a secure configuration
actor SupabaseClient {
    static let shared = SupabaseClient()

    private let baseURL = "https://ukshxdoqgwoxobjdclpx.supabase.co"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVrc2h4ZG9xZ3dveG9iamRjbHB4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MjI2NDEsImV4cCI6MjA4MDI5ODY0MX0.UGNrsfG6goEA0PPWG4x7gxBueA7D5Oe9uWI-iCXIar0"

    private var session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Generic Request Builder

    private func buildRequest(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) -> URLRequest? {
        var components = URLComponents(string: "\(baseURL)/rest/v1\(path)")
        components?.queryItems = queryItems

        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = body

        return request
    }

    // MARK: - Players

    func fetchPlayers() async throws -> [Player] {
        guard let request = buildRequest(
            path: "/players",
            queryItems: [URLQueryItem(name: "order", value: "name")]
        ) else {
            throw SupabaseError.invalidURL
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Player].self, from: data)
    }

    // MARK: - Chores

    func fetchChores() async throws -> [Chore] {
        guard let request = buildRequest(
            path: "/chores",
            queryItems: [
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "name")
            ]
        ) else {
            throw SupabaseError.invalidURL
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Chore].self, from: data)
    }

    // MARK: - Chore Completions

    func fetchPendingCompletions() async throws -> [ChoreCompletion] {
        guard let request = buildRequest(
            path: "/chore_completions",
            queryItems: [
                URLQueryItem(name: "status", value: "eq.pending"),
                URLQueryItem(name: "order", value: "completed_at.desc"),
                URLQueryItem(name: "select", value: "*,players(name),chores(name,icon)")
            ]
        ) else {
            throw SupabaseError.invalidURL
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ChoreCompletion].self, from: data)
    }

    func claimChore(playerId: UUID, choreId: UUID, value: Int) async throws -> ChoreCompletion {
        let today = ISO8601DateFormatter().string(from: Date())
        let body: [String: Any] = [
            "player_id": playerId.uuidString,
            "chore_id": choreId.uuidString,
            "completed_date": String(today.prefix(10)),
            "completed_at": today,
            "value_awarded": value,
            "status": "pending"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
              let request = buildRequest(path: "/chore_completions", method: "POST", body: jsonData) else {
            throw SupabaseError.invalidURL
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let completions = try decoder.decode([ChoreCompletion].self, from: data)
        guard let completion = completions.first else {
            throw SupabaseError.noData
        }
        return completion
    }

    func approveCompletion(id: UUID) async throws {
        let body: [String: Any] = ["status": "approved"]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
              let request = buildRequest(
                path: "/chore_completions",
                method: "PATCH",
                queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
                body: jsonData
              ) else {
            throw SupabaseError.invalidURL
        }

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func rejectCompletion(id: UUID) async throws {
        let body: [String: Any] = ["status": "rejected"]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
              let request = buildRequest(
                path: "/chore_completions",
                method: "PATCH",
                queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
                body: jsonData
              ) else {
            throw SupabaseError.invalidURL
        }

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Weekly Totals (RPC)

    func fetchWeeklyTotals(weekStart: String) async throws -> [(playerId: UUID, total: Int)] {
        var components = URLComponents(string: "\(baseURL)/rest/v1/rpc/get_weekly_totals")
        components?.queryItems = nil

        guard let url = components?.url else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["week_start": weekStart]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        struct WeeklyTotal: Decodable {
            let player_id: UUID
            let weekly_total: Int
        }

        let results = try JSONDecoder().decode([WeeklyTotal].self, from: data)
        return results.map { ($0.player_id, $0.weekly_total) }
    }

    // MARK: - Helpers

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.httpError(httpResponse.statusCode)
        }
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .noData:
            return "No data returned"
        }
    }
}
