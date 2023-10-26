//
//  File.swift
//  
//
//  Created by Sherif Shokry on 22/10/2023.
//

import UIKit
import Kingfisher

class PanZoomImageView: UIScrollView {

    @IBInspectable
    private var imageName: String? {
        didSet {
            guard let imageName = imageName else {
                return
            }
            imageView.image = UIImage(named: imageName)
        }
    }

    @IBInspectable
    var imageURL: String?
    var didReceiveError: (() -> Void)? = nil
    private(set) var imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    convenience init(named: String) {
        self.init(frame: .zero)
        self.imageName = named
    }


    func loadImageURL() {
        let url = URL(string: imageURL ?? "")!
        let imageId = url.getImageID()
        let resource = KF.ImageResource(downloadURL: url, cacheKey: imageId)
        imageView.loadImage(from: resource, loaderStyle: .large, loaderColor: .white) { [weak self] result in
            guard let self = self else { return }
            // this line is to get the image from cache after download and downsample it
            self.imageView.loadImage(from: resource, loaderStyle: .large, loaderColor: .white) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(_): break
                case .failure(_):
                    self.didReceiveError?()
                }
            }
        }
    }
    private func commonInit() {
        // Setup image view
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: widthAnchor),
            imageView.heightAnchor.constraint(equalTo: heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Setup scroll view
        minimumZoomScale = 1
        maximumZoomScale = 5
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        delegate = self

        // Setup tap gesture
        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapRecognizer)
    }
    @objc private func handleDoubleTap(_ sender: UITapGestureRecognizer) {
        if self.zoomScale == 1 {
            self.zoom(to: zoomRectForScale(scale: self.maximumZoomScale, center: sender.location(in: sender.view)), animated: true)
        } else {
            self.setZoomScale(1, animated: true)
        }
    }
    func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
            var zoomRect = CGRect.zero
            zoomRect.size.height = imageView.frame.size.height / scale
            zoomRect.size.width  = imageView.frame.size.width  / scale
            let newCenter = imageView.convert(center, from: self)
            zoomRect.origin.x = newCenter.x - (zoomRect.size.width / 2.0)
            zoomRect.origin.y = newCenter.y - (zoomRect.size.height / 2.0)
            return zoomRect
        }

    func resetZoomScale() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            self?.setZoomScale(1, animated: false)
        }
    }
}

extension PanZoomImageView: UIScrollViewDelegate {

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}
