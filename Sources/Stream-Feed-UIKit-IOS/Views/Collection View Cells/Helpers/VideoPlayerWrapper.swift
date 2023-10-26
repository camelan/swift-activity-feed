//
//  File.swift
//  
//
//  Created by Sherif Shokry on 16/10/2023.
//

import Foundation
import AVFoundation
import AVKit

protocol VideoPlayerWrapperProtocol {
    var playerController: AVPlayerViewController? { get }
    var player: AVPlayer? { get set}
    var statusDidChange: ((_ olaStatus: AVPlayer.TimeControlStatus, _ newStatus: AVPlayer.TimeControlStatus) -> Void)? { get set }
    var videoDidEndClosure: (() -> Void)? { get set }
    var logErrorAction: ((String, String) -> Void)? { get set }
    func setupVideo(url: String?, view: UIView, delegate: AVPlayerViewControllerDelegate, action: ((Bool) -> Void)?)
    func pauseVideo()
    func playVideo()
    func openFullScreen()
    func releasePlayersFromMemory()
    
}


class VideoPlayerWrapper: NSObject, VideoPlayerWrapperProtocol {
    var playerController: AVPlayerViewController?
    var player: AVPlayer?
    var statusDidChange: ((_ olaStatus: AVPlayer.TimeControlStatus, _ newStatus: AVPlayer.TimeControlStatus) -> Void)?
    var videoDidEndClosure: (() -> Void)?
    var logErrorAction: ((String, String) -> Void)?
    func setupVideo(url: String?, view: UIView, delegate: AVPlayerViewControllerDelegate, action: ((Bool) -> Void)?) {
        guard let videoUrl = URL(string: url ?? "") else {
            logErrorAction?("[Video Wraper] Video URL is invalid or empty", "videoURL: \(url ?? "")")
            return
        }
        self.releasePlayersFromMemory()
        playerController = AVPlayerViewController()
        let asset = AVAsset(url: videoUrl)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        player?.addObserver(self, forKeyPath: "timeControlStatus", options: [.old, .new], context: nil)
        playerController?.player = player
        playerController?.delegate = delegate
        playerController?.showsPlaybackControls = false
        playerController?.exitsFullScreenWhenPlaybackEnds = true
        action?(playerController?.showsPlaybackControls ?? false)
        view.addSubview(playerController?.view ?? UIView())
        playerController?.view.frame = view.bounds
        playerController?.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerController?.videoGravity = .resizeAspect
        if #available(iOS 16.0, *) {
            playerController?.allowsVideoFrameAnalysis = false
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(videoDidEnd),
                                               name: NSNotification
                                                .Name
                                                .AVPlayerItemDidPlayToEndTime,
                                               object: playerController?.player?.currentItem)
    }
    func pauseVideo() {
        playerController?.player?.pause()
    }
    func playVideo() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        } catch let error {
            logErrorAction?("[Video Wraper] something went wrong with AVAudio Session", "error: \(error.localizedDescription)")
        }
        playerController?.player?.play()
    }
    
    func openFullScreen() {
        self.playerController?.enterFullScreen(animated: true)
    }
    deinit {
        debugPrint("Deinit Video Wrapper")
        releasePlayersFromMemory()
    }
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "timeControlStatus", let change = change, let newValue = change[NSKeyValueChangeKey.newKey] as? Int, let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int {
            guard let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue) else { return }
            guard let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue) else { return }
            if newStatus != oldStatus {
                statusDidChange?(oldStatus, newStatus)
            }
        }
    }
    @objc private func videoDidEnd(notification: Notification) {
        guard let playerItem = notification.object as? AVPlayerItem else { return }
        guard let url = (playerItem.asset as? AVURLAsset)?.url else { return }
        self.playerController?.showsPlaybackControls = false
        self.playerController?.player?.seek(to: .zero) { [weak self] _ in
            guard let self = self else { return }
            self.pauseVideo()
        }
    }
    
    func releasePlayersFromMemory() {
        debugPrint("Release Video Wrapper")
        self.player?.removeObserver(self, forKeyPath: "timeControlStatus")
        NotificationCenter.default.removeObserver(self)
        self.playerController?.player = nil
        self.playerController = nil
        self.player = nil
    }
}

extension AVPlayerViewController {
    func enterFullScreen(animated: Bool) {
        let selectorName: String = {
            return "enterFullScreenAnimated:completionHandler:"
            }()
        if self.responds(to: Selector(selectorName)) {
            self.perform(Selector(selectorName), with: true, with: nil)
        }
    }
    func exitFullScreen(animated: Bool) {
        let selectorName: String = "exitFullScreenAnimated:completionHandler:"
        if self.responds(to: Selector(selectorName)) {
            self.perform(Selector(selectorName), with: true, with: nil)
        }
    }
}
