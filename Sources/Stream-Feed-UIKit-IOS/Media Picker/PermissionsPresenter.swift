//
//  PermissionsPresenter.swift
//
//
//  Created by Mohammedbadr on 1/22/24.
//

import AVFoundation
import CoreLocation
import Foundation
import Photos

protocol PermissionsDelegate: class {
    func didCheckCameraPermission(_ granted: Bool)
    func didCheckMicrophonePermission(_ granted: Bool)
    func hasEnabledAllPermissions()
    func didDenyPermissionBefore()
}

extension PermissionsDelegate {
    func didCheckCameraPermission(_ granted: Bool) {}
    func didCheckMicrophonePermission(_ granted: Bool) {}
    func didDenyPermissionBefore() {}
}

enum CMPermission {
    case camera
    case microphone
    case location
}

final class PermissionsPresenter: NSObject {
    weak var delegate: PermissionsDelegate?
    var givenPermissions: [CMPermission] = [] {
        didSet {
            dump(givenPermissions)
            if givenPermissions.contains(.camera) && givenPermissions.contains(.microphone) {
                delegate?.hasEnabledAllPermissions()
            }
        }
    }
    
    var deniedPermissions: [CMPermission] = []
    
    init(delegate: PermissionsDelegate) {
        self.delegate = delegate
    }
    
    func checkAllPermissions() {
        checkCameraAccess()
        checkMicrophoneAccess()
    }
    
    func checkCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            givenPermissions.append(.camera)
            delegate?.didCheckCameraPermission(true)
        case .notDetermined, .restricted:
            delegate?.didCheckCameraPermission(false)
        case .denied:
            deniedPermissions.append(.camera)
            delegate?.didCheckCameraPermission(false)
        default:
            break
        }
    }
    
    func requestCameraAccess() {
        if deniedPermissions.contains(.camera) {
            delegate?.didDenyPermissionBefore()
            return
        }
        AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
            self?.checkCameraAccess()
        }
    }
    
    func checkMicrophoneAccess() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            givenPermissions.append(.microphone)
            delegate?.didCheckMicrophonePermission(true)
        case .undetermined:
            delegate?.didCheckMicrophonePermission(false)
        case .denied:
            deniedPermissions.append(.microphone)
            delegate?.didCheckMicrophonePermission(false)
        default:
            break
        }
    }
    
    func requestMicrophoneAccess() {
        if deniedPermissions.contains(.microphone)  {
            guard deniedPermissions.contains(.camera) == false else { return }
            delegate?.didDenyPermissionBefore()
            return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] _ in
            self?.checkMicrophoneAccess()
        }
    }
}
