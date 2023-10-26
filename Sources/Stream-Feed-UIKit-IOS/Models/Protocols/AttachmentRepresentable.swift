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
    public func attachmentImageURLs(timelineVideoEnabled: Bool) -> [UploadedMediaItem]? {
        if let mediaItems = media, mediaItems.count > 0, timelineVideoEnabled {
            var updatedMediaItem: [UploadedMediaItem] = mediaItems
            updatedMediaItem.removeFirst()
            return updatedMediaItem
        } else if let imageURLs = attachment?.imageURLs, imageURLs.count > 0 {
            return imageURLs.map { UploadedMediaItem(mediaType: "image", imageURL: $0, videoURL: nil, thumbnailURL: nil) }
        }
        return nil
    }
}
