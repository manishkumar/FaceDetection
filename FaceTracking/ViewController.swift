//
//
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
//class ViewController3: UIViewController {
    
    var session: AVCaptureSession?
    fileprivate let captureSession = AVCaptureSession()
    fileprivate let movieOutput = AVCaptureMovieFileOutput()
    fileprivate var previewLayer: AVCaptureVideoPreviewLayer!
    fileprivate var activeInput: AVCaptureDeviceInput!
    fileprivate var outputURL: URL!
    fileprivate let avPlayer = AVPlayer()
    fileprivate var avPlayerLayer: AVPlayerLayer!
    
    
    lazy var frontCamera: AVCaptureDevice? = {
        guard let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] else { return nil }
        return devices.filter { $0.position == .front }.first
    }()
    
    let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy : CIDetectorAccuracyHigh])
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !Platform.isSimulator {
            if setupSession() {
                setupSessions2()
                setupPreview()
                startSession()
                session?.startRunning()
                startRecording()
                
                Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(timerAction), userInfo: nil, repeats: false)
            }
        }
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
    
    func setupSessions2() {
        session = AVCaptureSession()
        
        guard let session = session, let captureDevice = frontCamera else { return }
        
        session.sessionPreset = AVCaptureSessionPresetHigh
        
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


extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
//extension ViewController3: AVCaptureVideoDataOutputSampleBufferDelegate {
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
