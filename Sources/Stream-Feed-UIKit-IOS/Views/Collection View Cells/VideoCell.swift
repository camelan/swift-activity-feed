//
//  VideoCell.swift
//  
//
//  Created by Sherif Shokry on 16/10/2023.
//

import UIKit
import Reusable

public final class VideoCell: UICollectionViewCell, NibReusable {
    
    @IBOutlet weak var showControlsButton: UIButton!
    @IBOutlet weak var playButtonView: UIView!
    @IBOutlet weak var videoThumbnailImageView: UIImageView!
    @IBOutlet public weak var removeButton: UIButton!
    var logErrorAction: ((String, String) -> Void)?
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        removeButton.removeTap()
        videoThumbnailImageView.image = nil
    }
    
    func config(thumbnailImage: UIImage?) {
        videoThumbnailImageView.image = thumbnailImage
    }
}
