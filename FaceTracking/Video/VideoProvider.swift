//
//  VideoProvider.swift
//  FaceTracking
//
//  Created by Nino
//

import Foundation
import UIKit
import AVFoundation

enum VideoProviderError: Error {
    case errorConfiguringInputDevice
    case errorStartingRecording
}

protocol VideoProviderDelegate: class {
    func onStartError(error: VideoProviderError)
}

protocol VideoProviding : class {
    var delegate: VideoProviderDelegate? { get set }
    
    func startPreview(frame: CGRect, parent: UIView)
    func stopPreview()
    func startRecording()
    func stopRecording() -> String
}

final class VideoProvider: VideoProviding {
    
    fileprivate let session: AVCaptureSession
    fileprivate let cameraPosition: AVCaptureDevice.Position
    
    weak var delegate: VideoProviderDelegate?
    fileprivate var previewLayer: AVCaptureVideoPreviewLayer?    
    fileprivate var avPlayerLayer: AVPlayerLayer?
    
    init(session: AVCaptureSession = AVCaptureSession(),
         cameraPosition: AVCaptureDevice.Position) {
        self.session = session
        self.cameraPosition = cameraPosition
        initSession()
    }
    
    func startPreview(frame: CGRect, parent: UIView) {
        setupPreview(frame: frame, parent: parent)
        
    }
    
    func stopPreview() {
        
    }
    
    func startRecording() {
        
    }
    
    func stopRecording() -> String {
        return ""
    }
    
    private func setupPreview(frame: CGRect,
                              parent: UIView) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.frame = frame
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        guard let previewLayer = previewLayer else { return }
        parent.layer.addSublayer(previewLayer)
        parent.layer.cornerRadius = 10.0
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
                delegate?.onStartError(error: .errorConfiguringInputDevice)
                return
        }
        
        session.sessionPreset = AVCaptureSessionPresetHigh
        session.addInput(camera)
        session.addInput(microphone)
        
        //TODO: Add output (figure this one out)
    }
    
}
