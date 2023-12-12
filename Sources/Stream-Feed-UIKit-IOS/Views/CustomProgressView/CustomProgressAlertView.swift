//
//  CustomProgressAlertView.swift
//
//
//  Created by Sherif Shokry on 30/11/2023.
//

import UIKit

protocol Instantiator {
    static func instantiate() -> Self
}

extension Instantiator {
    static func instantiate() -> Self {
        let id = String(describing: self)
        let nib = UINib(nibName: id, bundle: .module)
        return nib.instantiate(withOwner: nil, options: nil).first as! Self
    }
}

class CustomProgressAlertView: UIView, Instantiator {
    
    @IBOutlet weak var titleLbl: UILabel!
    @IBOutlet weak var progressLbl: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var cancelBtn: UIButton!
    var cancel: (() -> Void)?
    override class func awakeFromNib() {
        super.awakeFromNib()
    }
    
    
    @IBAction func CancelAction(_ sender: UIButton) {
        cancel?()
    }
    
}
