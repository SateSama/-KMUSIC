import Foundation
import AVFoundation
import MediaPlayer
import UIKit

/// Plays the queue with AVPlayer, keeps playing in the background and
/// drives the lock-screen / Control Center controls.
final class PlayerManager: ObservableObject {
    @Published private(set) var queue: [Song] = []
    @Published private(set) var index: Int = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0

    private let player = AVPlayer()
    private var client: SubsonicClient?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var artworkTask: Task<Void, Never>?

    var current: Song? {
        queue.indices.contains(index) ? queue[index] : nil
    }

    var coverURL: URL? {
        client?.coverURL(for: current?.coverArt, size: 600)
    }

    init() {
        configureAudioSession()
        configureRemoteCommands()
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds.isFinite ? time.seconds : 0
            if let item = self.player.currentItem {
                let total = item.duration.seconds
                if total.isFinite && total > 0 { self.duration = total }
            }
            self.updateNowPlayingProgress()
        }
    }

    // MARK: Public controls

    func play(_ songs: [Song], startAt start: Int = 0, client: SubsonicClient) {
        guard songs.indices.contains(start) else { return }
        self.client = client
        queue = songs
        index = start
        load(songs[start])
    }

    func toggle() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else if current != nil {
            player.play()
            isPlaying = true
        }
        updateNowPlayingProgress()
    }

    func next() {
        guard index + 1 < queue.count else {
            player.pause()
            isPlaying = false
            return
        }
        index += 1
        load(queue[index])
    }

    func previous() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard index > 0 else {
            seek(to: 0)
            return
        }
        index -= 1
        load(queue[index])
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        currentTime = seconds
        updateNowPlayingProgress()
    }

    // MARK: Loading

    private func load(_ song: Song) {
        guard let client, let url = client.streamURL(for: song.id) else { return }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        let item = AVPlayerItem(url: url)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.next()
        }
        player.replaceCurrentItem(with: item)
        currentTime = 0
        duration = Double(song.duration ?? 0)
        player.play()
        isPlaying = true
        publishNowPlaying(song)
    }

    // MARK: Audio session & lock screen

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("KMUSIC: audio session error \(error)")
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if !self.isPlaying { self.toggle() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.isPlaying { self.toggle() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: event.positionTime)
            return .success
        }
    }

    private func publishNowPlaying(_ song: Song) {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist ?? "",
            MPMediaItemPropertyAlbumTitle: song.album ?? "",
            MPMediaItemPropertyPlaybackDuration: Double(song.duration ?? 0),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        artworkTask?.cancel()
        guard let url = client?.coverURL(for: song.coverArt, size: 600) else { return }
        artworkTask = Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            await MainActor.run {
                // Merge with whatever is current so progress updates are not lost.
                var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
                updated[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
            }
        }
    }

    private func updateNowPlayingProgress() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
