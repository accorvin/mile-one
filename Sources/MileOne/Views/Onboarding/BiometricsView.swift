#if canImport(UIKit)
import SwiftUI

// MARK: - BiometricsView

/// Onboarding step 2: Collect height, weight, birth year, biological sex.
/// Pre-populated from HealthKit when available.
public struct BiometricsView: View {

    @Bindable var viewModel: OnboardingViewModel

    private var isMetric: Bool { viewModel.unitPreference == .metric }

    private var heightLabel: String { isMetric ? "Height (cm)" : "Height (in)" }
    private var weightLabel: String { isMetric ? "Weight (kg)" : "Weight (lbs)" }
    private var heightPlaceholder: String { isMetric ? "170" : "67" }
    private var weightPlaceholder: String { isMetric ? "70" : "154" }

    /// Binding that converts between the VM's metric storage and imperial display.
    private var displayHeight: Binding<Double> {
        Binding(
            get: { isMetric ? viewModel.heightCm : viewModel.heightCm / 2.54 },
            set: { viewModel.heightCm = isMetric ? $0 : $0 * 2.54 }
        )
    }

    private var displayWeight: Binding<Double> {
        Binding(
            get: { isMetric ? viewModel.weightKg : viewModel.weightKg * 2.20462 },
            set: { viewModel.weightKg = isMetric ? $0 : $0 / 2.20462 }
        )
    }

    public var body: some View {
        Form {
            Section("Units") {
                Picker("Units", selection: $viewModel.unitPreference) {
                    Text("Imperial (miles, lbs)").tag(UnitPreference.imperial)
                    Text("Metric (km, kg)").tag(UnitPreference.metric)
                }
                .pickerStyle(.segmented)
            }

            Section("Height & Weight") {
                HStack {
                    Text(heightLabel)
                    Spacer()
                    TextField(heightPlaceholder, value: displayHeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text(weightLabel)
                    Spacer()
                    TextField(weightPlaceholder, value: displayWeight, format: .number)
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
