//
//  File.swift
//  
//
//  Created by Sherif Shokry on 22/10/2023.
//

import UIKit


@IBDesignable
class MediaCustomPageControl: UIView {
    
    var dotsView = [RoundButton]()
    var currentIndex = 0
    
    @IBInspectable var circleColor: UIColor = UIColor.orange {
        didSet {
            updateView()
        }
    }
    @IBInspectable var circleBackgroundColor: UIColor = UIColor.clear {
        didSet {
            updateView()
        }
    }
    @IBInspectable var numberOfDots: Int = 7 {
        didSet {
            updateView()
        }
    }
    @IBInspectable var borderWidthSize: CGFloat = 1 {
        didSet {
            updateView()
        }
    }
   
   override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func  updateView() -> Void {
        self.releaseViews()
        
        let stackView   = UIStackView()
        stackView.axis  = NSLayoutConstraint.Axis.horizontal
        stackView.distribution  = UIStackView.Distribution.fillEqually
        stackView.alignment = UIStackView.Alignment.center
        stackView.spacing   = 5
        stackView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stackView)

        //Constraints
        stackView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        NSLayoutConstraint.activate([
            stackView.heightAnchor.constraint(equalToConstant: 20.0)
        ])
        stackView.removeFullyAllArrangedSubviews()
        if numberOfDots > 1 {
            for i in 0..<numberOfDots {
                let button:RoundButton = RoundButton(frame: CGRect(origin: CGRect.zero.origin, size: CGSize(width: 7, height: 7)))
                button.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    button.heightAnchor.constraint(equalToConstant: 8),
                    button.widthAnchor.constraint(equalToConstant: 8),
                ])
                button.tag = i
                button.layer.borderWidth = 1
                button.backgroundColor = circleBackgroundColor
                button.layer.borderWidth = borderWidthSize
                button.layer.borderColor = circleColor.cgColor
                button.layer.cornerRadius = button.frame.width / 2
                stackView.addArrangedSubview(button)
                dotsView.append(button)
                
            }
        }
        
       
    }
    func updateCurrentDots(borderColor : UIColor, backColor : UIColor, index : Int){
        for button in dotsView{
            if button == dotsView[index]{
                button.backgroundColor = backColor
                button.layer.borderColor = borderColor.cgColor
                button.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            }else{
                button.backgroundColor = self.circleBackgroundColor
                button.layer.borderColor = borderColor.cgColor
                button.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }
        }
    }

    private func releaseViews() {
        for v in self.subviews{
            v.removeFromSuperview()
        }
        dotsView.removeAll()
    }
}


class RoundButton: UIButton {

    override init(frame: CGRect) {
         super.init(frame: frame)
     }

     required init?(coder aDecoder: NSCoder) {
         super.init(coder: aDecoder)
     }

     override func prepareForInterfaceBuilder() {
         super.prepareForInterfaceBuilder()
     }

}

extension UIStackView {

    func removeFully(view: UIView) {
        removeArrangedSubview(view)
        view.removeFromSuperview()
    }

    func removeFullyAllArrangedSubviews() {
        arrangedSubviews.forEach { (view) in
            removeFully(view: view)
        }
    }

}
