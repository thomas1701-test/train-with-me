import SwiftUI

struct GamificationView: View {
    var viewModel: AppViewModel

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            ScrollView {
                VStack(spacing: 20) {
                    levelCard
                    achievementsSection
                }.padding()
            }
        }
        .navigationTitle("Fortschritt")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var levelCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LEVEL \(viewModel.training.currentLevelIndex + 1)")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.4))
                        .kerning(1.5)
                    Text(viewModel.training.levelTitle)
                        .font(.title.bold())
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(viewModel.training.totalXP)")
                        .font(.title2.bold())
                        .foregroundColor(viewModel.currentTheme.accentColor)
                    Text("XP gesamt")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [viewModel.currentTheme.accentColor, viewModel.currentTheme.accentColor.opacity(0.6)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(geo.size.width * viewModel.training.levelProgress, 0), height: 10)
                        .animation(.easeOut(duration: 0.5), value: viewModel.training.levelProgress)
                }
            }.frame(height: 10)

            HStack {
                if viewModel.training.xpToNextLevel > 0 {
                    Text("Noch \(viewModel.training.xpToNextLevel) XP bis Level \(viewModel.training.currentLevelIndex + 2)")
                        .font(.caption).foregroundColor(.white.opacity(0.4))
                } else {
                    Text("Maximales Level erreicht! 🏆")
                        .font(.caption.bold()).foregroundColor(.yellow)
                }
                Spacer()
                Text("\(Int(viewModel.training.levelProgress * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(viewModel.currentTheme.accentColor)
            }

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            HStack(spacing: 0) {
                statColumn(label: "Gesamtvolumen", value: "\(Int(viewModel.training.totalVolume / 1000))t")
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 32)
                statColumn(label: "Trainingstage", value: "\(viewModel.training.totalTrainingDays)")
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 32)
                statColumn(label: "Längster Streak", value: "\(viewModel.training.longestStreak)d")
            }
        }
        .padding(20)
        .glassStyle()
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold()).foregroundColor(.white)
            Text(label).font(.caption2).foregroundColor(.white.opacity(0.4))
        }.frame(maxWidth: .infinity)
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            let all = viewModel.training.achievements
            let unlockedCount = all.filter { $0.isUnlocked }.count

            HStack {
                Text("Achievements").font(.title3.bold()).foregroundColor(.white)
                Spacer()
                Text("\(unlockedCount) / \(all.count)")
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.4))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.training.achievements) { achievement in
                    AchievementCard(achievement: achievement, accentColor: viewModel.currentTheme.accentColor)
                }
            }
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    let accentColor: Color

    var body: some View {
        VStack(spacing: 10) {
            Text(achievement.emoji)
                .font(.system(size: 36))
                .opacity(achievement.isUnlocked ? 1.0 : 0.2)
                .grayscale(achievement.isUnlocked ? 0 : 1)
                .scaleEffect(achievement.isUnlocked ? 1.0 : 0.9)
            Text(achievement.title)
                .font(.caption.bold())
                .foregroundColor(achievement.isUnlocked ? .white : .white.opacity(0.3))
                .multilineTextAlignment(.center)
            Text(achievement.subtitle)
                .font(.caption2)
                .foregroundColor(achievement.isUnlocked ? accentColor : .white.opacity(0.2))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16).padding(.horizontal, 10)
        .background(achievement.isUnlocked ? accentColor.opacity(0.1) : Color.white.opacity(0.03))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(achievement.isUnlocked ? accentColor.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

struct AchievementUnlockedBanner: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 14) {
            Text(achievement.emoji).font(.title)
            VStack(alignment: .leading, spacing: 3) {
                Text("Achievement freigeschaltet!")
                    .font(.caption.bold()).foregroundColor(.yellow)
                Text(achievement.title)
                    .font(.subheadline.bold()).foregroundColor(.white)
                Text(achievement.subtitle)
                    .font(.caption).foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yellow.opacity(0.4), lineWidth: 1))
        .padding(.horizontal).padding(.top, 8)
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
    }
}
