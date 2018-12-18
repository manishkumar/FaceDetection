//
//  ViewController.swift
//  FaceTracking
//
//  Created by Nino
//

import UIKit
import AVFoundation
import Photos

struct Platform {
    static let isSimulator: Bool = {
        var isSim = false
        #if arch(i386) || arch(x86_64)
        isSim = true
        #endif
        return isSim
    }()
}

class ViewController: UIViewController {
    
    fileprivate let captureSession = AVCaptureSession()
    fileprivate let movieOutput = AVCaptureMovieFileOutput()
    fileprivate var previewLayer: AVCaptureVideoPreviewLayer?
    fileprivate var activeInput: AVCaptureDeviceInput?
    fileprivate var outputURL: URL?
    fileprivate let avPlayer = AVPlayer()
    fileprivate var avPlayerLayer: AVPlayerLayer?
    
    var faceDetector: FaceDetecting?
    
    
    lazy var frontCamera: AVCaptureDevice? = {
        guard let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] else { return nil }
        return devices.filter { $0.position == .front }.first
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let camera = frontCamera else { return }
        faceDetector = FaceDetector(captureDevice: camera)
        faceDetector?.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !Platform.isSimulator {
            if setupSession() {
                setupPreview()
                startSession()
                startRecording()
                faceDetector?.start()
            }
        }
    }
    
    func setupPreview() {
        view.layer.cornerRadius = 10.0
        view.clipsToBounds = true
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.frame
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        guard let layer = previewLayer else { return }
        view.layer.addSublayer(layer)
        layer.cornerRadius = 10.0
        
    }
    
    func setupSession() -> Bool {
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        let microphone = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
        
        do {
            let input = try AVCaptureDeviceInput(device: frontCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                activeInput = input
            }
            
            let micInput = try AVCaptureDeviceInput(device: microphone)
            if captureSession.canAddInput(micInput) {
                captureSession.addInput(micInput)
            }
        } catch {
            print("Error setting device video input: \(error)")
            return false
        }
        
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }
        
        return true
    }
    
    func startSession() {
        if !captureSession.isRunning {
            videoQueue().async {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            videoQueue().async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    func videoQueue() -> DispatchQueue {
        return DispatchQueue.main
    }
    
    func currentVideoOrientation() -> AVCaptureVideoOrientation {
        var orientation: AVCaptureVideoOrientation
        
        switch UIDevice.current.orientation {
        case .portrait:
            orientation = AVCaptureVideoOrientation.portrait
        case .landscapeRight:
            orientation = AVCaptureVideoOrientation.landscapeLeft
        case .portraitUpsideDown:
            orientation = AVCaptureVideoOrientation.portraitUpsideDown
        default:
            orientation = AVCaptureVideoOrientation.landscapeRight
        }
        
        return orientation
    }
    
    func startRecording() {
        if movieOutput.isRecording == false {
            let connection = movieOutput.connection(withMediaType: AVMediaTypeVideo)            
            
            if let _ = connection?.isVideoOrientationSupported {
                connection?.videoOrientation = currentVideoOrientation()
            }
            
            if let _ = connection?.isVideoStabilizationSupported {
                connection?.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.auto
            }
            
            guard let device = activeInput?.device else { return }
            
            if (device.isSmoothAutoFocusSupported) {
                do {
                    try device.lockForConfiguration()
                    device.isSmoothAutoFocusEnabled = false
                    device.unlockForConfiguration()
                } catch {
                    print("Error setting configuration: \(error)")
                }
            }
            outputURL = recordedFileUrl()
            movieOutput.startRecording(toOutputFileURL: outputURL, recordingDelegate: self)
        }
        else {
            stopRecording()
        }
    }
    
    func stopRecording() {
        if movieOutput.isRecording == true {
            movieOutput.stopRecording()
        }
    }
    
    func recordedFileUrl() -> URL? {
        let directory = NSTemporaryDirectory() as NSString
        if directory != "" {
            let path = directory.appendingPathComponent(NSUUID().uuidString + ".mp4")
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}


extension ViewController: AVCaptureFileOutputRecordingDelegate {
    
    func capture(_ output: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        print("finished recording")
    }
    
    func capture(_ output: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        print("Starting")
    }
}


extension ViewController: FaceDetectionDelegate {
    func onError(error: FaceDetectionError) {
        switch error {
        case .ErrorCreatingDeviceInput:
            print("Error: ErrorCreatingDeviceInput")
        case .FaceOutOfFrame:
            print("Error: FaceOutOfFrame")
        case .FaceTilted:
            print("Error: FaceTilted")
        }
        
    }
}
