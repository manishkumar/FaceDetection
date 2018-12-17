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
    fileprivate var previewLayer: AVCaptureVideoPreviewLayer!
    fileprivate var activeInput: AVCaptureDeviceInput!
    fileprivate var outputURL: URL!
    fileprivate let avPlayer = AVPlayer()
    fileprivate var avPlayerLayer: AVPlayerLayer!
    fileprivate var faceDetector: FaceDetecting?
    
    lazy var frontCamera: AVCaptureDevice? = {
        guard let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] else { return nil }
        return devices.filter { $0.position == .front }.first
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard let frontCamera = frontCamera else { return }
        faceDetector = FaceDetector(captureDevice: frontCamera)
        faceDetector?.delegate = self
        faceDetector?.start()
        
        /*if !Platform.isSimulator {
            if setupSession() {
                setupPreview()
                startSession()
                startRecording()
                
                Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(timerAction), userInfo: nil, repeats: false)
            }
        }*/
    }
    
    // called every time interval from the timer
    func timerAction() {
        stopRecording()
    }
    func setupPreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = self.view.frame
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        self.view.layer.addSublayer(previewLayer)
        previewLayer.cornerRadius = 25.0
        self.view.layer.cornerRadius = 25.0
        self.view.clipsToBounds = true
    }
    
    func setupSession() -> Bool {
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        do {
            let input = try AVCaptureDeviceInput(device: frontCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                activeInput = input
            }
        } catch {
            print("Error setting device video input: \(error)")
            return false
        }
        
        //let microphone = AVCaptureDevice.default(for: AVMediaType.audio)
        /*let microphone: AVCaptureDevice? = {
            guard let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeAudio) as? [AVCaptureDevice] else { return nil }
            return devices.first
        }()
        
        do {
            let micInput = try AVCaptureDeviceInput(device: microphone)
            if captureSession.canAddInput(micInput) {
                captureSession.addInput(micInput)
            }
        } catch {
            print("Error setting device audio input: \(error)")
            return false
        }*/
        
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
            if (connection?.isVideoOrientationSupported)! {
                connection?.videoOrientation = currentVideoOrientation()
            }
            
            if (connection?.isVideoStabilizationSupported)! {
                connection?.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.auto
            }
            
            guard let device = activeInput.device else { return }
            if (device.isSmoothAutoFocusSupported) {
                do {
                    try device.lockForConfiguration()
                    device.isSmoothAutoFocusEnabled = false
                    device.unlockForConfiguration()
                } catch {
                    print("Error setting configuration: \(error)")
                }
            }
            outputURL = tempURL()
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
    
    
    func tempURL() -> URL? {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent("temp.mp4")
        try? FileManager.default.removeItem(at: fileUrl)
        return fileUrl
        
        let directory = NSTemporaryDirectory() as NSString
        
        if directory != "" {
            let path = directory.appendingPathComponent(NSUUID().uuidString + ".mov")
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}


extension ViewController: AVCaptureFileOutputRecordingDelegate {
//extension ViewController3: AVCaptureFileOutputRecordingDelegate {
    func capture(_ output: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        print("x")
    }
    
    /*func capture(_ output: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        print("finished recording")
    }
    
    func capture(_ output: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        print("Starting")
    }*/
}


extension ViewController: FaceDetectionDelegate {
    func onError(error: FaceDetectionError) {
        switch error {
        case .FaceTilted:
            print("FD: Face tilted")
        case .FaceOutOfFrame:
            print("FD: Out of frame")
        default:
            print("FD: Other error")
        }
    }
}
