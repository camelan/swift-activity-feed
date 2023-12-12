//
//  VideoCell.swift
//  
//
//  Created by Sherif Shokry on 16/10/2023.
//

import UIKit
import AVKit
import Reusable

public final class VideoCell: UICollectionViewCell, NibReusable {
    
    @IBOutlet weak var showControlsButton: UIButton!
    @IBOutlet weak var playButtonView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet public weak var removeButton: UIButton!
    var streamingURL: String?
    var logErrorAction: ((String, String) -> Void)?
    private(set) var videoPlayerWrapper: VideoPlayerWrapperProtocol = VideoPlayerWrapper()
    var showControlsState: ((Bool) -> Void)?
    var videoPlayerTapped: (() -> Void)?
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        videoPlayerWrapper.logErrorAction = logErrorAction
        activityIndicator.removeFromSuperview()
        activityIndicator.stopAnimating()
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        self.videoPlayerWrapper.playerController?.showsPlaybackControls = false
        self.showControlsState?(self.videoPlayerWrapper.playerController?.showsPlaybackControls ?? false)
        self.videoPlayerWrapper.player?.pause()
        self.videoPlayerWrapper.playerController?.player?.seek(to: .zero) { [weak self] _ in
            guard let self = self else { return }
            self.pauseVideo()
        }
        removeButton.removeTap()
    }
    
    func presentIndicator() {
        activityIndicator.color = .white
    }
    
    
    
    func releasePlayerObservers() {
        activityIndicator?.removeFromSuperview()
    }
    
     func config(streamingURL: String?) {
        startVideoPlayer(streamingURL: streamingURL)
    }
    
    private func startVideoPlayer(streamingURL: String?) {
        self.streamingURL = streamingURL
        self.videoPlayerWrapper.setupVideo(url: streamingURL ?? "", view: self.videoView, delegate: self) { [weak self] isControllerShown in
            guard let self = self else { return }
            self.showControlsState?(isControllerShown)
        }
        
        self.videoPlayerWrapper.statusDidChange = { [weak self] (oldStatus, newStatus) in
            guard let self = self else { return }
            if newStatus == .playing || newStatus == .paused {
                self.activityIndicator.stopAnimating()
            } else {
                self.presentIndicator()
            }
        }
        self.videoPlayerWrapper.videoDidEndClosure = { [weak self] in
            guard let self = self else { return }
            self.showControlsState?(self.videoPlayerWrapper.playerController?.showsPlaybackControls ?? false)
            self.showControlsButton.isHidden = false
            self.playButtonView.isHidden = false
            self.activityIndicator.stopAnimating()
        }
    }
    
    @objc func pauseVideo() {
        self.videoPlayerWrapper.pauseVideo()
    }
    
    @objc func playVideo() {
        self.videoPlayerWrapper.playVideo()
    }
    
    @IBAction func videoPlayerTouched(_ sender: UIButton) {
       videoPlayerTapped?()
    }
    
    @IBAction func didTapPlayButton(_ sender: UIButton) {
        videoPlayerTapped?()
    }
}

extension VideoCell: AVPlayerViewControllerDelegate {
    public func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        // The system pauses when returning from full screen, we need to 'resume' manually.
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self = self else { return }
            self.playVideo()
        }
    }
    
    public func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self = self else { return }
            self.playVideo()
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.videoPlayerWrapper.playerController?.showsPlaybackControls = !(self.videoPlayerWrapper.playerController?.showsPlaybackControls ?? false)
       
        self.showControlsState?(self.videoPlayerWrapper.playerController?.showsPlaybackControls ?? false)
    }
    
}

