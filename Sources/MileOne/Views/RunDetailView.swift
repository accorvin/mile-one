#if canImport(UIKit)
import SwiftUI
import MapKit

// MARK: - RunDetailView

/// Detailed view of a single completed run, including GPS trace (loaded on-demand).
public struct RunDetailView: View {

    let run: CompletedRunSnapshot
    @State private var viewModel: HistoryViewModel

    public init(run: CompletedRunSnapshot, viewModel: HistoryViewModel) {
        self.run = run
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                runHeader

                // Map trace
                mapSection

                // Stats grid
                statsGrid

                // Effort rating
                if let effort = run.effortRating {
                    effortSection(effort)
                }
            }
            .padding()
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadGPSPoints(forRunId: run.id)
        }
    }

    // MARK: - Header

    private var navigationTitle: String {
        run.isFreeRun ? "Free Run" : "Week \(run.weekNumber) · Session \(run.sessionNumber)"
    }

    private var runHeader: some View {
        VStack(spacing: 4) {
            Text(run.date, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(run.date, style: .time)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Map

    private var mapSection: some View {
        Group {
            if viewModel.currentGPSPoints.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGroupedBackground))
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No GPS data")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            } else {
                GPSTraceMapView(points: viewModel.currentGPSPoints)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(
                title: "Distance",
                value: String(format: "%.2f km", run.distanceMeters / 1000),
                icon: "figure.run"
            )
            statCard(
                title: "Duration",
                value: formattedDuration(run.durationSeconds),
                icon: "clock"
            )
            if let pace = run.averagePaceSecondsPerKm {
                statCard(
                    title: "Avg Pace",
                    value: formattedPace(pace),
                    icon: "speedometer"
                )
            }
            if run.calories > 0 {
                statCard(
                    title: "Calories",
                    value: "\(Int(run.calories)) kcal",
                    icon: "flame"
                )
            }
            if let hr = run.averageHeartRate {
                statCard(
                    title: "Avg Heart Rate",
                    value: "\(Int(hr)) bpm",
                    icon: "heart"
                )
            }
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Effort

    private func effortSection(_ effort: EffortRating) -> some View {
        HStack {
            Text("Effort")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(effort.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Formatters

    private func formattedDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func formattedPace(_ secondsPerKm: Double) -> String {
        let m = Int(secondsPerKm) / 60
        let s = Int(secondsPerKm) % 60
        return String(format: "%d:%02d /km", m, s)
    }
}

// MARK: - GPSTraceMapView

private struct GPSTraceMapView: UIViewRepresentable {
    let points: [GPSPointSnapshot]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isUserInteractionEnabled = false
        return map
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        guard !points.isEmpty else { return }

        let coords = points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

        // Remove existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        // Add polyline
        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        mapView.addOverlay(polyline)

        // Set region
        let region = MKCoordinateRegion(polyline.boundingMapRect.insetBy(dx: -5000, dy: -5000))
        mapView.setRegion(region, animated: false)

        // Start/end pins
        if let first = coords.first {
            let start = MKPointAnnotation()
            start.coordinate = first
            start.title = "Start"
            mapView.addAnnotation(start)
        }
        if let last = coords.last, coords.count > 1 {
            let end = MKPointAnnotation()
            end.coordinate = last
            end.title = "End"
            mapView.addAnnotation(end)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - EffortRating display name

private extension EffortRating {
    var displayName: String { label }
}
#endif
