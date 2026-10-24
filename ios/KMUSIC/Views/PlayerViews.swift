import SwiftUI

/// Puts the KMUSIC wordmark and the mini player above the tab bar.
struct MiniPlayerInset: ViewModifier {
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            MiniPlayerBar()
        }
    }
}

extension View {
    func miniPlayerInset() -> some View {
        modifier(MiniPlayerInset())
    }
}

struct MiniPlayerBar: View {
    @EnvironmentObject var player: PlayerManager
    @State private var showFull = false

    var body: some View {
        VStack(spacing: 0) {
            // The wordmark, always visible just above the player.
            Text("KMUSIC")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(Color.kPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .background(Color.kBackground)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.kSurfaceHigh).frame(height: 1)
                }

            if let song = player.current {
                HStack(spacing: 12) {
                    CoverView(url: player.coverURL)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Color.kText)
                            .lineLimit(1)
                        Text(song.artist ?? "")
                            .font(.caption)
                            .foregroundColor(Color.kMuted)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        player.toggle()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(Color.kText)
                            .frame(width: 40, height: 40)
                    }
                    Button {
                        player.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundColor(Color.kText)
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.kSurface)
                .contentShape(Rectangle())
                .onTapGesture { showFull = true }
            }
        }
        .sheet(isPresented: $showFull) {
            NowPlayingView()
        }
    }
}

struct NowPlayingView: View {
    @EnvironmentObject var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    @State private var dragging = false
    @State private var dragValue: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.kSurfaceHigh)
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            Spacer(minLength: 0)

            CoverView(url: player.coverURL)
                .frame(maxWidth: 320)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.kPrimary.opacity(0.35), radius: 24)
                .padding(.horizontal, 32)

            VStack(spacing: 4) {
                Text(player.current?.title ?? "")
                    .font(.title3.bold())
                    .foregroundColor(Color.kText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(player.current?.artist ?? "")
                    .foregroundColor(Color.kMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { dragging ? dragValue : player.currentTime },
                        set: { dragValue = $0 }
                    ),
                    in: 0...max(player.duration, 1),
                    onEditingChanged: { editing in
                        dragging = editing
                        if !editing { player.seek(to: dragValue) }
                    }
                )
                .tint(Color.kPrimary)
                HStack {
                    Text(clock(dragging ? dragValue : player.currentTime))
                    Spacer()
                    Text(clock(player.duration))
                }
                .font(.caption)
                .foregroundColor(Color.kMuted)
            }
            .padding(.horizontal, 28)

            HStack(spacing: 44) {
                Button { player.previous() } label: {
                    Image(systemName: "backward.fill").font(.title)
                }
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(Color.kPrimary)
                }
                Button { player.next() } label: {
                    Image(systemName: "forward.fill").font(.title)
                }
            }
            .foregroundColor(Color.kText)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.kBackground.ignoresSafeArea())
    }
}
