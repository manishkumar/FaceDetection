//
//  FaceDetector.swift
//  FaceTracking
//
//  Created by Nino
//

import Foundation
import AVFoundation
import UIKit

enum FaceDetectionError: Error {
    case FaceOutOfFrame
    case FaceTilted
}

protocol FaceDetectionDelegate: class {
    func onError(error: FaceDetectionError)
}

protocol FaceDetecting : class {
    var delegate: FaceDetectionDelegate? { get set }
    var isRunning: Bool { get }
    
    func start()
    func stop()
    func captureOutput(sampleBuffer: CMSampleBuffer)    
}

final class FaceDetector: NSObject, FaceDetecting {
    
    fileprivate struct Constants {
        static let tiltAngleThresholdForError: Float = 12
    }
    
    var isRunning: Bool = false
    weak var delegate: FaceDetectionDelegate?
    let detector = CIDetector(ofType: CIDetectorTypeFace,
                              context: nil,
                              options: [CIDetectorAccuracy : CIDetectorAccuracyHigh])
    
    override init() {
        super.init()
    }
    
    func start() {
        isRunning = true
    }
    
    func stop() {
        isRunning = false
    }
    
}

extension FaceDetector {
    func captureOutput(sampleBuffer: CMSampleBuffer) {
        if !isRunning {
            return
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate) as? [String : Any] else { return }
        
        let ciImage = CIImage(cvImageBuffer: pixelBuffer, options: attachments)
        let options: [String : Any] = [CIDetectorImageOrientation: exifOrientation(orientation: UIDevice.current.orientation),
                                       CIDetectorEyeBlink: true,
                                       CIDetectorReturnSubFeatures: true]
        
        let features = detector?.features(in: ciImage, options: options)
        guard let feature = features?.first as? CIFaceFeature else {
            delegate?.onError(error: .FaceOutOfFrame)
            return
        }
        
        if !feature.hasMouthPosition {
            delegate?.onError(error: .FaceOutOfFrame)
        } else if abs(feature.faceAngle) > Constants.tiltAngleThresholdForError {
            delegate?.onError(error: .FaceTilted)
        }
    }
    
    func exifOrientation(orientation: UIDeviceOrientation) -> Int {
        switch orientation {
        case .portraitUpsideDown:
            return 8
        case .landscapeLeft:
            return 3
        case .landscapeRight:
            return 1
        default:
            return 6
        }
    }
}
