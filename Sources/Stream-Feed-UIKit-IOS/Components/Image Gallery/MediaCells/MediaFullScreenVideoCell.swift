//
//  File.swift
//  
//
//  Created by Sherif Shokry on 22/10/2023.
//

import UIKit

class MediaFullScreenVideoCell: UICollectionViewCell {
    
    @IBOutlet weak var videoPlayerView: VideoPlayerView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        videoPlayerView?.resetData()
    }
    
    func config(videoURL: String?, presentedViewController: UIViewController, logErrorAction: ((String,String) -> Void)?) {
        videoPlayerView?.videoURL = videoURL
        videoPlayerView?.logErrorAction = logErrorAction
        videoPlayerView?.presentedViewController = presentedViewController
        videoPlayerView?.loadVideoPlayerViewData()
    }
}
