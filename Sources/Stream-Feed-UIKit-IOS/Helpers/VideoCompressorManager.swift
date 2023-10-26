//
//  VideoCompressorManager.swift
//  
//
//  Created by Sherif Shokry on 24/10/2023.
//

import Foundation

protocol VideoCompressorService {
    func compressVideoURL(videoURL: URL, compressionPrecentage: Int, completion: @escaping ((CompressionResult) -> Void))
}

class VideoCompressorManager: VideoCompressorService {
    var compressor = VideoCompressor()

    func compressVideoURL(videoURL: URL, compressionPrecentage: Int, completion: @escaping ((CompressionResult) -> Void)) {
        compressor = VideoCompressor()
        guard let data = try? Data(contentsOf: videoURL) else {
            return
        }
        let originalFileSize = Double(data.count / 1048576)
        do {
            let documentDirectory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let compressedURL = documentDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            compressor.compressFile(source: videoURL, destination: compressedURL, compressionPercentage: Float(compressionPrecentage)) { progress in
            } completion: { result in
                switch result {
                case .onSuccess(let path):
                    guard let compressedData = try? Data(contentsOf: path) else {
                        return
                    }
                    let compressedFileSize = Double(compressedData.count / 1048576)
                    let selectedVideoUrl = originalFileSize > compressedFileSize ? compressedURL : videoURL
                    DispatchQueue.main.async {
                        completion(.onSuccess(selectedVideoUrl))
                    }
                case .onStart:
                    DispatchQueue.main.async {
                        completion(.onStart)
                    }
                case .onFailure(let error):
                    DispatchQueue.main.async {
                        completion(.onFailure(error))
                    }
                case .onCancelled:
                    DispatchQueue.main.async {
                        completion(.onCancelled)
                    }
                }
            }
        } catch {
            completion(.onCancelled)
        }
    }

}
