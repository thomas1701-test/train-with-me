import SwiftUI

struct CreateRoutineView: View {
    var viewModel: AppViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var name = ""
    @State private var selectedMachines: Set<Machine> = []

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            VStack {
                Text("Neuer Plan").font(.title).bold().foregroundColor(.white).padding()
                VStack(alignment: .leading) {
                    Text("Name").foregroundColor(.gray)
                    TextField("z.B. Push Day", text: $name)
                        .padding().background(Color.white.opacity(0.1)).cornerRadius(10).foregroundColor(.white)
                }.padding()

                ScrollView {
                    VStack(alignment: .leading) {
                        Text("Übungen wählen:").foregroundColor(.white).font(.headline).padding(.horizontal)
                        ForEach(viewModel.training.machines) { machine in
                            HStack {
                                Text(machine.name).foregroundColor(.white); Spacer()
                                Image(systemName: selectedMachines.contains(machine) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedMachines.contains(machine) ? .green : .gray)
                            }
                            .padding().glassStyle().padding(.horizontal)
                            .onTapGesture {
                                if selectedMachines.contains(machine) { selectedMachines.remove(machine) }
                                else { selectedMachines.insert(machine) }
                            }
                        }
                    }
                }

                HStack {
                    Button("Abbrechen") { presentationMode.wrappedValue.dismiss() }.foregroundColor(.red)
                    Spacer()
                    Button("Speichern") {
                        if !name.isEmpty && !selectedMachines.isEmpty {
                            viewModel.training.addRoutine(name: name, selectedMachines: Array(selectedMachines))
                            presentationMode.wrappedValue.dismiss()
                        }
                    }.bold().foregroundColor(.green)
                }.padding()
            }
        }
    }
}//
//  CreateRoutineView.swift
//  Train with Me
//
//  Created by Thomas on 09.05.26.
//

