import Foundation
import Observation

/// Local persistence (JSON files in Application Support): business profile, logo, history, numbering and usage.
@MainActor
@Observable
final class DocumentStore {
    static let freeDocumentsPerMonth = 3

    private(set) var profile: BusinessProfile?
    private(set) var logoData: Data?
    private(set) var documents: [SavedDocument] = []
    private(set) var counters = Counters()

    struct Counters: Codable, Equatable {
        /// Last number used per "PREFIX-YEAR" key.
        var lastNumbers: [String: Int] = [:]
        /// Documents created per "yyyy-MM" month.
        var monthlyUsage: [String: Int] = [:]
    }

    private let directory: URL
    private let calendar = Calendar(identifier: .gregorian)

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PapiersPro", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Files

    private var profileURL: URL { directory.appendingPathComponent("profile.json") }
    private var documentsURL: URL { directory.appendingPathComponent("documents.json") }
    private var countersURL: URL { directory.appendingPathComponent("counters.json") }
    private var logoURL: URL { directory.appendingPathComponent("logo.png") }

    private func load() {
        let decoder = JSONDecoder()
        if let data = try? Data(contentsOf: profileURL) {
            profile = try? decoder.decode(BusinessProfile.self, from: data)
        }
        if let data = try? Data(contentsOf: documentsURL),
           let docs = try? decoder.decode([SavedDocument].self, from: data) {
            documents = docs.sorted { $0.updatedAt > $1.updatedAt }
        }
        if let data = try? Data(contentsOf: countersURL),
           let value = try? decoder.decode(Counters.self, from: data) {
            counters = value
        }
        logoData = try? Data(contentsOf: logoURL)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        #if os(iOS)
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try? data.write(to: url, options: .atomic)
        #endif
    }

    // MARK: - Profile

    func saveProfile(_ newProfile: BusinessProfile) {
        var p = newProfile
        p.hasLogo = logoData != nil
        profile = p
        write(p, to: profileURL)
    }

    func setLogo(_ data: Data?) {
        logoData = data
        if let data {
            try? data.write(to: logoURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: logoURL)
        }
        if let profile { saveProfile(profile) }
    }

    func resetAll() {
        profile = nil
        logoData = nil
        documents = []
        counters = Counters()
        for url in [profileURL, documentsURL, countersURL, logoURL] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Numbering

    private func numberKey(_ type: DocumentType, date: Date) -> String {
        "\(type.numberPrefix)-\(calendar.component(.year, from: date))"
    }

    /// Highest sequence already used, from counters and existing documents (in case counters were lost).
    private func lastSequence(for type: DocumentType, date: Date) -> Int {
        let key = numberKey(type, date: date)
        let fromCounters = counters.lastNumbers[key] ?? 0
        let fromDocuments = documents
            .map(\.data.number)
            .filter { $0.hasPrefix(key + "-") }
            .compactMap { Int($0.dropFirst(key.count + 1)) }
            .max() ?? 0
        return max(fromCounters, fromDocuments)
    }

    /// Number the next document of this type will get (not reserved).
    func nextNumber(for type: DocumentType, date: Date = .now) -> String {
        let key = numberKey(type, date: date)
        return Self.format(key: key, sequence: lastSequence(for: type, date: date) + 1)
    }

    private static func format(key: String, sequence: Int) -> String {
        let digits = String(sequence)
        return key + "-" + String(repeating: "0", count: max(0, 4 - digits.count)) + digits
    }

    // MARK: - Usage

    private func monthKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    func documentsCreated(inMonthOf date: Date = .now) -> Int {
        counters.monthlyUsage[monthKey(date)] ?? 0
    }

    func remainingFreeDocuments(now: Date = .now) -> Int {
        max(0, Self.freeDocumentsPerMonth - documentsCreated(inMonthOf: now))
    }

    func canCreateDocument(isPremium: Bool, now: Date = .now) -> Bool {
        isPremium || remainingFreeDocuments(now: now) > 0
    }

    // MARK: - Documents

    func document(id: UUID) -> SavedDocument? {
        documents.first { $0.id == id }
    }

    /// Saves a document. New documents receive the next number and count toward the monthly quota.
    @discardableResult
    func save(_ data: DocumentData, id: UUID?, now: Date = .now) -> SavedDocument {
        if let id, let index = documents.firstIndex(where: { $0.id == id }) {
            var doc = documents[index]
            doc.data = data
            if doc.data.number.isEmpty {
                doc.data.number = reserveNumber(for: data.type, date: data.date)
            }
            doc.updatedAt = now
            documents.remove(at: index)
            documents.insert(doc, at: 0)
            persistDocuments()
            return doc
        }
        var newData = data
        if newData.number.isEmpty {
            newData.number = reserveNumber(for: data.type, date: data.date)
        }
        let doc = SavedDocument(id: id ?? UUID(), data: newData, createdAt: now, updatedAt: now)
        documents.insert(doc, at: 0)
        counters.monthlyUsage[monthKey(now), default: 0] += 1
        persistDocuments()
        write(counters, to: countersURL)
        return doc
    }

    private func reserveNumber(for type: DocumentType, date: Date) -> String {
        let key = numberKey(type, date: date)
        let next = lastSequence(for: type, date: date) + 1
        counters.lastNumbers[key] = next
        write(counters, to: countersURL)
        return Self.format(key: key, sequence: next)
    }

    func delete(id: UUID) {
        documents.removeAll { $0.id == id }
        persistDocuments()
    }

    private func persistDocuments() {
        write(documents, to: documentsURL)
    }

    /// Recently used clients, most recent first, without duplicates.
    var recentClients: [ClientInfo] {
        var seen = Set<String>()
        var result: [ClientInfo] = []
        for doc in documents where !doc.data.client.isEmpty {
            let key = doc.data.client.name.lowercased()
            if seen.insert(key).inserted {
                result.append(doc.data.client)
            }
            if result.count == 20 { break }
        }
        return result
    }
}
