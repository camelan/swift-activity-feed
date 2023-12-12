//
//  File.swift
//  
//
//  Created by Sherif Shokry on 22/10/2023.
//

import UIKit

protocol AdditionalMediaProtocol {
    func onDismissPreview()
}


class MediaGalleryViewController: UIViewController, BundledStoryboardLoadable {
    public static var storyboardName = "ActivityFeed"
    @IBOutlet weak var mediaCollectionView: UICollectionView!
    @IBOutlet weak var innerContainerView: UIView!
    @IBOutlet weak var mediaPageControl: MediaCustomPageControl!
    private var panGestureRecognizer: UIPanGestureRecognizer!
    var viewTranslation = CGPoint(x: 0, y: 0)

    var additionalMedia = [UploadedMediaItem]()
    var selectedMediaItem: UploadedMediaItem?
    var logErrorAction: ((String, String) -> ())?
    var index: IndexPath?
    var isScreenDisplayed: Bool = false
    var currentIndexPath: IndexPath?
    var didTransactionOccur = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMediaCollectionView()
        setupPullDownToDismiss()
        setNavigationSettings(navigationType: .noNavigationBar)
    }


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        enableLandscapeMode(isEnabled: true)
        if isScreenDisplayed == false {
            self.view.backgroundColor = .clear
            self.innerContainerView.backgroundColor = .clear
            prepareMediaCollectionView()
            view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                guard let self = self else { return }
                self.view.transform = CGAffineTransform.identity
                self.view.backgroundColor = .black
                self.innerContainerView.backgroundColor = .black
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1, execute: { [weak self] in
                    guard let self = self else { return }
                    self.swipeToSpecificMedia()
                })
            })
            isScreenDisplayed = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pauseVideosOnDisappear()
        self.mediaCollectionView.visibleCells.forEach({
            if let cell = ($0 as? MediaFullScreenVideoCell) {
                cell.videoPlayerView.releasePlayerDataFromMemory()
            }
        })
        enableLandscapeMode(isEnabled: false)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
      
        didTransactionOccur = true
        self.mediaCollectionView.collectionViewLayout.invalidateLayout()
        scrollToCurrentIndexPath()
        self.mediaCollectionView.reloadData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.handleVideoAtCurrentIndexPath()
            self?.didTransactionOccur = false
        }
    }

    private func scrollToCurrentIndexPath() {
        guard let currentIndexPath = currentIndexPath else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            guard let self = self else { return }
            self.mediaCollectionView.scrollToItem(at: currentIndexPath, at: [.centeredVertically, .centeredHorizontally], animated: false)
        }
    }


   private func handleVideoAtCurrentIndexPath() {
        guard let currentIndexPath = currentIndexPath else {
            handleVideoAtIndex(item: IndexPath(item: 0, section: 0))
            return
        }

        handleVideoAtIndex(item: currentIndexPath)
    }

    private func enableLandscapeMode(isEnabled: Bool) {
        if isEnabled {
            let currentDeviceOrientation = UIDevice.current.orientation
            UIDevice.current.setValue(currentDeviceOrientation.rawValue, forKey: "orientation")
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
        UIViewController.attemptRotationToDeviceOrientation()
    }

    @objc func pauseVideosOnDisappear() {
        self.mediaCollectionView.visibleCells.forEach({
            ($0 as? MediaFullScreenVideoCell)?.videoPlayerView.pauseVideo()
        })
    }

    private func swipeToSpecificMedia() {
        guard let item = additionalMedia.firstIndex(where: { $0 == selectedMediaItem }) else { return }
        let index = index ?? IndexPath(item: item, section: 0)
        guard index.item < additionalMedia.count else {
            logErrorAction?("[Media Gallery] index item for Addtional Media is out of range this could be a crash but handled", "")
            return
        }
        mediaCollectionView.isPagingEnabled = false
        mediaCollectionView.scrollToItem(at: index, at: [.centeredVertically, .centeredHorizontally], animated: false)
        mediaPageControl.updateCurrentDots(borderColor: .white, backColor: .black, index: index.item)
        mediaCollectionView.isPagingEnabled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            self.handleVideoAtIndex(item: index)
        }
    }
    
    private func setupMediaCollectionView() {
        mediaCollectionView.register(UINib(nibName: "MediaFullScreenVideoCell", bundle: .module), forCellWithReuseIdentifier: "MediaFullScreenVideoCell")
        mediaCollectionView.register(UINib(nibName: "MediaImageCell", bundle: .module), forCellWithReuseIdentifier: "MediaImageCell")
        let layout = CustomCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumLineSpacing = 0


        self.mediaCollectionView.collectionViewLayout = layout
        self.mediaCollectionView.isPagingEnabled = true
        mediaCollectionView.translatesAutoresizingMaskIntoConstraints = false
        mediaCollectionView.showsHorizontalScrollIndicator = false
        mediaCollectionView.decelerationRate = .fast
        self.mediaCollectionView.delegate = self
        self.mediaCollectionView.dataSource = self
    }
    
    private func prepareMediaCollectionView() {
        mediaCollectionView.reloadData()
        if additionalMedia.isEmpty == false {
            mediaPageControl.numberOfDots = additionalMedia.count
        }
    }
    
    @IBAction func dismissAction(_ sender: UIButton) {
        self.setTransitionForDismiss()
    }

    private func setTransitionForDismiss() {
        let transition = CATransition()
        transition.duration = 0.5
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.type = CATransitionType.reveal
        transition.subtype = CATransitionSubtype.fromBottom
        navigationController?.view.layer.add(transition, forKey: nil)
        handleVideosOnMove()
        popOrDismiss()
    }

    private func handleVideoAtIndex(item: IndexPath) {
        // this Applies only on visible cell
        if let cell = self.mediaCollectionView.cellForItem(at: item) as? MediaFullScreenVideoCell {
            if !didTransactionOccur {
                cell.videoPlayerView.playerLayer?.player?.seek(to: .zero)
            }
            cell.videoPlayerView.playVideo()
            cell.videoPlayerView.showControlsBasedOnTime()
            cell.videoPlayerView.controlVolume(isMuted: false)
            self.mediaPageControl.isHidden = true
        } else if let _ = self.mediaCollectionView.cellForItem(at: item) as? MediaImageCell {
            self.mediaPageControl.isHidden = false
        }
    }
}
extension MediaGalleryViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.additionalMedia.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let mediaType = additionalMedia[indexPath.item].getMediaType()
        switch mediaType {
        case .image:
            let cell = mediaCollectionView.dequeueReusableCell(withReuseIdentifier: "MediaImageCell", for: indexPath) as! MediaImageCell
            cell.closeButton.isHidden = false
            cell.config(imageURL: self.additionalMedia[indexPath.item].imageURL?.absoluteString)
            cell.onDismissTap = { [weak self] in
                guard let self = self else { return }
                let isLandscapeOrientation = !UIDevice.current.orientation.isPortrait
                let topMostViewController = UIApplication.topMostViewController()
                if isLandscapeOrientation {
                    topMostViewController?.dismiss(animated: false)
                } else {
                    self.popOrDismiss()
                }
            }
            cell.onOptionsTap = { [weak self] in
                guard let self = self else { return }
            }
            cell.reloadImage = { [weak self] in
                guard let self = self else { return }
                self.mediaCollectionView.reloadItems(at: [indexPath])
            }
            return cell
        case .video:
            let cell = mediaCollectionView.dequeueReusableCell(withReuseIdentifier: "MediaFullScreenVideoCell", for: indexPath) as! MediaFullScreenVideoCell
             if !didTransactionOccur {
                 cell.config(videoURL: additionalMedia[indexPath.item].videoURL?.absoluteString,
                             presentedViewController: self,
                             logErrorAction: logErrorAction)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                cell.videoPlayerView.playerLayer?.frame = cell.videoPlayerView.videoView.frame
            }

            cell.videoPlayerView.showDots = { [weak self] show in
                self?.mediaPageControl.isHidden = !show
            }
            return cell
        }
    }
    
    private func popOrDismiss() {
        guard let topMostViewController = UIApplication.topMostViewController() else { return }
        guard let _ = topMostViewController.navigationController else {
            topMostViewController.dismiss(animated: false)
            return
        }
        topMostViewController.navigationController?.popViewController(animated: true)
    }
    
    private func isOnLandScapeOrientation() -> Bool {
        innerContainerView.frame.width >= innerContainerView.frame.height
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = innerContainerView.frame.width
        let height = innerContainerView.frame.height
        return CGSize(width: width, height: height)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == self.mediaCollectionView {
            let xPoint = scrollView.contentOffset.x + scrollView.frame.width / 2
            let yPoint = scrollView.frame.height / 2
            let center = CGPoint(x: xPoint, y: yPoint)
            if let ip = self.mediaCollectionView.indexPathForItem(at: center) {
                handleVideosOnMove()
                currentIndexPath = ip
                mediaPageControl.updateCurrentDots(borderColor: .white, backColor: .black, index: ip.item)
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let xPoint = scrollView.contentOffset.x + scrollView.frame.width / 2
                let yPoint = scrollView.frame.height / 2
                let center = CGPoint(x: xPoint, y: yPoint)
                if let ip = self.mediaCollectionView.indexPathForItem(at: center) {
                    self.index = ip
                    self.handleVideoAtIndex(item: ip)
                }
    }

    private func handleVideosOnMove() {
        // This Applies on all Video Cells onScroll Change
        self.mediaCollectionView.visibleCells.forEach({
            if let cell = ($0 as? MediaFullScreenVideoCell) {
                if !didTransactionOccur {
                    cell.videoPlayerView.playerLayer?.player?.seek(to: .zero)
                    cell.videoPlayerView.pauseVideo()
                    cell.videoPlayerView.controlVolume(isMuted: true)
                }
                cell.videoPlayerView.timer?.invalidate()
                cell.videoPlayerView.timer = nil
                self.mediaPageControl.isHidden = true
            }
        })
    }
}

extension MediaGalleryViewController{
    func setupPullDownToDismiss() {
        self.panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleDismiss))
        view.addGestureRecognizer(self.panGestureRecognizer)
    }

    @objc func handleDismiss(sender: UIPanGestureRecognizer) {
        let topMostViewController = UIApplication.topMostViewController()
        let isLandscapeOrientation = !UIDevice.current.orientation.isPortrait
        let maxTranslationValueInLandscapeMode: CGFloat = 50
        switch sender.state {
        case .changed:
            viewTranslation = sender.translation(in: view)
            if isLandscapeOrientation, abs(viewTranslation.y) >= maxTranslationValueInLandscapeMode {
                dismiss(animated: false)
            }
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
                self.view.transform = CGAffineTransform(translationX: 0, y: self.viewTranslation.y)
            })
            case .ended:
                if  viewTranslation.y > -50 && viewTranslation.y < 100 {
                    UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
                        self.view.transform = .identity
                    })
                } else {
                    self.handleVideosOnMove()
                    let transition = CATransition()
                    transition.duration = 0.5
                    transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                    transition.type = CATransitionType.fade
                    topMostViewController?.view.layer.add(transition, forKey: nil)
                    topMostViewController?.dismiss(animated: false)
                }
            default:
                break
            }
        }
}
