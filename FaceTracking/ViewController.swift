//
//  ViewController.swift
//  FaceTracking
//
//  Created by Nino
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var cameraView: UIView!
    private let devicePosition = AVCaptureDevice.Position.front
    private let videoQuality = AVCaptureSessionPresetHigh
    private var recorder: Recorder!
    private var ciContext: CIContext!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup the GLKView for video/image preview
        guard let eaglContext = EAGLContext(api: .openGLES2) else {
            fatalError("Could not create EAGLContext")
        }
        if eaglContext != EAGLContext.current() {
            EAGLContext.setCurrent(eaglContext)
        }
        
        ciContext = CIContext(eaglContext: eaglContext, options: [kCIContextWorkingColorSpace: NSNull()])
        recorder = Recorder(ciContext: ciContext,
                            devicePosition: devicePosition,
                            preset: videoQuality,
                            previewView: self.view)
        recorder.delegate = self
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.recorder.startRecording()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            self.recorder.stopRecording()
        }
    }
}

extension ViewController: RecorderDelegate {
    func recorderDidUpdate(drawingImage: CIImage) {
        //print("recorderDidUpdate image")
    }
    
    func recorderDidStartRecording() {
        print("recorderDidStartRecording")
    }
    
    func recorderDidAbortRecording() {
        print("recorderDidAbortRecording")
    }
    
    func recorderDidFinishRecording() {
        print("recorderDidFinishRecording")
    }
    
    func recorderWillStartWriting() {
        print("recorderWillStartWriting")
    }
    
    func recorderDidFinishWriting(outputURL: URL) {
        print("recorderDidFinishWriting: \(outputURL)")
    }
    
    func recorderDidUpdate(recordingSeconds: Int) {
        print("recorderDidUpdate: \(recordingSeconds)")
    }
    
    func recorderDidFail(with error: LocalizedError) {
        print("recorderDidFail: \(error)")
    }
    
    
}
