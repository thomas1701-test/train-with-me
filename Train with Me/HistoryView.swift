import SwiftUI

struct HistoryView: View {
    var viewModel: AppViewModel
    @Environment(\.presentationMode) var presentationMode

    let daysToDisplay = 28
    let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            ScrollView {
                VStack(alignment: .leading) {
                    Text("Aktivität").font(.title).bold().foregroundColor(.white).padding()
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(0..<daysToDisplay, id: \.self) { index in
                            let date = Calendar.current.date(byAdding: .day, value: -((daysToDisplay - 1) - index), to: Date())!
                            DayCell(date: date, volume: volumeForDate(date))
                        }
                    }.padding().glassStyle().padding()
                }
            }
        }
    }

    func volumeForDate(_ date: Date) -> Double {
        viewModel.training.machines.reduce(0) { total, machine in
            total + machine.sets.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.volume }
        }
    }
}
