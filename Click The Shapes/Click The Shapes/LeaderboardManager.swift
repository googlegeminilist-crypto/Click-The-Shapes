import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

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

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
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
        #if canImport(FirebaseFirestore)
        let data: [String: Any] = [
            "displayName": playerName,
            "totalWins": totalWins,
            "lastUpdated": FieldValue.serverTimestamp()
        ]
        db.collection(collectionName)
            .document(playerID)
            .setData(data, merge: true)
        #endif
    }

    @MainActor
    func fetchLeaderboard() async {
        isLoading = true
        #if canImport(FirebaseFirestore)
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
        #else
        isLoading = false
        #endif
    }
}
