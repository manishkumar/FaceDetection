//  FaceDetector.swift
//
//  Created by Nino
//

import Foundation
import AVFoundation
import UIKit

protocol FaceDetectionDelegate: class {
    func faceOutOfFrame()
    func faceTilted()
}

protocol FaceDetecting : class {
    var camera: AVCaptureDevice? { get set }
    var delegate: FaceDetectionDelegate? { get set }
    func start()
    func stop()
}


final class FaceDetector: NSObject, FaceDetecting {
    
    let faceDetector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: nil,
                                  options: [CIDetectorAccuracy : CIDetectorAccuracyHigh])
    weak var camera: AVCaptureDevice?
    weak var delegate: FaceDetectionDelegate?
    
    func start() {
        
    }
    
    func stop() {
        
    }
    
}

extension FaceDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput!,
                       didDrop sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault,
                                                        sampleBuffer,
                                                        kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!,
                              options: attachments as! [String : Any]?)
        let options: [String : Any] = [CIDetectorImageOrientation: exifOrientation(orientation: UIDevice.current.orientation),
                                       CIDetectorEyeBlink: true,
                                       CIDetectorReturnSubFeatures: true]
        let allFeatures = faceDetector?.features(in: ciImage, options: options)
        guard let features = allFeatures else { return }
        
        if !(features.count > 0) {
            delegate?.faceOutOfFrame()
            return
        }
        
        for feature in features {
            if let faceFeature = feature as? CIFaceFeature {
                if !faceFeature.hasMouthPosition {
                    delegate?.faceOutOfFrame()
                } else if abs(faceFeature.faceAngle) > 12 {
                    delegate?.faceTilted()
                }
            }
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
