//
//  File.swift
//  
//
//  Created by Sherif Shokry on 23/10/2023.
//

import UIKit

enum NavigationType {
    case `default`
    case defaultWithCustomFont(_ Font: UIFont)
    case largeTitle
    case noNavigationBar
}

extension UIViewController {
    func setNavigationSettings(navigationType: NavigationType) {
        switch navigationType {
        case .default:
            self.navigationItem.largeTitleDisplayMode = .never
            self.navigationController?.navigationItem.largeTitleDisplayMode = .never
            self.navigationController?.navigationBar.setCustomTitleFont(font: UIFont(name: "GTWalsheimProMedium", size: 17.0)!)
            self.navigationController?.setNavigationBarHidden(false, animated: true)
        case .defaultWithCustomFont(let font):
            self.navigationItem.largeTitleDisplayMode = .never
            self.navigationController?.navigationItem.largeTitleDisplayMode = .never
            self.navigationController?.navigationBar.setCustomTitleFont(font: font)
            self.navigationController?.setNavigationBarHidden(false, animated: true)
        case .largeTitle:
            navigationItem.largeTitleDisplayMode = .always
            self.navigationController?.navigationItem.largeTitleDisplayMode = .always
            self.navigationController?.setNavigationBarHidden(false, animated: true)
        case .noNavigationBar:
            self.navigationItem.largeTitleDisplayMode = .never
            self.navigationController?.navigationItem.largeTitleDisplayMode = .never
            self.navigationController?.setNavigationBarHidden(true, animated: true)
        }
        self.navigationController?.hideHairline()
    }
}
