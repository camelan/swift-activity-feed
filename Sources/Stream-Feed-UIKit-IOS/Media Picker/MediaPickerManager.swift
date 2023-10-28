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

class MediaPicker: NSObject {
    private let picker: PHPickerViewController
    private weak var presentationController: UIViewController?
    private weak var delegate: PHImagePickerDelegate?
    let logErrorAction: ((String, String) -> Void)?
    var timelineVideoEnabled: Bool
    var videoMaximumDurationInMinutes: Double = 2.0
    
    public init(presentationController: UIViewController,
                delegate: PHImagePickerDelegate,
                timelineVideoEnabled: Bool,
                logErrorAction: ((String, String) -> Void)?) {
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        configuration.filter = timelineVideoEnabled ? .any(of: [.images, .videos]) : .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .automatic
        self.logErrorAction = logErrorAction
        self.timelineVideoEnabled = timelineVideoEnabled
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

extension MediaPicker: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        var mediaItems: [MediaItem] = []
        guard !results.isEmpty else {
            dismiss(picker: picker)
            return
        }
        for result in results {
            let itemProvider = result.itemProvider
            
            if itemProvider.hasItemConformingToTypeIdentifier("public.movie") {
                getVideo(itemProvider: itemProvider) { [weak self] result in
                    guard let self else { return }
                    do {
                        let pickedVideoURL = try result.get()
                        guard isVideoDurationValid(pickedVideoURL: pickedVideoURL) else {
                            self.logErrorAction?("Error: Picked video duration exceeds the maximum allowed duration.",
                                                 "picked video duration: \(getVideoDuration(forUrl: pickedVideoURL)) seconds")
                            dismiss(picker: picker)
                            return
                        }
                        
                        let videoThumbnail = self.getThumbnailImage(forUrl: pickedVideoURL)
                        let mediaItem = MediaItem(id: UUID().uuidString, mediaType: .video, image: nil, videoURL: pickedVideoURL, videoThumbnail: videoThumbnail)
                        mediaItems.append(mediaItem)
                        self.delegate?.didSelect(mediaItems: mediaItems)
                    }
                    catch {
                        self.logErrorAction?("[Media Picker] something went wrong when picked video item",
                                             "error: \(error.localizedDescription)")
                    }
                    dismiss(picker: picker)
                }
            } else {
                getMediaImage(itemProvider: itemProvider) { [weak self] result in
                    guard let self else { return }
                    do {
                        let pickedImage = try result.get()
                        let mediaItem = MediaItem(id: UUID().uuidString, mediaType: .image, image: pickedImage, videoURL: nil, videoThumbnail: nil)
                        mediaItems.append(mediaItem)
                        DispatchQueue.mainAsyncIfNeeded { [weak self] in
                            guard let self else { return }
                            self.delegate?.didSelect(mediaItems: mediaItems)
                        }
                    } catch {
                        self.logErrorAction?("[Media Picker] something went wrong when picked image item",
                                             "error: \(error.localizedDescription)")
                    }
                    
                    dismiss(picker: picker)
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

extension MediaPicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func openCamera() {
        let imagePickerViewController = UIImagePickerController()
        imagePickerViewController.sourceType = .camera
        imagePickerViewController.delegate = self
        let mediaTypes = timelineVideoEnabled ? [UTType.image.identifier, UTType.movie.identifier] : [UTType.image.identifier]
        imagePickerViewController.mediaTypes = mediaTypes
        imagePickerViewController.cameraCaptureMode = .photo
        imagePickerViewController.cameraDevice = .front
        imagePickerViewController.allowsEditing = true
        imagePickerViewController.videoMaximumDuration = videoMaximumDurationInMinutes * 60
            
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
                let mediaItem = MediaItem(id: UUID().uuidString, mediaType: .image, image: editedImage, videoURL: nil, videoThumbnail: nil)
                mediaItems.append(mediaItem)
                delegate?.didSelect(mediaItems: mediaItems)
            } else if let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                let mediaItem = MediaItem(id: UUID().uuidString, mediaType: .image, image: originalImage, videoURL: nil, videoThumbnail: nil)
                mediaItems.append(mediaItem)
                delegate?.didSelect(mediaItems: mediaItems)
            }
        case UTType.movie.identifier:
            // Handle video selection result
            if let videoFileURL = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
                guard isVideoDurationValid(pickedVideoURL: videoFileURL) else {
                    self.logErrorAction?("Error: Picked video duration exceeds the maximum allowed duration.",
                                         "picked video duration: \(getVideoDuration(forUrl: videoFileURL)) seconds")
                    dismiss(picker: picker)
                    return
                }
                
                let videoThumbnail = getThumbnailImage(forUrl: videoFileURL)
                let mediaItem = MediaItem(id: UUID().uuidString, mediaType: .video, image: nil, videoURL: videoFileURL, videoThumbnail: videoThumbnail)
                mediaItems.append(mediaItem)
                delegate?.didSelect(mediaItems: mediaItems)
            }
        default:
            self.logErrorAction?("[Media Picker] Mismatched type",
                                 "mediaType: \(mediaType)")
        }
        dismiss(picker: picker)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(picker: picker)
    }
}

extension MediaPicker {
    private func getThumbnailImage(forUrl url: URL) -> UIImage? {
        let asset: AVAsset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        
        do {
            let thumbnailImage = try imageGenerator.copyCGImage(at: CMTimeMake(value: 1, timescale: 60), actualTime: nil)
            return UIImage(cgImage: thumbnailImage)
        } catch let error {
            self.logErrorAction?("[Media Picker] something went wrong while getting thumbnail image",
                                 "error: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func isVideoDurationValid(pickedVideoURL: URL) -> Bool {
        let videoMaximumDurationInSeconds = videoMaximumDurationInMinutes * 60
        let pickedVideoDurationInSeconds = getVideoDuration(forUrl: pickedVideoURL)
        
        if pickedVideoDurationInSeconds <= videoMaximumDurationInSeconds, pickedVideoDurationInSeconds >= 1 {
            return true
        } else {
            return false
        }
    }
    
    private func getVideoDuration(forUrl url: URL) -> Double {
        let asset = AVURLAsset(url: url)
        let videoDuration = asset.duration
        let videoDurationInSeconds = CMTimeGetSeconds(videoDuration)
        
        return videoDurationInSeconds
    }
    
    private func dismiss(picker: PHPickerViewController) {
        DispatchQueue.mainAsyncIfNeeded {
            picker.dismiss(animated: true, completion: nil)
        }
    }
    
    private func dismiss(picker: UIImagePickerController) {
        DispatchQueue.mainAsyncIfNeeded {
            picker.dismiss(animated: true, completion: nil)
        }
    }
}
