//
//  File.swift
//  
//
//  Created by Sherif Shokry on 22/10/2023.
//

import UIKit

class MediaImageCell: UICollectionViewCell {
    @IBOutlet weak var scrollImg: PanZoomImageView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var reloadButton: UIButton!
    @IBOutlet weak var optionsButton: UIButton!

    var onImageTap: (() -> Void)?
    var reloadImage: (() -> Void)?
    var onDismissTap: (() -> Void)?

    var onOptionsTap: (() -> Void)?
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        let singleTapGest = UITapGestureRecognizer(target: self, action: #selector(onTapImage))
        scrollImg.isUserInteractionEnabled = true
        scrollImg.addGestureRecognizer(singleTapGest)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        scrollImg.resetZoomScale()
    }

    func config(imageURL: String?) {
        scrollImg.setZoomScale(1, animated: true)
        scrollImg.imageURL = imageURL
        scrollImg.loadImageURL()
        reloadButton.isHidden = true
        scrollImg.didReceiveError = { [weak self] in
            guard let self = self else { return }
            self.reloadButton.isHidden = false
        }
    }

    @objc private func onTapImage() {
        onImageTap?()
    }
    @IBAction func closeAction(_ sender: UIButton) {
        onDismissTap?()
    }
    @IBAction func reloadTapped(_ sender: UIButton) {
        reloadImage?()
    }
    @IBAction func optionsTapped(_ sender: UIButton) {
        onOptionsTap?()
    }
}
