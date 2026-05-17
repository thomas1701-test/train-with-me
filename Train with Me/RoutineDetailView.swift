import SwiftUI

struct RoutineDetailView: View {
    var viewModel: AppViewModel
    let routine: Routine

    var routineMachines: [Machine] { viewModel.training.machines.filter { routine.machineIDs.contains($0.id) } }

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 20) {
                    ForEach(routineMachines) { machine in
                        NavigationLink(destination: TrainingView(viewModel: viewModel, machine: machine)) {
                            VStack {
                                CachedAsyncImage(fileName: machine.imageFileName) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 150, height: 150)
                                        .clipped()
                                        .cornerRadius(15)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 150, height: 150)
                                        .cornerRadius(15)
                                }
                                Text(machine.name)
                                    .font(.caption).bold().foregroundColor(.white).padding(5)
                            }.glassStyle()
                        }
                    }
                }.padding()
            }
        }.navigationTitle(routine.name)
    }
}
