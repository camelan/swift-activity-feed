//
//  AttachmentPresentable.swift
//  GetStreamActivityFeed
//
//  Created by Alexey Bukhtin on 05/03/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import GetStream
import UIKit

/// An attachment container protocol.
public protocol AttachmentRepresentable {
    /// An attachment. See `ActivityAttachment`.
    var attachment: ActivityAttachment? { get }
    var media: [UploadedMediaItem]? { get }
}

extension AttachmentRepresentable {
    /// Returns the Open Graph data. See `OGResponse`.
    public var ogData: OGResponse? {
        return attachment?.openGraphData
    }
    
    /// Returns a list of image URl's froim the attachment. See `ActivityAttachment`.
    public func attachmentImageURLs(firstImageURL: URL?, timelineVideoEnabled: Bool) -> [UploadedMediaItem]? {
        if let mediaItems = media, !mediaItems.isEmpty, timelineVideoEnabled {
            let updatedMediaItems = mediaItems.dropFirst()
            return !updatedMediaItems.isEmpty ? Array(mediaItems) : nil
        } else if let imageURLs = attachment?.imageURLs, !imageURLs.isEmpty {
            let allImagesURLs = imageURLs.map {
                UploadedMediaItem(mediaType: "image", imageURL: $0, videoURL: nil, thumbnailURL: nil)
            }
            if let firstImageURL = firstImageURL {
                let firstImageItem = UploadedMediaItem(mediaType: "image",
                                                       imageURL: firstImageURL,
                                                       videoURL: nil,
                                                       thumbnailURL: nil)
                return [firstImageItem] + allImagesURLs
            }
            
            return allImagesURLs
        }
        return nil
    }
}
