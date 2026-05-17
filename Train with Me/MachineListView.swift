import SwiftUI

struct MachineListView: View {
    var viewModel: AppViewModel
    let muscle: String

    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 20) {
                    Button(action: { showingImagePicker = true }) {
                        VStack {
                            Image(systemName: "camera.fill").font(.largeTitle).foregroundColor(.white)
                            Text("Neues Gerät").foregroundColor(.white)
                        }.frame(height: 150).frame(maxWidth: .infinity).glassStyle()
                    }

                    ForEach(viewModel.training.machines.filter { $0.muscleGroup == muscle }) { machine in
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
                        .contextMenu {
                            Button(role: .destructive) { viewModel.training.deleteMachine(machine: machine) } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }.padding()
            }
        }
        .navigationTitle(muscle)
        .sheet(isPresented: $showingImagePicker) { ImagePicker(image: $inputImage) }
        .onChange(of: inputImage) { _, newImage in
            if let img = newImage { viewModel.training.addMachine(muscle: muscle, image: img) }
        }
    }
}
