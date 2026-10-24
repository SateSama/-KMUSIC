import SwiftUI

struct AlbumDetailView: View {
    let album: Album

    @EnvironmentObject var app: AppState
    @EnvironmentObject var player: PlayerManager

    @State private var songs: [Song] = []
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CoverView(url: app.client?.coverURL(for: album.coverArt, size: 600))
                    .frame(maxWidth: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 8)

                VStack(spacing: 4) {
                    Text(album.name)
                        .font(.title2.bold())
                        .foregroundColor(Color.kText)
                        .multilineTextAlignment(.center)
                    Text(album.artist ?? "")
                        .foregroundColor(Color.kMuted)
                }

                HStack(spacing: 12) {
                    Button {
                        start(songs, at: 0)
                    } label: {
                        Label("Lecture", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.kPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    Button {
                        start(songs.shuffled(), at: 0)
                    } label: {
                        Label("Aléatoire", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.kSurfaceHigh)
                            .foregroundColor(Color.kText)
                            .cornerRadius(10)
                    }
                }
                .disabled(songs.isEmpty)
                .padding(.horizontal, 16)

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundColor(Color.kPrimaryBright)
                }

                LazyVStack(spacing: 0) {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { offset, song in
                        Button {
                            start(songs, at: offset)
                        } label: {
                            SongRow(song: song, number: song.track ?? offset + 1)
                        }
                        .buttonStyle(.plain)
                        Divider().background(Color.kSurfaceHigh)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
        }
        .background(Color.kBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .miniPlayerInset()
    }

    private func start(_ list: [Song], at index: Int) {
        guard let client = app.client else { return }
        player.play(list, startAt: index, client: client)
    }

    private func load() async {
        guard let client = app.client else { return }
        do {
            songs = try await client.album(id: album.id)?.song ?? []
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct SongRow: View {
    let song: Song
    let number: Int
    @EnvironmentObject var player: PlayerManager

    var body: some View {
        let playing = player.current?.id == song.id
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .foregroundColor(Color.kMuted)
                .frame(width: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .foregroundColor(playing ? Color.kPrimaryBright : Color.kText)
                    .lineLimit(1)
                if let artist = song.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundColor(Color.kMuted)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let seconds = song.duration {
                Text(clock(Double(seconds)))
                    .font(.caption)
                    .foregroundColor(Color.kMuted)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
