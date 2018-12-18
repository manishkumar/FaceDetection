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
    case ErrorCreatingDeviceInput
    case FaceOutOfFrame
    case FaceTilted
}

protocol FaceDetectionDelegate: class {
    func onError(error: FaceDetectionError)
}

protocol FaceDetecting : class {
    var delegate: FaceDetectionDelegate? { get set }
    
    func start()
    func stop()
}

final class FaceDetector: NSObject, FaceDetecting {
    
    fileprivate struct Constants {
        static let tiltAngleThresholdForError: Float = 12
        static let outputQueue = "output.queue"
    }
    
    weak var delegate: FaceDetectionDelegate?
    let session = AVCaptureSession()
    let captureDevice: AVCaptureDevice
    let detector = CIDetector(ofType: CIDetectorTypeFace,
                              context: nil,
                              options: [CIDetectorAccuracy : CIDetectorAccuracyHigh])
    let queue = DispatchQueue(label: Constants.outputQueue)
    
    init(captureDevice: AVCaptureDevice) {
        self.captureDevice = captureDevice
        super.init()
        self.configure()
    }
    
    private func configure() {
        session.sessionPreset = AVCaptureSessionPresetHigh
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            
            let output = AVCaptureVideoDataOutput()
            let outputKey = kCVPixelBufferPixelFormatTypeKey as String
            let outputValue = NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            output.videoSettings = [outputKey : outputValue]
            output.alwaysDiscardsLateVideoFrames = true

            session.beginConfiguration()
            
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            
            output.setSampleBufferDelegate(self, queue: queue)
        } catch {
            delegate?.onError(error: .ErrorCreatingDeviceInput)
        }
    }
    
    func start() {
        session.startRunning()
    }
    
    func stop() {
        session.stopRunning()
    }
    
}

extension FaceDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    

    func captureOutput(_ captureOutput: AVCaptureOutput!,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
                       from connection: AVCaptureConnection!) {
        print("Capturing output")
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault,
                                                              sampleBuffer,
                                                              kCMAttachmentMode_ShouldPropagate) as? [String : Any] else { return }
        let ciImage = CIImage(cvImageBuffer: pixelBuffer,
                              options: attachments)
        let options: [String : Any] = [CIDetectorImageOrientation: exifOrientation(orientation: UIDevice.current.orientation),
                                       CIDetectorEyeBlink: true,
                                       CIDetectorReturnSubFeatures: true]
        guard let features = detector?.features(in: ciImage, options: options) else { return }
        
        if !(features.count > 0) {
            delegate?.onError(error: .FaceOutOfFrame)
            return
        }
        
        for feature in features {
            if let faceFeature = feature as? CIFaceFeature {
                if !faceFeature.hasMouthPosition {
                    delegate?.onError(error: .FaceOutOfFrame)
                } else if abs(faceFeature.faceAngle) > Constants.tiltAngleThresholdForError {
                    delegate?.onError(error: .FaceTilted)
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
