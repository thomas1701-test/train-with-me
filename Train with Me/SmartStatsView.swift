import SwiftUI
import Charts

struct SmartStatsView: View {
    var viewModel: AppViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            viewModel.currentTheme.backgroundView
            ScrollView {
                VStack(spacing: 20) {

                    // KI Coach
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.largeTitle)
                                .foregroundColor(viewModel.currentTheme.accentColor)
                            Text("KI Coach").font(.title2.bold()).foregroundColor(.white)
                        }
                        if viewModel.gemini.isLoading {
                            HStack {
                                ProgressView().padding().tint(.white)
                                Text("Analysiere...").foregroundColor(.white)
                            }
                        } else {
                            Text(viewModel.gemini.lastResponse)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.top, 5)
                        }
                        Button(action: {
                            Task { await viewModel.gemini.analyzeBodyStats(weightHistory: viewModel.health.weightHistory, waistHistory: viewModel.health.waistHistory, bodyFatHistory: viewModel.health.bodyFatHistory, systolic: viewModel.latestSystolic, diastolic: viewModel.latestDiastolic, machines: viewModel.training.machines) }
                        }) {
                            Text("Training analysieren")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.currentTheme.accentColor.opacity(0.3))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                        }.padding(.top, 10)
                    }.padding().glassStyle()

                    // Muskel Balance
                    VStack(alignment: .leading) {
                        Text("Muskel Balance")
                            .font(.headline).foregroundColor(.white).padding(.bottom, 5)
                        if viewModel.training.muscleShare.isEmpty {
                            Text("Keine Daten für eine Analyse verfügbar.").foregroundColor(.gray)
                        } else {
                            Chart(viewModel.training.muscleShare) { share in
                                SectorMark(
                                    angle: .value("Volumen", share.percentage),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(by: .value("Muskel", share.name))
                            }.frame(height: 200)
                        }
                    }.padding().glassStyle()

                    // Wochentrend
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Wochentrend").font(.caption).foregroundColor(.gray)
                            HStack {
                                Image(systemName: viewModel.training.weeklyTrend >= 0
                                      ? "chart.line.uptrend.xyaxis"
                                      : "chart.line.downtrend.xyaxis")
                                Text("\(Int(viewModel.training.weeklyTrend))%").font(.title.bold())
                            }.foregroundColor(viewModel.training.weeklyTrend >= 0 ? .green : .red)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Vergleich zur").font(.caption).foregroundColor(.gray)
                            Text("Vorwoche").font(.caption).foregroundColor(.gray)
                        }
                    }.padding().glassStyle()

                }.padding()
            }
        }
        .navigationTitle("Insights")
        .toolbar {
            Button("Schließen") { presentationMode.wrappedValue.dismiss() }
        }
    }
}
