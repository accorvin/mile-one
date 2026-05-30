#if canImport(UIKit)
import SwiftUI

// MARK: - RouteListView

/// Displays all saved routes with the ability to delete them.
public struct RouteListView: View {

    private let dataStore: any DataStoreProviding

    @State private var routes: [SavedRouteSnapshot] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init(dataStore: any DataStoreProviding) {
        self.dataStore = dataStore
    }

    public var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading routes…")
            } else if routes.isEmpty {
                ContentUnavailableView(
                    "No Saved Routes",
                    systemImage: "map",
                    description: Text("Plan a route and save it to see it here.")
                )
            } else {
                List {
                    ForEach(routes) { route in
                        routeRow(route)
                    }
                    .onDelete(perform: deleteRoutes)
                }
            }
        }
        .navigationTitle("Saved Routes")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadRoutes() }
        .refreshable { await loadRoutes() }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage {
                Text(msg)
            }
        }
    }

    // MARK: - Row

    private func routeRow(_ route: SavedRouteSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(route.name)
                .font(.headline)
            HStack {
                Label(formattedDistance(route.distanceMeters), systemImage: "ruler")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Label(
                    route.drawMode == .roadSnap ? "Road" : "Free",
                    systemImage: route.drawMode == .roadSnap ? "road.lanes" : "pencil"
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            Text(route.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func loadRoutes() async {
        isLoading = true
        defer { isLoading = false }
        do {
            routes = try await dataStore.fetchSavedRoutes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteRoutes(at offsets: IndexSet) {
        let toDelete = offsets.map { routes[$0] }
        routes.remove(atOffsets: offsets)
        Task {
            for route in toDelete {
                try? await dataStore.deleteSavedRoute(id: route.id)
            }
        }
    }

    // MARK: - Formatting

    private func formattedDistance(_ meters: Double) -> String {
        String(format: "%.2f km", meters / 1000)
    }
}
#endif
