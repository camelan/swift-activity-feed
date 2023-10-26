//
//  PostAttachmentImagesTableViewCell.swift
//  GetStreamActivityFeed
//
//  Created by Alexey Bukhtin on 31/01/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit

class PostAttachmentImagesTableViewCell: BaseTableViewCell {
    @IBOutlet public weak var collectionView: UICollectionView!
    private var mediaItems: [UploadedMediaItem] = []
    var imagesTapped: ((UploadedMediaItem) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        collectionView.register(UINib(nibName: "AttachementImageCell", bundle: .module), forCellWithReuseIdentifier: "AttachementImageCell")
    }
    
    func config(mediaItems: [UploadedMediaItem]) {
        self.mediaItems = mediaItems
        collectionView.reloadData()
    }
    
    open override func reset() {
        mediaItems = []
    }
}
extension PostAttachmentImagesTableViewCell: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return mediaItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath) as AttachementImageCell
        let mediaItem = mediaItems[indexPath.item]
        
        cell.config(mediaItem: mediaItem)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let mediaItem = mediaItems[indexPath.item]
        imagesTapped?(mediaItem)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = CGFloat(90)
        let height = CGFloat(90)
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 1, bottom: 0, right: 1)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
}
