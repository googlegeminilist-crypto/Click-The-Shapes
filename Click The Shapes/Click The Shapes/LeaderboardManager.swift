import Foundation
import FirebaseFirestore

struct LeaderboardEntry: Identifiable, Codable {
    var id: String
    var displayName: String
    var totalWins: Int
    var lastUpdated: Date
}

class LeaderboardManager: ObservableObject {
    static let shared = LeaderboardManager()

    @Published var entries: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var playerName: String {
        didSet {
            UserDefaults.standard.set(playerName, forKey: "playerDisplayName")
        }
    }

    private let db = Firestore.firestore()
    private let collectionName = "leaderboard"

    var playerID: String {
        if let id = UserDefaults.standard.string(forKey: "playerID") {
            return id
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: "playerID")
        return newID
    }

    var hasSetName: Bool {
        !playerName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init() {
        self.playerName = UserDefaults.standard.string(forKey: "playerDisplayName") ?? ""
    }

    func recordWin(totalWins: Int) {
        guard hasSetName else { return }

        let data: [String: Any] = [
            "displayName": playerName,
            "totalWins": totalWins,
            "lastUpdated": FieldValue.serverTimestamp()
        ]

        db.collection(collectionName)
            .document(playerID)
            .setData(data, merge: true)
    }

    @MainActor
    func fetchLeaderboard() async {
        isLoading = true

        do {
            let snapshot = try await db.collection(collectionName)
                .order(by: "totalWins", descending: true)
                .limit(to: 50)
                .getDocuments()

            entries = snapshot.documents.compactMap { doc -> LeaderboardEntry? in
                let data = doc.data()
                guard let name = data["displayName"] as? String,
                      let wins = data["totalWins"] as? Int else { return nil }
                let timestamp = (data["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
                return LeaderboardEntry(
                    id: doc.documentID,
                    displayName: name,
                    totalWins: wins,
                    lastUpdated: timestamp
                )
            }
            isLoading = false
        } catch {
            debugLog("Leaderboard fetch failed: \(error)")
            isLoading = false
        }
    }
}
