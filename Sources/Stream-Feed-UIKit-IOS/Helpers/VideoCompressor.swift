//
//  File.swift
//  
//
//  Created by Sherif Shokry on 24/10/2023.
//

import UIKit
import AVFoundation
import Combine

// Compression Result
public enum CompressionResult {
    case onStart
    case onSuccess(URL)
    case onFailure(CompressionError)
    case onCancelled
}

// Compression Interruption Wrapper
public class Compression {
    public init() {}

    public var cancel = false
}

// Compression Error Messages
public struct CompressionError: LocalizedError {
    public let title: String

    init(title: String = "Compression Error") {
        self.title = title
    }
}

public class VideoCompressor {
    private let MAX_BITRATE = Float(2000000)
    // Minimum Video Settings properties
    private let MIN_HEIGHT = 640.0
    private let MIN_WIDTH = 360.0
    
    private var bag = Set<AnyCancellable>()
    
    private let videoCompressionProgress = CurrentValueSubject<Double, Never>(0)
    private let audioCompressionProgress = CurrentValueSubject<Double, Never>(0)
    
    private let compressionProgress = CurrentValueSubject<Double, Never>(0)
    
    private var assetWriter: AVAssetWriter?
    private var assetReader: AVAssetReader?
    // Video and Audio Queue
    private static let videoQueue = "videoQueue"
    private static let audioQueue = "audioQueue"
    
    init() {
        addHandlers()
    }
    
    deinit {
        self.assetWriter = nil
        self.assetReader = nil
    }
    
    private func addHandlers() {
        Publishers.CombineLatest(videoCompressionProgress, audioCompressionProgress)
                .map {($0 + $1) / ($1 > 0 ? 2 : 1)}
                .sink { [weak self] in self?.compressionProgress.send($0) }
                .store(in: &bag)
    }
    
    // Prepare Video Settings like bitrate after the compression and the resolution
    private func getVideoSettings(for track: AVAssetTrack, compressionPercentage: Float, keepOriginalResolution: Bool) -> [String: Any] {
        let bitrate = min(track.estimatedDataRate, MAX_BITRATE)
        // Generate a bitrate based on desired quality
        let newBitrate = getBitrate(bitrate: bitrate, compressionPercentage: compressionPercentage)
        
        // Handle new width and height values
        let videoSize = track.naturalSize
        let newSize = generateWidthAndHeight(width: videoSize.width, height: videoSize.height, keepOriginalResolution: keepOriginalResolution)
        let newWidth = newSize.width
        let newHeight = newSize.height
        // The Video Settings Dictionary
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: newBitrate],
            AVVideoHeightKey: newHeight,
            AVVideoWidthKey: newWidth
        ]
    }
    
    private var getVideoReaderSettings: [String: Any] {
        return [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ]

    }
    
    private func setupReader(for asset: AVAsset) -> AVAssetReader? {
        assetReader = try? AVAssetReader(asset: asset)
        return assetReader
    }
    
    private func setupWriter(to url: URL, with videoInput: AVAssetWriterInput, and audioInput: AVAssetWriterInput) -> AVAssetWriter? {
        assetWriter = try? AVAssetWriter(outputURL: url, fileType: AVFileType.mov)
        assetWriter?.shouldOptimizeForNetworkUse = true
        assetWriter?.add(videoInput)
        assetWriter?.add(audioInput)
        return assetWriter
    }
    
    func compressFile(source: URL,
                      destination: URL,
                      compressionPercentage: Float,
                      keepOriginalResolution: Bool = false,
                      progressHandler: ((Double) -> ())?,
                      completion: @escaping (CompressionResult) -> ()) {
        
        let compressionOperation = Compression()

        // Compression started
        completion(.onStart)
        
        var audioFinished = false
        var videoFinished = false

        let asset = AVAsset(url: source)
        let duration = asset.duration
        let durationTime = CMTimeGetSeconds(duration)
        guard
             let reader = setupReader(for: asset),
             let videoTrack = asset.tracks(withMediaType: .video).first
              else {
                 let msg = "Video Reader, Video Track and Audio Track something went wrong Video Compression won't work properly"
                 completion(.onFailure(CompressionError(title: msg)))
                 return
             }
        let audioTrack = asset.tracks(withMediaType: .audio).first
        let assetReaderVideoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: getVideoReaderSettings)
        let assetReaderAudioOutput: AVAssetReaderTrackOutput? = audioTrack != nil ? AVAssetReaderTrackOutput(track: audioTrack!, outputSettings: nil) : nil
        assetReaderVideoOutput.alwaysCopiesSampleData = false
        assetReaderAudioOutput?.alwaysCopiesSampleData = false
        let outputList = audioTrack != nil ? [assetReaderVideoOutput, assetReaderAudioOutput!] : [assetReaderVideoOutput]
        for output in outputList {
            guard reader.canAdd(output) else {
                let msg = "Video Reader can't add output something went wrong Video Compression won't work properly"
                completion(.onFailure(CompressionError(title: msg)))
                return
            }
            reader.add(output)
        }
        
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: getVideoSettings(for: videoTrack, compressionPercentage: compressionPercentage, keepOriginalResolution: keepOriginalResolution))
        videoInput.transform = videoTrack.preferredTransform

        let videoInputQueue = DispatchQueue(label: VideoCompressor.videoQueue)
        let audioInputQueue = DispatchQueue(label: VideoCompressor.audioQueue)

        guard let writer = setupWriter(to: destination, with: videoInput, and: audioInput) else {
            let msg = "Couldn't generate Writer something went wrong Video Compression won't work properly"
            completion(.onFailure(CompressionError(title: msg)))
            return
        }

        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: CMTime.zero)
        let closeWriter: () -> Void = { [weak self] in
            guard let self = self else { return }
            guard audioFinished && videoFinished else { return }
            
          
            self.assetWriter?.finishWriting(completionHandler: { [weak self] in
                guard let self = self else { return }
                self.assetReader?.cancelReading()
                self.assetWriter?.cancelWriting()
                self.assetReader = nil
                self.assetWriter = nil
                progressHandler?(self.compressionProgress.value)
                completion(.onSuccess(destination))
            })
        }
        // Audio Input Request Media
        audioInput.requestMediaDataWhenReady(on: audioInputQueue) { [weak self] in
            guard let self = self else { return }
            while audioInput.isReadyForMoreMediaData {
                // If there's no more Sample buffer we stop the While loop and mark audioInput as Finished
                guard let sample = assetReaderAudioOutput?.copyNextSampleBuffer() else {
                    guard self.assetWriter != nil, self.assetWriter?.inputs.contains(audioInput) == true else { return }
                    audioInput.markAsFinished()
                    audioFinished = true
                    closeWriter()
                    break
                }
                
                let timeStamp = CMSampleBufferGetPresentationTimeStamp(sample)
                let timeSecond = CMTimeGetSeconds(timeStamp)
                let per = timeSecond / durationTime
                self.audioCompressionProgress.send(per)
                debugPrint("audio progress --- \(per)")
                progressHandler?(self.compressionProgress.value)
                audioInput.append(sample)
            }
        }
        // Video Input Request Media
        videoInput.requestMediaDataWhenReady(on: videoInputQueue) { [weak self] in
            guard let self = self else { return }
            while videoInput.isReadyForMoreMediaData {
                // Observe any cancellation
                if compressionOperation.cancel {
                    self.assetReader?.cancelReading()
                    self.assetWriter?.cancelWriting()
                    completion(.onCancelled)
                    return
                }
                // If there's no more Sample buffer we stop the While loop and mark videoInput as Finished
                guard let sample = assetReaderVideoOutput.copyNextSampleBuffer() else {
                    guard self.assetWriter != nil, self.assetWriter?.inputs.contains(audioInput) == true else { return }
                    videoInput.markAsFinished()
                    videoFinished = true
                    closeWriter()
                    break
                }
                
                let timeStamp = CMSampleBufferGetPresentationTimeStamp(sample)
                let timeSecond = CMTimeGetSeconds(timeStamp)
                let per = timeSecond / durationTime
                self.videoCompressionProgress.send(per)
                debugPrint("video progress --- \(per)")
                progressHandler?(self.compressionProgress.value )
                videoInput.append(sample)
            }
        }
    }
    private func getBitrate(bitrate: Float, compressionPercentage: Float) -> Int {
        
        return Int(bitrate * (compressionPercentage / 100))
    }
    
    private func generateWidthAndHeight(
        width: CGFloat,
        height: CGFloat,
        keepOriginalResolution: Bool
    ) -> (width: Int, height: Int) {
        
        if (keepOriginalResolution) {
            return (Int(width), Int(height))
        }
        
        var newWidth: Int
        var newHeight: Int
        
        if width >= 1920 || height >= 1920 {
            
            newWidth = Int(width * 0.5 / 16) * 16
            newHeight = Int(height * 0.5 / 16 ) * 16
            
        } else if width >= 1280 || height >= 1280 {
            newWidth = Int(width * 0.75 / 16) * 16
            newHeight = Int(height * 0.75 / 16) * 16
        } else if width >= 960 || height >= 960 {
            if(width > height){
                newWidth = Int(MIN_HEIGHT * 0.95 / 16) * 16
                newHeight = Int(MIN_WIDTH * 0.95 / 16) * 16
            } else {
                newWidth = Int(MIN_WIDTH * 0.95 / 16) * 16
                newHeight = Int(MIN_HEIGHT * 0.95 / 16) * 16
            }
        } else {
            newWidth = Int(width * 0.9 / 16) * 16
            newHeight = Int(height * 0.9 / 16) * 16
        }
        
        return (newWidth, newHeight)
    }
    
}
