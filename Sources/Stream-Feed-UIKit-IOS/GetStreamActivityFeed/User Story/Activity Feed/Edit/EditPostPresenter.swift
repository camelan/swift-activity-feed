//
//  EditPostPresenter.swift
//  GetStreamActivityFeed
//
//  Created by Alexey Bukhtin on 28/01/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import Foundation
import GetStream
import UIKit
import Combine

public protocol EditPostViewable: AnyObject {
    func underlineLinks(with dataDetectorURLItems: [DataDetectorURLItem])
    func updateOpenGraphData()
}

public final class EditPostPresenter {
    let flatFeed: FlatFeed
    let imageCompression: Double
    let videoMaximumDurationInMinutes: Double
    let videoCompression: Int
    let timeLineVideoEnabled: Bool
    let logErrorAction: ((String, String) -> Void)?
    let activity: Activity?
    private weak var view: EditPostViewable?
    private var detectedURL: URL?
    private(set) var ogData: OGResponse?
    var videoCompressorManager: VideoCompressorService = VideoCompressorManager()
    var videoCompressionSubject = CurrentValueSubject<CompressionResult, Never>(CompressionResult.onStart)
    var compressionCanceled = false
    
    var mediaItems: [MediaItem] = []
    
    private(set) lazy var dataDetectorWorker: DataDetectorWorker? = try? DataDetectorWorker(types: .link) { [weak self]  in
        self?.updateOpenGraph($0)
    }
    
    private(set) lazy var openGraphWorker = OpenGraphWorker() { [weak self] url, openGraphData, error in
        if let self = self, error == nil {
            self.detectedURL = url
            self.ogData = openGraphData
            self.view?.updateOpenGraphData()
        }
    }
    
    init(flatFeed: FlatFeed,
         view: EditPostViewable,
         activity: Activity? = nil,
         imageCompression: Double,
         videoMaximumDurationInMinutes: Double,
         videoCompression: Int,
         timeLineVideoEnabled: Bool,
         logErrorAction: @escaping ((String, String) -> Void)) {
        self.flatFeed = flatFeed
        self.view = view
        self.activity = activity
        self.imageCompression = imageCompression
        self.videoCompression = videoCompression
        self.videoMaximumDurationInMinutes = videoMaximumDurationInMinutes
        self.timeLineVideoEnabled = timeLineVideoEnabled
        self.logErrorAction = logErrorAction
    }
    
    func save(_ text: String?, completion: @escaping (_ error: Error?) -> Void) async {
        guard Client.shared.currentUser != nil else {
            logErrorAction?("found nil user while posting new feed", "")
            completion(nil)
            return
        }
        let hasMediaItems = mediaItems.count > 0
        
        if hasMediaItems {
            let videoItems = mediaItems.filter({ $0.mediaType == .video })
            guard videoItems.count > 0 else {
                await saveWithMediaItems(text: text, completion: completion)
                return
            }
            handleVideosCompression(videoItems: videoItems, text: text, completion: completion)
        } else {
            saveActivity(text: text, completion: completion)
        }
    }
    
    private func saveWithMediaItems(text: String?, completion: @escaping (_ error: Error?) -> Void) async {
        let mediaFiles = prepareMediaFiles()
        let videoThumbnailFiles = prepareThumbnailFiles()
        do {
            // Upload videoThumbnailFiles
            if !videoThumbnailFiles.isEmpty {
                let thumbnailURLs = try await uploadFilesAsync(files: videoThumbnailFiles)
                updateMediaItemsWithThumbnailURLs(thumbnailURLs)
            }
            

            // Upload other mediaFiles.
            let mediaURLs = try await uploadFilesAsync(files: mediaFiles)
            mediaItems = updateMediaItemsWithMediaURLs(mediaURLs)
          
            saveActivity(text: text, completion: completion)
        } catch let error {
            logErrorAction?("Something went wrong while saving meida items", error.localizedDescription)
            completion(error)
        }
    }
    
    private func uploadFilesAsync(files: [File]) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            Client.shared.upload(files: files) { result in
                switch result {
                case .success(let urls):
                    continuation.resume(returning: urls)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func updateMediaItemsWithThumbnailURLs(_ thumbnailURLs: [URL]) {
        let videoItems = mediaItems.filter { $0.mediaType == .video }
        
        videoItems.enumerated().forEach { index, videoItem in
            guard let mediaItemindex = mediaItems.firstIndex(where: { $0.id == videoItem.id }) else { return }
            mediaItems[mediaItemindex].uploadedVideoThumbnailURL = thumbnailURLs[index]
        }
    }
    
    private func updateMediaItemsWithMediaURLs(_ mediaURLs: [URL]) -> [MediaItem] {
        return mediaItems.enumerated().map { index, mediaItem in
            var updatedMediaItem = mediaItem
            
            switch updatedMediaItem.mediaType {
            case .image:
                updatedMediaItem.uploadedImageURL = mediaURLs[index]
            case .video:
                updatedMediaItem.uploadedVideoURL = mediaURLs[index]
            }
            return updatedMediaItem
        }
    }
    
    private func prepareThumbnailFiles() -> [File] {
        let videoItems = mediaItems.filter { $0.mediaType == .video }
        let files: [File] = videoItems.enumerated().compactMap { index, mediaItem in
            if let compressedThumbnail = mediaItem.videoThumbnail?.compressed(imageCompression) {
                return File(name: "thumbnail\(index)", jpegImage: compressedThumbnail)
            }
            return nil
        }
        return files
    }
    
    private func prepareMediaFiles() -> [File] {
        // Sort the media list such that photos appear before videos.
        let sortedMediaItems = mediaItems.sorted { $0.mediaType.rawValue < $1.mediaType.rawValue }
        mediaItems = sortedMediaItems
        
        let files: [File] = sortedMediaItems.enumerated().compactMap { index, mediaItem in
            switch mediaItem.mediaType {
            case .image:
                if let compressedImage = mediaItem.image?.compressed(imageCompression) {
                    return File(name: "image\(index)", jpegImage: compressedImage)
                }
            case .video:
                if let videoURL = mediaItem.videoURL {
                    return File(name: "video\(videoURL.lastPathComponent)", videoURL: videoURL)
                }
            }
            return nil
        }
        
        return files
    }
    
    private func handleVideosCompression(videoItems: [MediaItem], text: String?, completion: @escaping (_ error: Error?) -> Void) {
        let group = DispatchGroup()
         DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
             videoItems.forEach { mediaItem in
                group.enter()
                if let videoURL = mediaItem.videoURL {
                    self.videoCompressorManager.compressVideoURL(videoURL: videoURL, compressionPrecentage: self.videoCompression) { [weak self]  compressionResult in
                        guard let self = self else { return }
                        switch compressionResult {
                        case .onStart:
                            self.videoCompressionSubject.send(.onStart)
                        case .onSuccess(let uRL):
                            let index = self.mediaItems.firstIndex(where: { $0.id == mediaItem.id }) ?? 0
                            self.mediaItems[index].videoURL = uRL
                            group.leave()
                        case let .onFailure(error):
                            logErrorAction?("[Multimedia] something went wrong with timeline video compression", error.localizedDescription)
                            self.videoCompressionSubject.send(.onFailure(error))
                            group.leave()
                        case .onCancelled:
                            self.videoCompressionSubject.send(.onCancelled)
                            group.leave()
                        }
                    }
                }
                group.wait()
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if !self.compressionCanceled {
                    Task {
                        await self.saveWithMediaItems(text: text, completion: completion)
                    }
                }
                 self.videoCompressionSubject.send(.onSuccess(videoItems[0].videoURL!))
            }
        }
    }
    
    private func saveActivity(text: String?, completion: @escaping (_ error: Error?) -> Void) {
        guard let user = Client.shared.currentUser as? User , (text != nil || mediaItems.count > 0) else {
            completion(nil)
            return
        }
        
        let activity: Activity
        let attachment = ActivityAttachment()
        var tempMediaItems = mediaItems
        
        if let tempMediaItem = tempMediaItems.first {
            switch tempMediaItem.mediaType {
            case .image:
                guard let imageURL = tempMediaItem.uploadedImageURL else { return }
                activity = Activity(actor: user, verb: .post, object: .image(imageURL))
            case .video:
                guard let thumnnailURL = tempMediaItem.uploadedVideoThumbnailURL else { return }
                activity = Activity(actor: user, verb: .post, object: .image(thumnnailURL))
            }
            tempMediaItems.removeFirst()
            activity.text = text
        } else if let text = text {
            activity = Activity(actor: user, verb: .post, object: .text(text))
        } else {
            completion(nil)
            return
        }
        
        if mediaItems.count > 0 {
            activity.media = mediaItems.map({ $0.uploadedMediaItem })
            attachment.imageURLs = tempMediaItems.map({ mediaItem in
                switch mediaItem.mediaType {
                case .image:
                    return mediaItem.uploadedImageURL!
                case .video:
                    return mediaItem.uploadedVideoThumbnailURL!
                }
            })
            activity.attachment = attachment
        }
        
        if let ogData = ogData {
            attachment.openGraphData = ogData
            activity.attachment = attachment
        }
        
        flatFeed.add(activity) { [weak self] result in
            do {
                _ = try result.get()
                completion(nil)
            } catch let error {
                self?.logErrorAction?("Something went wrong with save activity", error.localizedDescription)
                completion(error)
            }
        }
    }
    
    
    
    func updateActivity(with text: String) {
    }
    
    
    
}

extension EditPostPresenter {
    private func updateOpenGraph(_ dataDetectorURLItems: [DataDetectorURLItem]) {
        view?.underlineLinks(with: dataDetectorURLItems)
        
        guard let item = dataDetectorURLItems.first(where: { !openGraphWorker.isBadURL($0.url) }) else {
            detectedURL = nil
            ogData = nil
            openGraphWorker.cancel()
            view?.updateOpenGraphData()
            return
        }
        
        if let detectedURL = detectedURL, detectedURL == item.url {
            return
        }
        
        detectedURL = nil
        ogData = nil
        view?.updateOpenGraphData()
        openGraphWorker.dispatch(item.url)
    }
}
