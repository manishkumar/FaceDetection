//
//  VideoProvider.swift
//  FaceTracking
//
//  Created by Nino
//

import Foundation
import UIKit
import AVFoundation

enum VideoRecorderError: Error {
    case errorConfiguringInputDevice
    case errorStartingRecording
    case faceDetectionError(error: FaceDetectionError)
}

protocol VideoRecorderDelegate: class {
    func onError(error: VideoRecorderError)
}

protocol VideoRecording : class {
    var delegate: VideoRecorderDelegate? { get set }
    
    func startPreview(frame: CGRect, parent: UIView)
    func stopPreview()
    func startRecording()
    func stopRecording() -> String
}

final class VideoRecorder: NSObject, VideoRecording {
    
    fileprivate struct Constants {
        static let outputQueue = "output.queue"
    }
    
    fileprivate let session: AVCaptureSession
    fileprivate let cameraPosition: AVCaptureDevice.Position
    fileprivate let queue = DispatchQueue(label: Constants.outputQueue)
    
    weak var delegate: VideoRecorderDelegate?
    fileprivate var previewLayer: AVCaptureVideoPreviewLayer?    
    fileprivate var avPlayerLayer: AVPlayerLayer?
    fileprivate var faceDetector: FaceDetecting?
    
    init(session: AVCaptureSession = AVCaptureSession(),
         cameraPosition: AVCaptureDevice.Position,
         requireFaceDetection: Bool = false) {
        self.session = session
        self.cameraPosition = cameraPosition
        super.init()
        
        self.faceDetector = FaceDetector()
        self.faceDetector?.delegate = self
        initSession()
    }
    
    func startPreview(frame: CGRect, parent: UIView) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.frame = frame
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        guard let previewLayer = previewLayer else { return }
        parent.layer.addSublayer(previewLayer)
        session.startRunning()
        faceDetector?.start()
    }
    
    func stopPreview() {
        
    }
    
    func startRecording() {
        
    }
    
    func stopRecording() -> String {
        return ""
    }
    
    private func initSession() {
        
        let cameraDevice: AVCaptureDevice? = {
            guard let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] else { return nil }
            return devices.filter { $0.position == cameraPosition }.first
        }()
        
        let camera = try? AVCaptureDeviceInput(device: cameraDevice)
        let microphone = try? AVCaptureDeviceInput(device: AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio))
        
        guard let cameraInput = camera,
            let microphoneInput = microphone,
            session.canAddInput(cameraInput),
            session.canAddInput(microphoneInput) else {
                delegate?.onError(error: .errorConfiguringInputDevice)
                return
        }
        
        session.sessionPreset = AVCaptureSessionPresetHigh
        session.addInput(camera)
        session.addInput(microphone)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey : Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)]
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: queue)
        
        session.addOutput(videoOutput)
        session.addOutput(audioOutput)
    }
}


extension VideoRecorder: AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        faceDetector?.captureOutput(sampleBuffer: sampleBuffer)
    }
}

extension VideoRecorder: FaceDetectionDelegate {
    func onError(error: FaceDetectionError) {
        delegate?.onError(error: .faceDetectionError(error: error))
    }
}
