//
//  UIViewController+Extensions.swift
//  GetStreamActivityFeed
//
//  Created by Alexey Bukhtin on 15/01/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import SnapKit

// MARK: - Child View Controllers
typealias AlertAction = (title: String, style: UIAlertAction.Style, action: () -> Void, isEnabled: Bool?)

extension UIViewController {
    
    /// Adds a child view controller to a given container view or to the self view.
    public func add(viewController: UIViewController, to containerView: UIView? = nil) {
        addChild(viewController)
        let containerView: UIView = containerView ?? view
        containerView.addChildViewControllerView(viewController)
        viewController.didMove(toParent: self)
    }
    
    /// Removes a child view controller.
    public func remove(viewController: UIViewController) {
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }
    
    /// Replaces a child view controller with a new one.
    public func replace(viewController: UIViewController, with newViewController: UIViewController) {
        guard let containerView = viewController.view.superview else { return }
        viewController.willMove(toParent: nil)
        addChild(newViewController)
        containerView.addChildViewControllerView(newViewController)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
        newViewController.didMove(toParent: self)
    }
    
    private func addChildViewControllerViewToContainerView(containerView: UIView, childView: UIView) {
        containerView.addSubview(childView)
    }
    
    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() {
        UIApplication.shared.windows.filter{$0.isKeyWindow}.first?.endEditing(true)
    }
    
    func alertWithAction(title: String?,
                         message: String?,
                         alertStyle: UIAlertController.Style,
                         tintColor: UIColor?,
                         actions: [AlertAction]) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: alertStyle)
        actions.map { action in
                let alertAction = UIAlertAction(title: action.title, style: action.style, handler: { (_) in
                    action.action()
                })
            alertAction.isEnabled = action.isEnabled ?? true
            return alertAction
            }.forEach {
                alert.addAction($0)
            }

        if alertStyle == .actionSheet {
            alert.view.superview?.isUserInteractionEnabled = true
            alert.view.superview?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.alertControllerBackgroundTapped)))
        }
        if let tintColor = tintColor {
            alert.view.tintColor = tintColor
        }
        if var topController = UIApplication.shared.keyWindow?.rootViewController  {
        while let presentedViewController = topController.presentedViewController {
              topController = presentedViewController
             }
             topController.present(alert, animated: true)
        }

    }
    
    @objc private func alertControllerBackgroundTapped() {
        self.dismiss(animated: true, completion: nil)
    }
}

extension UIView {
    fileprivate func addChildViewControllerView(_ childViewController: UIViewController) {
        addSubview(childViewController.view)
        
        childViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    var safeAreaInset: UIEdgeInsets {
        if let window = UIApplication.shared.windows.filter({($0.isKeyWindow)}).first {
            return window.safeAreaInsets
        }
        return self.safeAreaInsets
    }
}

// MARK: - Modal

extension UIViewController {
    /// Return true if the view controller was presented modally.
    public var isModal: Bool {
        return presentingViewController != nil
            || navigationController?.presentingViewController?.presentedViewController === navigationController
            || tabBarController?.presentingViewController is UITabBarController
    }
}

// MARK: - Segue

extension UIViewController {
    /// Performs the segue with an identifier like the view controller class name.
    public func performSegue(show type: UIViewController.Type, sender: Any?) {
        performSegue(withIdentifier: String(describing: type), sender: sender)
    }
}

// MARK: - Show Alert Controller

extension UIViewController {
    func showErrorAlertIfNeeded(_ error: Error?) {
        if let error = error {
            showErrorAlert(error)
        }
    }
    
    func showErrorAlert(_ error: Error, function: String = #function, line: Int = #line) {
        print("❌", function, line, error)
        
        let alertController = UIAlertController(title: "Error",
                                                message: error.localizedDescription,
                                                preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        present(alertController, animated: true)
    }
}

extension UIViewController {
    func topMostViewController() -> UIViewController? {
        if self.presentedViewController == nil {
            return self
        }
        if let navigation = self.presentedViewController as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController()
        }
        if let tab = self.presentedViewController as? UITabBarController {
            if let selectedTab = tab.selectedViewController {
                return selectedTab.topMostViewController()
            }
            return tab.topMostViewController()
        }
        return self.presentedViewController!.topMostViewController()
    }
}



extension UIApplication {
    func topMostViewController() -> UIViewController? {
        return UIWindow.key?.rootViewController?.topMostViewController()
    }

    static func topMostViewController() -> UIViewController? {
        return UIApplication.shared.topMostViewController()
    }
}

extension UIWindow {
    static var key: UIWindow? {
        if #available(iOS 13, *) {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.keyWindow
        }
    }
}
