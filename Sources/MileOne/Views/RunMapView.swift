import SwiftUI
import MapKit

// MARK: - RunMapView

/// Map view showing the runner's current position with a stats overlay.
@available(iOS 17.0, *)
public struct RunMapView: View {
    @Bindable var viewModel: RunViewModel

    private let darkBackground = Color(red: 28/255, green: 28/255, blue: 30/255)

    public init(viewModel: RunViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Map {
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
            }

            // Stats overlay
            HStack(spacing: 32) {
                statColumn(value: viewModel.formattedDistance, label: "Distance")
                statColumn(value: viewModel.formattedTotalElapsed, label: "Elapsed")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.bottom, 24)
            .padding(.horizontal, 16)
        }
        .background(darkBackground)
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
