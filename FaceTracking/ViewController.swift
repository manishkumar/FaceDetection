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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        recorder = Recorder(devicePosition: devicePosition,
                            preset: videoQuality,
                            previewFrame: cameraView.frame,
                            previewSuperView: cameraView)
        recorder.delegate = self
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.recorder.startRecording()
        }
    }
}

extension ViewController: RecorderDelegate {
    func recorderDidUpdate(drawingImage: CIImage) {
        print("recorderDidUpdate image")
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
