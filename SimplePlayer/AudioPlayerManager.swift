import Foundation
import AVFoundation
import MediaPlayer

class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()
    private var player: AVAudioPlayer?
    @Published var isPlaying: Bool = false
    private var nowPlayingInfo: [String: Any] = [:]
    private var nowPlayingTimer: Timer?
    private var currentTrackURL: URL?
    private var currentTitle: String = ""
    private var currentArtist: String = ""
    private var currentArtwork: UIImage? = nil
    private override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        setupRemoteCommandCenter()
    }
    func play(url: URL, title: String = "", artist: String = "", artwork: UIImage? = nil) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
            currentTrackURL = url
            currentTitle = title
            currentArtist = artist
            currentArtwork = artwork
            updateNowPlayingInfo()
            startNowPlayingTimer()
        } catch {
            print("Ошибка воспроизведения: \(error)")
        }
    }
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingPlaybackState()
    }
    func resume() {
        player?.play()
        isPlaying = true
        updateNowPlayingPlaybackState()
    }
    func stop() {
        player?.stop()
        isPlaying = false
        stopNowPlayingTimer()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    private func updateNowPlayingInfo() {
        guard let player = player else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTitle,
            MPMediaItemPropertyArtist: currentArtist,
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let artwork = currentArtwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        nowPlayingInfo = info
    }
    private func updateNowPlayingPlaybackState() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime ?? 0
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    private func startNowPlayingTimer() {
        stopNowPlayingTimer()
        nowPlayingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateNowPlayingPlaybackState()
        }
    }
    private func stopNowPlayingTimer() {
        nowPlayingTimer?.invalidate()
        nowPlayingTimer = nil
    }
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            if self?.isPlaying == true {
                self?.pause()
            } else {
                self?.resume()
            }
            return .success
        }
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.player?.currentTime = event.positionTime
            self.updateNowPlayingPlaybackState()
            return .success
        }
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopNowPlayingTimer()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
