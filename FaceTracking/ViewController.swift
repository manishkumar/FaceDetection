//
//  ViewController.swift
//  AutoCamera
//
//  Created by Nino
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

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
        previewLayer?.frame = view.frame
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let previewLayer = previewLayer else { return }
        
        view.layer.addSublayer(previewLayer)
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

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
        let options: [String : Any] = [CIDetectorImageOrientation: exifOrientation(orientation: UIDevice.current.orientation),
                                       CIDetectorEyeBlink: true,
                                       CIDetectorReturnSubFeatures: true]
        let allFeatures = faceDetector?.features(in: ciImage, options: options)
        guard let features = allFeatures else { return }
        
        for feature in features {
            if let faceFeature = feature as? CIFaceFeature {
                //let featureDetails = ["Has mouth position: \(faceFeature.hasMouthPosition)"]
                //print("featureDetails.joined(separator: "\n")")
                if(faceFeature.hasLeftEyePosition && faceFeature.hasRightEyePosition) {
                    let leftEyeCenter = faceFeature.leftEyePosition
                    let rightEyeCenter = faceFeature.rightEyePosition
                    
                    let simpleDistance = rightEyeCenter.x - leftEyeCenter.x
                    //This finds the distance simply by comparing the x coordinates of the two pupils
                    
                    //print("Simple distance = \(simpleDistance)")
                    let complexDistance = fabsf(sqrtf(powf(Float(leftEyeCenter.y - rightEyeCenter.y), 2) + powf(Float(rightEyeCenter.x - leftEyeCenter.x), 2)))
                    //This will return the diagonal distance between the two pupils allowing for greater distance if the pupils are not perfectly level.
                }
                
                if (!faceFeature.hasMouthPosition || abs(faceFeature.faceAngle) > 12) {
                    print("Please face camera without tilting your head")
                }
            }
        }
        
        if features.count == 0 {
            print("Place your face in the frame")
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
