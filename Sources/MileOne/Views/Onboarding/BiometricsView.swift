#if canImport(UIKit)
import SwiftUI

// MARK: - BiometricsView

/// Onboarding step 2: Collect height, weight, birth year, biological sex.
/// Pre-populated from HealthKit when available.
public struct BiometricsView: View {

    @Bindable var viewModel: OnboardingViewModel

    public var body: some View {
        Form {
            Section("Height & Weight") {
                HStack {
                    Text("Height (cm)")
                    Spacer()
                    TextField("170", value: $viewModel.heightCm, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Weight (kg)")
                    Spacer()
                    TextField("70", value: $viewModel.weightKg, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("About You") {
                HStack {
                    Text("Birth Year")
                    Spacer()
                    TextField("1990", value: $viewModel.birthYear, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }

                Picker("Biological Sex", selection: $viewModel.biologicalSex) {
                    Text("Male").tag(BiologicalSex.male)
                    Text("Female").tag(BiologicalSex.female)
                }
            }

            Section("Units") {
                Picker("Units", selection: $viewModel.unitPreference) {
                    Text("Imperial (miles, lbs)").tag(UnitPreference.imperial)
                    Text("Metric (km, kg)").tag(UnitPreference.metric)
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Your Details")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Continue") { viewModel.advance() }
            }
        }
    }
}
#endif
