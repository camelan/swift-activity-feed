//
//  File.swift
//  
//
//  Created by Sherif Shokry on 12/10/2023.
//

import UIKit.UIImage
import PhotosUI

enum MediaType {
    case photo, video
}

struct MediaItem {
    var id: String
    var mediaType: MediaType
    var image: UIImage?
    var url: URL?
}
