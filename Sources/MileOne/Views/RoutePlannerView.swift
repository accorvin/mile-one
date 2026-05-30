#if canImport(UIKit)
import SwiftUI
import MapKit

// MARK: - RoutePlannerView

/// View for planning a route by placing waypoints on a map.
/// Supports road-snap and free-draw modes.
public struct RoutePlannerView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RoutePlannerViewModel
    @State private var drawMode: DrawMode = .roadSnap
    @State private var showSaveSheet = false
    @State private var routeName = ""
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var freeDrawPoints: [CLLocationCoordinate2D] = []

    private let dataStore: any DataStoreProviding

    public init(routeService: RouteService, dataStore: any DataStoreProviding) {
        _viewModel = State(initialValue: RoutePlannerViewModel(routeService: routeService))
        self.dataStore = dataStore
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mapLayer
                overlayControls
            }
            .navigationTitle("Route Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showSaveSheet) { saveSheet }
        }
    }

    // MARK: - Map Layer

    private var mapLayer: some View {
        MapReader { proxy in
            Map(position: $mapPosition) {
                ForEach(Array(viewModel.waypoints.enumerated()), id: \.offset) { index, coord in
                    Annotation("", coordinate: coord) {
                        Circle()
                            .fill(index == 0 ? Color.green : Color.blue)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                }
            }
            .onTapGesture { location in
                guard drawMode == .roadSnap else { return }
                if let coord = proxy.convert(location, from: .local) {
                    viewModel.addWaypoint(coord)
                    if viewModel.canCalculateRoute {
                        Task { await viewModel.calculateRoute() }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Overlay Controls

    private var overlayControls: some View {
        VStack(spacing: 12) {
            // Mode toggle
            Picker("Mode", selection: $drawMode) {
                Text("Road Snap").tag(DrawMode.roadSnap)
                Text("Free Draw").tag(DrawMode.freeDraw)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Distance counter
            HStack {
                Label(formattedDistance, systemImage: "ruler")
                    .font(.headline)
                Spacer()
                if viewModel.isCalculating {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal)

            // Action buttons
            HStack(spacing: 16) {
                Button(action: { viewModel.removeLastWaypoint() }) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(viewModel.waypoints.isEmpty)

                Button(action: { viewModel.clearAll() }) {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(viewModel.waypoints.isEmpty)

                Spacer()

                Button(action: { showSaveSheet = true }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .bold()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canCalculateRoute || viewModel.totalDistance == 0)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            NavigationLink {
                RouteListView(dataStore: dataStore)
            } label: {
                Label("Saved Routes", systemImage: "list.bullet")
            }
        }
    }

    // MARK: - Save Sheet

    private var saveSheet: some View {
        NavigationStack {
            Form {
                Section("Route Name") {
                    TextField("My Route", text: $routeName)
                }
                Section("Summary") {
                    LabeledContent("Distance", value: formattedDistance)
                    LabeledContent("Mode", value: drawMode == .roadSnap ? "Road Snap" : "Free Draw")
                }
            }
            .navigationTitle("Save Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRoute() }
                        .disabled(routeName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSaveSheet = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private var formattedDistance: String {
        let km = viewModel.totalDistance / 1000
        return String(format: "%.2f km", km)
    }

    private func saveRoute() {
        let name = routeName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let coords = viewModel.waypoints.map { [$0.latitude, $0.longitude] }
        guard let data = try? JSONEncoder().encode(coords) else { return }

        Task {
            _ = try? await dataStore.saveSavedRoute(
                name: name,
                drawMode: drawMode,
                waypointsData: SavedRoute.compress(data),
                distanceMeters: viewModel.totalDistance
            )
            showSaveSheet = false
            routeName = ""
        }
    }
}
#endif
