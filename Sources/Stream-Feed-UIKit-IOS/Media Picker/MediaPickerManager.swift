//
//  File.swift
//  
//
//  Created by Sherif Shokry on 12/10/2023.
//

import UIKit
import PhotosUI

enum NSItemProviderError: Error {
    case couldnotLoadObject(NSItemProvider?)
    case failedToLoadObject(Error)
}

protocol PHImagePickerDelegate: AnyObject {
    func didSelect(mediaItems: [MediaItem])
}

class ImagePicker: NSObject {
    private let picker: PHPickerViewController
    private weak var presentationController: UIViewController?
    private weak var delegate: PHImagePickerDelegate?
    
    public init(presentationController: UIViewController, delegate: PHImagePickerDelegate) {
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        configuration.filter = .any(of: [.images, .videos])
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .automatic
        
        picker = PHPickerViewController(configuration: configuration)
        super.init()
        
        self.presentationController = presentationController
        self.delegate = delegate
        picker.delegate = self
    }
    
    public func openGallery() {
        presentationController?.present(self.picker, animated: true)
    }
}

extension ImagePicker: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        var mediaItems: [MediaItem] = []
        guard !results.isEmpty else {
            picker.dismiss(animated: true, completion: nil)
            return
        }
        for result in results {
            let itemProvider = result.itemProvider
            
            if itemProvider.hasItemConformingToTypeIdentifier("public.movie") {
                getVideo(itemProvider: itemProvider) { result in
                    do {
                        let pickedVideoURL = try result.get()
                        let mediaItem = MediaItem(id: UUID().uuidString, mediaType: .video, image: nil, url: pickedVideoURL)
                        mediaItems.append(mediaItem)
                        self.delegate?.didSelect(mediaItems: mediaItems)
                    }
                    catch {
                        print("BNBN Video!!")
                    }
                    picker.dismiss(animated: true, completion: nil)
                }
            } else {
                getMediaImage(itemProvider: itemProvider) { [weak self] result in
                    guard let self else { return }
                    do {
                        let pickedImage = try result.get()
                        let mediaItem = MediaItem(id: UUID().uuidString, mediaType: .photo, image: pickedImage, url: nil)
                        mediaItems.append(mediaItem)
                        self.delegate?.didSelect(mediaItems: mediaItems)
                    } catch {
                        print("BNBN Image!!")
                    }
                    
                    picker.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
    
    private func getMediaImage(itemProvider: NSItemProvider, completion: @escaping ((Result<UIImage, NSItemProviderError>) -> Void)) {
        itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
            guard error == nil else {
                completion(.failure(.failedToLoadObject(error!)))
                return
            }
            guard let data = data , let image = UIImage(data: data) else {
                completion(.failure(.couldnotLoadObject(itemProvider)))
                return
            }
            DispatchQueue.mainAsyncIfNeeded {
                completion(.success(image))
            }
        }
    }
    
    func getVideo(itemProvider: NSItemProvider, completion: @escaping ((Result<URL, NSItemProviderError>) -> Void)) {
        let movie = UTType.movie.identifier
        itemProvider.loadFileRepresentation(forTypeIdentifier: movie) { videoURL, error in
            guard error == nil else {
                completion(.failure(.failedToLoadObject(error!)))
                return
            }
            guard let videoURL = videoURL else {
                completion(.failure(.couldnotLoadObject(itemProvider)))
                return
            }
            let directory = NSTemporaryDirectory()
            let fileName = NSUUID().uuidString.appending(".mov")
            if let copiedURLFile = NSURL.fileURL(withPathComponents: [directory, fileName]) {
                do {
                    try FileManager.default.copyItem(at: videoURL, to: copiedURLFile)
                    DispatchQueue.main.async {
                        completion(.success(copiedURLFile))
                    }
                } catch {
                    completion(.failure(.failedToLoadObject(error)))
                }
            }
        }
    }
}

extension ImagePicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func openCamera() {
        let imagePickerViewController = UIImagePickerController()
        imagePickerViewController.sourceType = .camera
        imagePickerViewController.delegate = self
        imagePickerViewController.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        imagePickerViewController.cameraCaptureMode = .photo
        imagePickerViewController.cameraDevice = .front
        imagePickerViewController.allowsEditing = true
            
        if UIImagePickerController.isFlashAvailable(for: .front) {
            imagePickerViewController.cameraFlashMode = .on
        }
        
        presentationController?.present(imagePickerViewController, animated: true)
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        var mediaItems: [MediaItem] = []
        
        let mediaType = info[UIImagePickerController.InfoKey.mediaType] as! String
        switch mediaType {
        case UTType.image.identifier:
            // Handle image selection result
            if let editedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {
                let mediaItem = MediaItem(id: UUID().uuidString, mediaType: .photo, image: editedImage, url: nil)
                mediaItems.append(mediaItem)
                delegate?.didSelect(mediaItems: mediaItems)
            } else if let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                let mediaItem = MediaItem(id: UUID().uuidString, mediaType: .photo, image: originalImage, url: nil)
                mediaItems.append(mediaItem)
                delegate?.didSelect(mediaItems: mediaItems)
            }
        case UTType.movie.identifier:
            // Handle video selection result
            if let videoFileURL = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
                let mediaItem = MediaItem(id: UUID().uuidString, mediaType: .video, image: nil, url: videoFileURL)
                mediaItems.append(mediaItem)
                delegate?.didSelect(mediaItems: mediaItems)
            }
        default:
            print("Mismatched type: \(mediaType)")
        }
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
