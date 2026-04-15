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

/// Very basic client-side profanity filter for display names. Catches common
/// variants via normalization (leetspeak, repeated chars, diacritics) but is
/// not exhaustive — determined users will still find ways through. Pair with
/// a server-side Cloud Function review if you need stronger guarantees.
enum DisplayNameFilter {
    /// Substrings that should reject the name if present after normalization.
    /// Kept compact: common English-language slurs, sexual terms, and vulgarities.
    /// Using substring (not word-boundary) match keeps the implementation simple
    /// at the cost of some false positives (classic Scunthorpe problem).
    private static let blocklist: Set<String> = [
        // Sexual / explicit
        "fuck", "shit", "cock", "dick", "pussy", "cunt", "bitch", "bastard",
        "asshole", "arsehole", "wanker", "twat", "boob", "tit", "nipple",
        "penis", "vagina", "sex", "porn", "nude", "naked", "orgasm", "masturbat",
        "jizz", "cum", "horny", "slut", "whore", "hooker", "milf", "dildo",
        "anal", "rape", "incest", "pedo", "pedophile", "paedophile", "loli",
        // Racial / ethnic slurs (abbreviated list — add more if required)
        "nigger", "nigga", "chink", "spic", "kike", "gook", "wetback", "paki",
        "tranny", "faggot", "fag", "dyke", "homo",
        // Violence / self-harm
        "kill", "murder", "suicide", "nazi", "hitler", "terrorist",
        // Drugs
        "cocaine", "heroin", "meth",
        // Generic vulgar
        "piss", "crap", "damn", "hell"
    ]

    /// Returns true if the name should be rejected.
    static func isLikelyProfane(_ name: String) -> Bool {
        let normalized = normalize(name)
        if normalized.isEmpty { return false }
        return blocklist.contains { normalized.contains($0) }
    }

    /// Normalize: lowercase, strip diacritics, remove non-alphanumerics,
    /// collapse runs of the same letter, map common leetspeak to letters.
    private static func normalize(_ s: String) -> String {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        var out = ""
        var lastChar: Character?
        for ch in folded {
            let mapped: Character?
            switch ch {
            case "0": mapped = "o"
            case "1", "!", "|": mapped = "i"
            case "3": mapped = "e"
            case "4", "@": mapped = "a"
            case "5", "$": mapped = "s"
            case "7": mapped = "t"
            case "8": mapped = "b"
            case "9": mapped = "g"
            default:
                mapped = ch.isLetter ? ch : nil
            }
            guard let m = mapped else { continue }
            if m == lastChar { continue } // collapse repeats: "fuuuck" -> "fuck"
            out.append(m)
            lastChar = m
        }
        return out
    }
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
