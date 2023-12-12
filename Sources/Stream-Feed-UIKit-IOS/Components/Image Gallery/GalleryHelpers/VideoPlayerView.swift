//
//  File.swift
//  
//
//  Created by Sherif Shokry on 22/10/2023.
//

import UIKit
import AVKit

class VideoPlayerView: UIView {

    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var volumeBtn: UIButton!
    
    @IBOutlet weak var dismissBtn: UIButton!
    @IBOutlet weak var resizeBtn: UIButton!
    @IBOutlet weak var videoSlider: UISlider!
    @IBOutlet weak var currentTimeLbl: UILabel!
    @IBOutlet weak var remainingTimeLbl: UILabel!
    @IBOutlet weak var goBackBtn: UIButton!
    @IBOutlet weak var goForwardBtn: UIButton!
    @IBOutlet weak var playAndPauseBtn: UIButton!
    @IBOutlet weak var playBackControlsView: UIView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var videoURL: String?
    var logErrorAction: ((String, String) -> Void)?
    
    private var player: AVPlayer?
    var presentedViewController: UIViewController?
    var timeObserver: Any?
    var showTime = 3
    weak var timer: Timer?
    private var playerItem: AVPlayerItem?
    var playerLayer: AVPlayerLayer?
    private var isPlaying: Bool = false
    var showDots: ((Bool) -> Void)?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    private func loadViewFromNib() -> UIView? {
        let nib = UINib(nibName: getNibName(), bundle: nil)
        return nib.instantiate(withOwner: self, options: nil).first as? UIView
    }
    
    private func getNibName() -> String {
        return String(describing: type(of: self))
    }
    
    func resetData() {
        self.videoSlider.maximumValue = 0
        self.videoSlider.minimumValue = 0
        self.videoSlider.value = Float(0)
        self.currentTimeLbl.text = "00:00"
        self.remainingTimeLbl.text = "00:00"
    }
    
    
    private func commonInit() {
        guard let view = loadViewFromNib() else { return }
        view.frame = self.bounds
        self.addSubview(view)
        self.dismissBtn.addBlurEffect(effect: .systemThinMaterialDark)
        self.volumeBtn.addBlurEffect(effect: .systemThinMaterialDark)
        self.resizeBtn.addBlurEffect(effect: .systemThinMaterialDark)
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(showControlsBasedOnTime))
        self.videoView?.isUserInteractionEnabled = true
        self.videoView?.addGestureRecognizer(tapGR)
        self.videoSlider.setThumbImage(UIImage(systemName: "circle.fill"), for: .normal)
        let isAr = false
        let configuration = UIImage.SymbolConfiguration(scale: .large)
        let backImage = UIImage(systemName: isAr ? "goforward.15" : "gobackward.15", withConfiguration: configuration)
        goBackBtn.setImage(backImage, for: .normal)
        let forwardImage = UIImage(systemName: isAr ? "gobackward.15" : "goforward.15", withConfiguration: configuration)
        goForwardBtn.setImage(forwardImage, for: .normal)
    }
    
    func loadVideoPlayerViewData() {
        guard let videoUrl = URL(string: videoURL ?? "") else {
            logErrorAction?("[Video Player View] [Video URL is invalid or empty]", "vidoeURL: \(videoURL ?? "")")
            return
        }
        resetData()
        self.activityIndicator.startAnimating()
        let asset = AVAsset(url: videoUrl)
        self.releaseOldPlayerItem()
        self.playerItem = AVPlayerItem(asset: asset)
        self.playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.initial, .old, .new], context: nil)
        self.player = nil
        player = AVPlayer(playerItem: playerItem)
        startPlayer()
    }
    
    func startPlayer() {
        guard self.player != nil else { return }
        self.releaseOldVideoPlayerLayer()
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        self.playerLayer?.frame = self.videoView.frame
        self.playerLayer?.addObserver(self,
                                      forKeyPath: #keyPath(AVPlayerLayer.isReadyForDisplay),
                                      options: [.old, .new], context: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(videoDidEnd),
                                               name: NSNotification
                                                .Name
                                                .AVPlayerItemDidPlayToEndTime,
                                               object: self.playerLayer?.player?.currentItem)

        self.playerLayer?.player?.currentItem?.addObserver(self, forKeyPath: "duration", options: [.initial, .old, .new], context: nil)
        addTimeObserver()
        videoView?.layer.addSublayer(playerLayer!)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.playerLayer?.frame = self.videoView.frame
        }
    }
    
    @objc private func videoDidEnd(notification: Notification) {
        guard let playerItem = notification.object as? AVPlayerItem else { return }
        guard let url = (playerItem.asset as? AVURLAsset)?.url else { return }
        let finishedVideoIsTheOneCurrentlyInDisplay = self.videoURL == url.absoluteString
        guard finishedVideoIsTheOneCurrentlyInDisplay else { return }
        self.playerLayer?.player?.seek(to: .zero) { [weak self] _ in
            guard let self = self else { return }
            self.pauseVideo()
            self.activityIndicator.stopAnimating()
            self.showControlsBasedOnTime()
        }
    }
    
    deinit {
        debugPrint("Video Player View deinit")
        releasePlayerDataFromMemory()
    }
    
    
    func releasePlayerDataFromMemory() {
        debugPrint("Video Player View Release Observers")
        self.pauseVideo()
        self.releaseOldPlayerItem()
        self.releaseOldVideoPlayerLayer()
        videoView?.layer.sublayers?.removeAll()
        videoView?.removeFromSuperview()
        NotificationCenter.default.removeObserver(self)
    }
    private func releaseOldVideoPlayerLayer() {
        if let playerLayer = self.playerLayer {
            self.playerLayer?.player?.currentItem?.removeObserver(self, forKeyPath: "duration")
            if let observer = self.timeObserver {
                self.playerLayer?.player?.removeTimeObserver(observer)
                self.timeObserver = nil
            }
            playerLayer.removeObserver(self, forKeyPath: #keyPath(AVPlayerLayer.isReadyForDisplay))
            self.playerLayer?.player = nil
            self.playerLayer = nil
        }
    }
    private func releaseOldPlayerItem() {
        if let _ = self.playerItem {
            self.playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
            self.playerItem = nil
        }
    }
    
    @objc func showControlsBasedOnTime() {
        self.showHidePlaybackControls(show: true)
        self.showTime = 3
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] (Timer) in
            guard let self = self else { return }
            if self.showTime > 0 {
                self.showTime -= 1
                self.showHidePlaybackControls(show: true)
            } else {
                Timer.invalidate()
                self.timer?.invalidate()
                self.timer = nil
                self.showHidePlaybackControls(show: false)
            }
        }
    }
    
    
    @IBAction func volumeBtnAction(_ sender: UIButton) {
        self.controlVolume(isMuted: !(self.playerLayer?.player?.isMuted ?? false))
    }
    
    @objc func controlVolume(isMuted: Bool) {
        self.playerLayer?.player?.isMuted = isMuted
        let configuration = UIImage.SymbolConfiguration(scale: .medium)
        
        let image = UIImage(systemName: (self.playerLayer?.player?.isMuted ?? false) ? "speaker.slash.fill" :"speaker.3.fill")?.applyingSymbolConfiguration(configuration)
        self.volumeBtn.setImage(image, for: .normal)
        resetShowHideTimer()
    }
    
    @IBAction func dismissAction(_ sender: UIButton) {
        self.pauseVideo()
        self.playerLayer?.player?.seek(to: .zero)
        let transition = CATransition()
        transition.duration = 0.5
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.type = CATransitionType.reveal
        transition.subtype = CATransitionSubtype.fromBottom
        presentedViewController?.navigationController?.view.layer.add(transition, forKey: nil)
        let isLandscapeOrientation = !UIDevice.current.orientation.isPortrait
        if isLandscapeOrientation {
            presentedViewController?.dismiss(animated: false)
        } else {
            popOrDismiss()
        }
    }
    
    private func popOrDismiss() {
        guard let _ = presentedViewController?.navigationController else {
            presentedViewController?.dismiss(animated: false)
            return
        }
        presentedViewController?.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func resizeAction(_ sender: UIButton) {
        self.playerLayer?.videoGravity = self.playerLayer?.videoGravity == .resizeAspect ? .resizeAspectFill : .resizeAspect
        resetShowHideTimer()
    }
    
    @IBAction func playAndPauseAction(_ sender: UIButton) {
        if isPlaying {
            pauseVideo()
        } else {
            playVideo()
        }
        resetShowHideTimer()
    }
    
    func pauseVideo() {
        self.playerLayer?.player?.pause()
        self.isPlaying = false
        let configuration = UIImage.SymbolConfiguration(scale: .large)
        let image = UIImage(systemName: self.isPlaying ? "pause.circle.fill" : "play.fill")?.applyingSymbolConfiguration(configuration)
        self.playAndPauseBtn.setImage(image, for: .normal)
    }
    
    func playVideo() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        } catch let error {
            logErrorAction?("[Video Player View] [something went wrong with AVAudio Session]", "error: \(error.localizedDescription)")
        }
        self.playerLayer?.player?.play()
        self.isPlaying = true
        let configuration = UIImage.SymbolConfiguration(scale: .large)
        let image = UIImage(systemName: self.isPlaying ? "pause.circle.fill" : "play.fill")?.applyingSymbolConfiguration(configuration)
        self.playAndPauseBtn.setImage(image, for: .normal)
    }
    
    
    @IBAction func backwardAction(_ sender: UIButton) {
        backwardAction()
    }
    
    @IBAction func forwardAction(_ sender: UIButton) {
        guard let duration = self.playerLayer?.player?.currentItem?.duration else { return }
        forwardAction(duration)
    }
    
    private func forwardAction(_ duration: CMTime) {
        let currentTime = CMTimeGetSeconds(self.playerLayer?.player?.currentTime() ?? CMTime() )
        let newTime = currentTime + 15.0
        
        if newTime < (CMTimeGetSeconds(duration) + 15) {
            let time = CMTimeMake(value: Int64(newTime) * 1000, timescale: 1000)
            self.playerLayer?.player?.seek(to: time)
        }
        resetShowHideTimer()
    }
    
    private func backwardAction() {
        let currentTime = CMTimeGetSeconds(self.playerLayer?.player?.currentTime() ?? CMTime() )
        var newTime = currentTime - 15.0
        
        if newTime < 0 {
            newTime = 0
        }
        let time = CMTimeMake(value: Int64(newTime) * 1000, timescale: 1000)
        self.playerLayer?.player?.seek(to: time)
        resetShowHideTimer()
    }
    @IBAction func videoSliderValueChange(_ sender: UISlider) {
        self.playerLayer?.player?.seek(to: CMTime(value: Int64(sender.value * 1000), timescale: 1000))
        resetShowHideTimer()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath,  keyPath == "duration", let duration = self.playerLayer?.player?.currentItem?.duration.seconds, duration > 0.0 {
            self.remainingTimeLbl.text = getTimeString(from: self.playerLayer?.player?.currentItem?.duration ?? CMTime())
            
        }
        if keyPath == #keyPath(AVPlayerLayer.isReadyForDisplay) {
                if playerLayer?.isReadyForDisplay ?? false {
                    debugPrint("Ready to display")
                    self.activityIndicator.stopAnimating()
                }
            }
        if keyPath == #keyPath(AVPlayerItem.status) {
                let status: AVPlayerItem.Status

                if let statusNumber = change?[.newKey] as? NSNumber {
                    status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
                } else {
                    status = .unknown
                }

                // Switch over status value
                switch status {
                case .readyToPlay:
                    debugPrint("Player item is ready to play.")
                case .failed:
                    debugPrint("Player item failed. See error \(self.playerLayer?.player?.currentItem?.error?.localizedDescription)")
                    handleVideoError()
                case .unknown:
                    debugPrint("Player item is not yet ready")
                @unknown default:
                    handleVideoError()
                }
            }
    }
    
    private func handleVideoError() {
        var errorReport = "Video Player View Error Occured\n"
        errorReport += "Error: -\n"
        errorReport += "Readable Error: \(self.playerLayer?.player?.currentItem?.error?.localizedDescription)"
        errorReport += "\(self.playerLayer?.player?.currentItem?.error)"
        logErrorAction?("[Video Player] [Something went wrong with VideoPlayerView]", "error: \(errorReport)")
    }
    
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let mainQueue = DispatchQueue.main
        self.timeObserver = self.playerLayer?.player?.addPeriodicTimeObserver(forInterval: interval, queue: mainQueue, using: { [weak self] (time) in
            guard let self = self else { return }
            guard let currentItem = self.playerLayer?.player?.currentItem else { return }
            if currentItem.status == .readyToPlay {
                self.videoSlider.maximumValue = Float(currentItem.duration.seconds)
                self.videoSlider.minimumValue = 0
                self.videoSlider.value = Float(currentItem.currentTime().seconds)
                self.currentTimeLbl.text = self.getTimeString(from: currentItem.currentTime())
                self.remainingTimeLbl.text = self.getTimeString(from: currentItem.duration - currentItem.currentTime())
            }
            
        })
    }
    
    private func getTimeString(from time: CMTime) -> String {
        let totalSeconds = CMTimeGetSeconds(time)
        let hours = Int(totalSeconds/3600)
        let minutes = Int(totalSeconds/60) % 60
        let seconds = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
        if hours > 0 {
            return String(format: "%i:%02i:%02i", arguments: [hours, minutes, seconds])
        } else {
            return String(format: "%02i:%02i", arguments: [minutes, seconds])
        }
    }
    
    func showHidePlaybackControls(show: Bool) {
        self.showDots?(!show)
        self.dismissBtn.isHidden = !show
        self.resizeBtn.isHidden = !show
        self.volumeBtn.isHidden = !show
        self.playBackControlsView.isHidden = !show
    }
    
    private func resetShowHideTimer() {
        self.timer?.invalidate()
        self.timer = nil
        self.showControlsBasedOnTime()
    }
}


    extension UIButton {
        func addBlurEffect(effect: UIBlurEffect.Style) {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: effect))
            blur.frame = self.bounds
            blur.isUserInteractionEnabled = false //This allows touches to forward to the button.
            self.insertSubview(blur, at: 0)
            if let imageView = self.imageView{
                imageView.backgroundColor = .clear
                self.bringSubviewToFront(imageView)
            }
        }
    }
