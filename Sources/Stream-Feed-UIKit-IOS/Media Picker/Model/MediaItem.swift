//
//  File.swift
//  
//
//  Created by Sherif Shokry on 12/10/2023.
//

import UIKit.UIImage
import PhotosUI

public enum MediaType: String {
    case image, video
}

public enum State: Equatable {
   case onStart
   case Uploaded
   case Error
   case Cancelled
   case Uploading(Double)
}

struct MediaItem {
    var id: String
    var mediaType: MediaType
    var image: UIImage?
    var uploadedImageURL: URL?
    var videoURL: URL?
    var uploadedVideoURL: URL?
    var videoThumbnail: UIImage?
    var uploadedVideoThumbnailURL: URL?
    
    
    var uploadedMediaItem: UploadedMediaItem {
        return UploadedMediaItem(mediaType: mediaType.rawValue,
                                 imageURL: uploadedImageURL,
                                 videoURL: uploadedVideoURL,
                                 thumbnailURL: uploadedVideoThumbnailURL)
    }
}

public struct UploadedMediaItem: Codable, Equatable {
    var mediaType: String
    var imageURL: URL?
    var videoURL: URL?
    var thumbnailURL: URL?
    
    
    public func getMediaURL() -> String? {
        let mediaType = self.getMediaType()
        switch mediaType {
        case .video:
            if let thumbnailURL = thumbnailURL?.absoluteString {
                return thumbnailURL
            }
        case .image:
            if let imageURL = imageURL?.absoluteString {
                return imageURL
            }
        }
        return nil
    }
    
    public func getMediaType() -> MediaType {
        switch self.mediaType {
        case "video":
            return .video
        case "image":
            return .image
        default:
            return .image
        }
    }
    
    
    private enum CodingKeys: String, CodingKey {
        case mediaType, imageURL
        case videoURL, thumbnailURL
    }
}
