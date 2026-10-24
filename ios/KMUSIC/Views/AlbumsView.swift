import SwiftUI

struct AlbumsView: View {
    @EnvironmentObject var app: AppState

    @State private var sort = "newest"
    @State private var albums: [Album] = []
    @State private var loading = false
    @State private var reachedEnd = false
    @State private var errorText: String?

    private struct SortOption: Identifiable {
        let key: String
        let label: String
        var id: String { key }
    }

    private let sorts: [SortOption] = [
        SortOption(key: "newest", label: "Récents"),
        SortOption(key: "alphabeticalByName", label: "A–Z"),
        SortOption(key: "frequent", label: "Fréquents"),
        SortOption(key: "random", label: "Aléatoire"),
    ]
    private let pageSize = 60

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Tri", selection: $sort) {
                        ForEach(sorts) { option in
                            Text(option.label).tag(option.key)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let errorText {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundColor(Color.kPrimaryBright)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 18) {
                        ForEach(albums) { album in
                            NavigationLink(value: album) {
                                AlbumCard(album: album)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if album.id == albums.last?.id {
                                    Task { await loadMore() }
                                }
                            }
                        }
                    }

                    if loading {
                        ProgressView().tint(Color.kPrimary)
                    }
                }
                .padding(16)
            }
            .background(Color.kBackground.ignoresSafeArea())
            .navigationTitle("Albums")
            .navigationDestination(for: Album.self) { album in
                AlbumDetailView(album: album)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            app.logout()
                        } label: {
                            Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task(id: sort) { await reload() }
            .miniPlayerInset()
        }
    }

    private func reload() async {
        albums = []
        reachedEnd = false
        errorText = nil
        await loadMore()
    }

    private func loadMore() async {
        guard !loading, !reachedEnd, let client = app.client else { return }
        loading = true
        defer { loading = false }
        do {
            let page = try await client.albums(type: sort, offset: albums.count, size: pageSize)
            let known = Set(albums.map(\.id))
            albums.append(contentsOf: page.filter { !known.contains($0.id) })
            if page.count < pageSize || sort == "random" {
                reachedEnd = true
            }
        } catch is CancellationError {
            // The sort changed while loading; the new task takes over.
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            errorText = error.localizedDescription
        }
    }
}

struct AlbumCard: View {
    let album: Album
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CoverView(url: app.client?.coverURL(for: album.coverArt, size: 300))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(album.name)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.kText)
                .lineLimit(1)
            Text(album.artist ?? "")
                .font(.caption)
                .foregroundColor(Color.kMuted)
                .lineLimit(1)
        }
    }
}
