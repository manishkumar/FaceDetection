//
//  ViewController.swift
//  AutoCamera
//
//  Created by Nino
//

import UIKit
import AVFoundation

class ViewController2: UIViewController {
//class ViewController: UIViewController {
    var session: AVCaptureSession?
    var borderLayer: CAShapeLayer?
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        var previewLay = AVCaptureVideoPreviewLayer(session: self.session!)
        previewLay?.videoGravity = AVLayerVideoGravityResizeAspectFill
        return previewLay
    }()
    
    lazy var frontCamera: AVCaptureDevice? = {
        guard let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] else { return nil }
        return devices.filter { $0.position == .front }.first
    }()
    
    let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy : CIDetectorAccuracyHigh])
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        //previewLayer?.frame = view.frame
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let previewLayer = previewLayer else { return }
        
        //view.layer.addSublayer(previewLayer)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sessionPrepare()
        session?.startRunning()
    }
    
    //Prepare camera session
    func sessionPrepare() {
        session = AVCaptureSession()
        
        guard let session = session, let captureDevice = frontCamera else { return }
        
        session.sessionPreset = AVCaptureSessionPresetPhoto
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            session.beginConfiguration()
            
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            output.alwaysDiscardsLateVideoFrames = true
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            
            let queue = DispatchQueue(label: "output.queue")
            output.setSampleBufferDelegate(self, queue: queue)
        } catch {
            print("error with creating AVCaptureDeviceInput")
        }
    }        
}

extension ViewController2: AVCaptureVideoDataOutputSampleBufferDelegate {
//extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
        let options: [String : Any] = [CIDetectorImageOrientation: exifOrientation(orientation: UIDevice.current.orientation),
                                       CIDetectorEyeBlink: true,
                                       CIDetectorReturnSubFeatures: true]
        let allFeatures = faceDetector?.features(in: ciImage, options: options)
        guard let features = allFeatures else { return }
        
        if !(features.count > 0) {
            print("Place your face inside the frame")
            return
        }
        
        for feature in features {
            if let faceFeature = feature as? CIFaceFeature {
                if !faceFeature.hasMouthPosition {
                    print("Please face camera")
                } else if abs(faceFeature.faceAngle) > 12 {
                    print("Please don't tilt your head")
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
