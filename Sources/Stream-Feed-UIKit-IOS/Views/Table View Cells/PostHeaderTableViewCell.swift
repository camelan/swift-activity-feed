//
//  PostHeaderTableViewCell.swift
//  GetStreamActivityFeed
//
//  Created by Alexey Bukhtin on 18/01/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import Nuke
import GetStream
import Kingfisher

open class PostHeaderTableViewCell: BaseTableViewCell {

    @IBOutlet public weak var avatarButton: UIButton!
    @IBOutlet private(set) weak var userProfileButton: UIButton!
    @IBOutlet public weak var nameLabel: UILabel!
    @IBOutlet private weak var repostInfoStackView: UIStackView!
    @IBOutlet private weak var repostInfoLabel: UILabel!
    @IBOutlet public weak var dateLabel: UILabel!
    @IBOutlet public weak var messageLabel: UILabel!
    @IBOutlet private weak var messageBottomConstraint: NSLayoutConstraint!
    @IBOutlet private(set) weak var photoImageView: UIImageView!
    @IBOutlet public weak var postSettingsButton: UIButton!
    @IBOutlet public weak var ImagePostButton: UIButton!
    @IBOutlet public weak var playVideoView: UIView!
    
    var activityID: String = ""
    var postSettingsTapped: ((Activity) -> Void)?
    var photoImageTapped: (([UploadedMediaItem], UploadedMediaItem) -> Void)?
    var profileImageTapped: ((String) -> Void)?
    var currentActivity: Activity?
    var timelineVideoEnabled: Bool = false
    
    public var repost: String? {
        get {
            return repostInfoLabel.text
        }
        set {
            if let reply = newValue {
                repostInfoStackView.isHidden = false
                repostInfoLabel.text = reply
            } else {
                repostInfoStackView.isHidden = true
            }
        }
    }
    
    open override func reset() {
        updateAvatar(with: nil)
        userProfileButton.isEnabled = true
        userProfileButton.isUserInteractionEnabled = true
        nameLabel.text = nil
        dateLabel.text = nil
        repostInfoLabel.text = nil
        repostInfoStackView.isHidden = true
        messageLabel.text = nil
        photoImageView.image = nil
        currentActivity = nil
        messageBottomConstraint.priority = .defaultHigh + 1
        playVideoView.isHidden = false
        timelineVideoEnabled = false
    }
    
    public func setActivity(with activity: Activity, timelineVideoEnabled: Bool) {
        currentActivity = activity
        self.timelineVideoEnabled = timelineVideoEnabled

        guard let currentActivity = currentActivity, currentActivity.media?.count ?? 0 > 0, timelineVideoEnabled else {
            playVideoView.isHidden = true
            return
        }
        guard let firstMediaItem = currentActivity.media?.first else { return }
        let mediaType = firstMediaItem.getMediaType()
        playVideoView.isHidden = mediaType == .video ? false : true
    }
    
    public func updateAvatar(with image: UIImage?) {
        if let image = image {
            avatarButton.setImage(image, for: .normal)
            avatarButton.contentHorizontalAlignment = .fill
            avatarButton.contentVerticalAlignment = .fill
        } else {
            avatarButton.setImage(UIImage(named: "user_icon"), for: .normal)
            avatarButton.contentHorizontalAlignment = .center
            avatarButton.contentVerticalAlignment = .center
        }
        avatarButton.imageView?.contentMode = .scaleAspectFill
    }
    
    public func updateAvatar(with profilePictureURL: String) {
        guard let imageURL = URL(string: profilePictureURL) else { return }
        avatarButton.loadImage(from: imageURL.absoluteString, placeholder: UIImage(named: "user_icon")) { [weak self] _ in
            self?.updateAvatar(with: self?.avatarButton.imageView?.image)
        }
    }

    public func updatePhoto(with url: URL) {
        messageBottomConstraint.priority = .defaultLow
        photoImageView.isHidden = false
        loadImage(with: url)
    }
    
    private func loadImage(with url: URL) {
        let imageId = url.getImageID()
        let resource = KF.ImageResource(downloadURL: url, cacheKey: imageId)
        
        photoImageView.loadImage(from: resource)
    }

    
    @IBAction func postSettings(_ sender: UIButton) {
       guard let currentActivity = currentActivity else { return }
       postSettingsTapped?(currentActivity)
    }
    
    @IBAction func photoImageTapped(_ sender: UIButton) {
        guard let mediaItems = currentActivity?.mappedMediaItems(timelineVideoEnabled: timelineVideoEnabled) else { return }
        guard let firstMediaItem = mediaItems.first else { return }
        photoImageTapped?(mediaItems, firstMediaItem)
    }
    
    @IBAction func profileImageTapped(_ sender: UIButton) {
        navigateToUserProfileAction()
    }
    
    @IBAction func userNameTapped(_ sender: UIButton) {
        navigateToUserProfileAction()
    }
    
    private func navigateToUserProfileAction() {
        let originalActivity = currentActivity?.original
        guard let actorId = originalActivity?.actor.id else { return }
        
        profileImageTapped?(actorId)
    }
}

extension PostHeaderTableViewCell {
    
    public func update<T: ActivityProtocol>(with activity: T, originalActivity: T? = nil) where T.ActorType: UserNameRepresentable {
        let originalActivity = originalActivity ?? activity
        nameLabel.text = originalActivity.actor.name
        
        if let textRepresentable = originalActivity as? TextRepresentable {
            messageLabel.text = textRepresentable.text
        }
        
        if let object = originalActivity.object as? ActivityObject {
            switch object {
            case .text(let text):
                messageLabel.text = text
            case .image(let url):
                guard let currentActivity = currentActivity, currentActivity.media?.count ?? 0 > 0 else {
                    updatePhoto(with: url)
                    return
                }
                guard let firstMediaItem = currentActivity.media?.first else { return }
                guard let mediaURLString = firstMediaItem.getMediaURL() else {
                    updatePhoto(with: url)
                    return
                }
                let mediaURL = URL(string: mediaURLString)!
                updatePhoto(with: mediaURL)
            case .following(let user):
                messageLabel.text = "Follow to \(user.name)"
            default:
                return
            }
        }
        
        dateLabel.text = activity.time?.relative
        
        if activity.verb == .repost {
            repost = "reposted by \(activity.actor.name)"
        }
    }
    
    public func updateAvatar<T: AvatarRepresentable>(with avatar: T, action: UIControl.Action? = nil) {
        if let avatarURL = avatar.avatarURL {
            ImagePipeline.shared.loadImage(with: avatarURL.imageRequest(in: avatarButton), completion:  { [weak self] result in
                self?.updateAvatar(with: try? result.get().image)
            })
        }
    }
}
