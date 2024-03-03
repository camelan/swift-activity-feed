//
//  CommentTableViewCell.swift
//  GetStreamActivityFeed
//
//  Created by Alexey Bukhtin on 06/02/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit

open class CommentTableViewCell: BaseTableViewCell {
    
    @IBOutlet weak var avatarLeadingConstraint: NSLayoutConstraint!
    @IBOutlet public weak var avatarImageView: UIImageView!
    @IBOutlet private weak var commentLabel: UILabel!
    @IBOutlet public weak var replyButton: UIButton!
    @IBOutlet public weak var likeButton: LikeButton!
    @IBOutlet weak var moreRepliesStackView: UIStackView!
    @IBOutlet weak var moreRepliesLabel: UILabel!
    var avatarUserTapped: (() -> Void)?
    var name: String?
    public var withIndent: Bool {
        get { return avatarLeadingConstraint.constant != 0 }
        set {
            avatarLeadingConstraint.constant = newValue ? avatarImageView.bounds.width + 8 : 0
            
            if newValue {
                replyButton.isHidden = true
                likeButton.isHidden = true
            }
        }
    }
    
    public var moreReplies: String {
        get { return moreRepliesLabel.text ?? "" }
        set {
            moreRepliesStackView.isHidden = newValue.isEmpty
            moreRepliesLabel.text = newValue
        }
    }
    
    open override func reset() {
        avatarImageView.image = UIImage(named: "user_icon")
        commentLabel.attributedText = nil
        replyButton.removeTap()
        replyButton.isSelected = false
        replyButton.isHidden = true
        replyButton.semanticContentAttribute = .forceLeftToRight
        likeButton.removeTap()
        likeButton.isSelected = false
        likeButton.isHidden = false
        likeButton.semanticContentAttribute = .forceLeftToRight
        withIndent = false
        moreReplies = ""
    }
    @IBAction func avatarTapped(_ sender: UIButton) {
        avatarUserTapped?()
    }
    
    public func updateComment(name: String, comment: String, date: Date) {
        self.name = name
        let attributedText = NSMutableAttributedString(string: name, attributes: [.font: UIFont(name: "GTWalsheimProMedium", size: 15.0)!])
        let comment = NSAttributedString(string: "\n\(comment)", attributes: [.font: UIFont(name: "GTWalsheimProRegular", size: 15.0)!])
        attributedText.append(comment)
        let date = NSAttributedString(string: "\n\(date.relative)", attributes: [.foregroundColor: UIColor.lightGray,
                                                                                 .font: UIFont(name: "GTWalsheimProRegular", size: 12.0)!])
        attributedText.append(date)
        
        attributedText.applyParagraphStyle { paragraphStyle in
            paragraphStyle.lineHeightMultiple = 1.2
        }
        
        commentLabel.attributedText = attributedText
        commentLabel.isUserInteractionEnabled = true
        commentLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTapOnUserName(_:))))

         
    }
    
    @objc func handleTapOnUserName(_ tapGesture: UITapGestureRecognizer) {
        if let name = name {
            if didTapText(label: commentLabel, text: name, tapGesture: tapGesture) {
                avatarUserTapped?()
            }
        }
    }
    
    private func didTapText(label: UILabel, text: String, tapGesture: UITapGestureRecognizer) -> Bool {
        guard let textRange = (label.text as? NSString)?.range(of: text) else { return false }
        return tapGesture.didTapAttributedTextInLabel(label: label, inRange: textRange)
    }
}
