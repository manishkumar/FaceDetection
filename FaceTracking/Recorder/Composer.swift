//
//  Composer.swift
//  FaceTracking
//
//  Created by Nino
//

import Foundation
import AVFoundation

struct Composer {

    static func compose(videoURL: URL, outputURL: URL, completion: @escaping (URL?, Error?) -> ()) {

        let asset = AVURLAsset(url: videoURL)

        let composition = AVMutableComposition()
        composition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)

        guard let clipVideoTrack = asset.tracks(withMediaType: AVMediaTypeVideo).first else {
            fatalError("failed to get track.")
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = CGSize(width: clipVideoTrack.naturalSize.height,
                                             height: clipVideoTrack.naturalSize.width)
        videoComposition.frameDuration = CMTimeMake(1, 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration)

        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: clipVideoTrack)
        let t1 = CGAffineTransform(translationX: clipVideoTrack.naturalSize.height, y: 0)
        let t2 = t1.rotated(by: .pi / 2)

        let finalTransform = t2
        transformer.setTransform(finalTransform, at: kCMTimeZero)
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            fatalError("failed to create session.")
        }
        exporter.videoComposition = videoComposition
        exporter.outputURL = outputURL
        exporter.outputFileType = AVFileTypeQuickTimeMovie

        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                completion(exporter.outputURL, nil)
            default:
                completion(nil, exporter.error)
            }
        }
    }
}
