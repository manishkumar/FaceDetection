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
        
        let deviceInput = try? AVCaptureDeviceInput(device: captureDevice)
        let output = AVCaptureVideoDataOutput()
        let outputKey = kCVPixelBufferPixelFormatTypeKey as String
        let outputValue = NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        output.videoSettings = [outputKey : outputValue]
        output.alwaysDiscardsLateVideoFrames = true
        
        session.beginConfiguration()
        guard session.canAddInput(deviceInput),
            session.canAddOutput(output) else {
                delegate?.onError(error: .ErrorCreatingDeviceInput)
                return
        }
        
        session.addInput(deviceInput)
        session.addOutput(output)
        session.commitConfiguration()
        output.setSampleBufferDelegate(self, queue: queue)
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
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault,
                                                              sampleBuffer,
                                                              kCMAttachmentMode_ShouldPropagate) as? [String : Any] else { return }
        let ciImage = CIImage(cvImageBuffer: pixelBuffer,
                              options: attachments)
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