//
//  File.swift
//  
//
//  Created by Sherif Shokry on 19/10/2023.
//

import UIKit
import Kingfisher
import Reusable


class AttachementImageCell: UICollectionViewCell, Reusable {
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var playVideoView: UIView!
    
    func config(mediaItem: UploadedMediaItem) {
        let mediaType = mediaItem.getMediaType()
        switch mediaType {
        case .image:
            playVideoView.isHidden = true
            guard let uploadedImageURL = mediaItem.imageURL else { return }
            loadImage(with: uploadedImageURL)
        case .video:
            playVideoView.isHidden = false
            guard let thumbnailURL = mediaItem.thumbnailURL else { return }
            loadImage(with: thumbnailURL)
        }
    }
    
    
    private func loadImage(with url: URL) {
        let imageId = url.getImageID()
        let resource = KF.ImageResource(downloadURL: url, cacheKey: imageId)
        
        imageView.loadImage(from: resource)
    }

}
