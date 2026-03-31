import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var leaderboard = LeaderboardManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text("LEADERBOARD")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(GameColors.neonYellow)
                        .shadow(color: GameColors.neonYellow, radius: 8)
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .opacity(0)
                }
                .padding(.horizontal)

                if leaderboard.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(GameColors.neonCyan)
                    Spacer()
                } else if leaderboard.entries.isEmpty {
                    Spacer()
                    Text("No entries yet")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("Win a game to get on the board!")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.6))
                    Spacer()
                } else {
                    HStack {
                        Text("#")
                            .frame(width: 30, alignment: .center)
                        Text("PLAYER")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("WINS")
                            .frame(width: 60, alignment: .trailing)
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.horizontal)

                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(leaderboard.entries.enumerated()), id: \.element.id) { index, entry in
                                let isCurrentPlayer = entry.id == leaderboard.playerID
                                HStack {
                                    Text("\(index + 1)")
                                        .frame(width: 30, alignment: .center)
                                        .foregroundColor(rankColor(index))
                                    Text(entry.displayName)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .foregroundColor(isCurrentPlayer ? GameColors.neonGreen : .white)
                                    Text("\(entry.totalWins)")
                                        .frame(width: 60, alignment: .trailing)
                                        .foregroundColor(GameColors.neonCyan)
                                }
                                .font(.system(size: 14, weight: isCurrentPlayer ? .bold : .medium, design: .monospaced))
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                .background(
                                    isCurrentPlayer
                                        ? GameColors.neonGreen.opacity(0.1)
                                        : Color.white.opacity(0.03)
                                )
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isCurrentPlayer ? GameColors.neonGreen.opacity(0.4) : .clear, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top, 20)
        }
        .task {
            await leaderboard.fetchLeaderboard()
        }
    }

    func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return GameColors.neonYellow
        case 1: return .white
        case 2: return GameColors.neonOrange
        default: return .gray
        }
    }
}
