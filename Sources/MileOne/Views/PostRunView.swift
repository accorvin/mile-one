#if canImport(UIKit)
import SwiftUI
import MapKit

// MARK: - PostRunView

/// Summary screen displayed after a run completes.
/// Shows route map, stats, HealthKit status, effort check-in, and a CTA.
@available(iOS 17.0, *)
public struct PostRunView: View {

    // MARK: - Input Data

    public let result: SaveRunResult
    public let distanceMeters: Double
    public let durationSeconds: Double
    public let calories: Double
    public let averagePaceSecondsPerKm: Double?
    public let averageHeartRate: Double?
    public let routeCoordinates: [CLLocationCoordinate2D]

    // MARK: - State

    @State private var selectedEffort: EffortRating? = nil
    @State private var effortSubmitted = false

    // MARK: - Callbacks

    public var onEffortSelected: ((EffortRating) -> Void)?
    public var onDashboard: () -> Void

    // MARK: - Init

    public init(
        result: SaveRunResult,
        distanceMeters: Double,
        durationSeconds: Double,
        calories: Double,
        averagePaceSecondsPerKm: Double?,
        averageHeartRate: Double?,
        routeCoordinates: [CLLocationCoordinate2D],
        onEffortSelected: ((EffortRating) -> Void)? = nil,
        onDashboard: @escaping () -> Void
    ) {
        self.result = result
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.calories = calories
        self.averagePaceSecondsPerKm = averagePaceSecondsPerKm
        self.averageHeartRate = averageHeartRate
        self.routeCoordinates = routeCoordinates
        self.onEffortSelected = onEffortSelected
        self.onDashboard = onDashboard
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    mapSection
                    statsSection
                    heartRateSection
                    healthKitStatusSection
                    effortSection
                    ctaSection
                }
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Nice Work! 🏃")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            Text("Run Complete")
                .font(.headline)
                .foregroundStyle(.gray)
        }
        .padding(.top, 32)
    }

    private var mapSection: some View {
        Group {
            if routeCoordinates.isEmpty {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 220)
                    .overlay(
                        Text("No route data")
                            .foregroundStyle(.gray)
                    )
                    .padding(.horizontal)
            } else {
                RouteMapSnapshot(coordinates: routeCoordinates)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
            }
        }
    }

    private var statsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatTile(label: "Distance", value: formattedDistance, unit: "km")
                StatTile(label: "Duration", value: formattedDuration, unit: "")
            }
            HStack(spacing: 16) {
                StatTile(label: "Pace", value: formattedPace, unit: "/km")
                StatTile(label: "Calories", value: String(format: "%.0f", calories), unit: "kcal")
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var heartRateSection: some View {
        if let hr = averageHeartRate {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("Avg Heart Rate")
                    .foregroundStyle(.gray)
                Spacer()
                Text(String(format: "%.0f bpm", hr))
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private var healthKitStatusSection: some View {
        HStack {
            Image(systemName: result.healthKitSaved ? "checkmark.circle.fill" : "info.circle")
                .foregroundStyle(result.healthKitSaved ? .green : .orange)
            Text(result.healthKitSaved
                 ? "Saved to Apple Health"
                 : "Not saved to Apple Health")
                .font(.subheadline)
                .foregroundStyle(result.healthKitSaved ? .green : .orange)
            Spacer()
        }
        .padding(.horizontal)
    }

    private var effortSection: some View {
        VStack(spacing: 12) {
            Text("How did it feel?")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                ForEach(EffortRating.allCases, id: \.self) { rating in
                    EffortButton(
                        rating: rating,
                        isSelected: selectedEffort == rating,
                        isDisabled: effortSubmitted
                    ) {
                        guard !effortSubmitted else { return }
                        selectedEffort = rating
                        effortSubmitted = true
                        onEffortSelected?(rating)
                    }
                }
            }

            if effortSubmitted, let effort = selectedEffort {
                Text("Got it — \(effort.label.lowercased())!")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var ctaSection: some View {
        Button(action: onDashboard) {
            HStack {
                Text("Back to Dashboard")
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal)
    }

    // MARK: - Formatters

    private var formattedDistance: String {
        String(format: "%.2f", distanceMeters / 1000.0)
    }

    private var formattedDuration: String {
        let total = Int(durationSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }

    private var formattedPace: String {
        guard let pace = averagePaceSecondsPerKm, pace > 0 else { return "--:--" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - StatTile

@available(iOS 17.0, *)
private struct StatTile: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.gray)
                .textCase(.uppercase)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - EffortButton

@available(iOS 17.0, *)
private struct EffortButton: View {
    let rating: EffortRating
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    private var emoji: String {
        switch rating {
        case .tooEasy:    return "😎"
        case .justRight:  return "✅"
        case .tooHard:    return "🔥"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.title2)
                Text(rating.label)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(isDisabled && !isSelected ? 0.4 : 1.0)
        }
        .disabled(isDisabled)
    }
}

// MARK: - RouteMapSnapshot

/// Minimal MapKit view that draws the GPS polyline from the run.
@available(iOS 17.0, *)
private struct RouteMapSnapshot: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isUserInteractionEnabled = false
        map.mapType = .standard
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        guard coordinates.count >= 2 else { return }

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        map.addOverlay(polyline)

        let region = MKCoordinateRegion(
            center: coordinates[coordinates.count / 2],
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
        map.setRegion(region, animated: false)
        map.delegate = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 4
            return renderer
        }
    }
}
#endif
