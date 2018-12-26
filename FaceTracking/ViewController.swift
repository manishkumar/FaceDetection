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
    fileprivate var isErrorShown: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        recorder = Recorder(devicePosition: devicePosition,
                            preset: videoQuality,
                            previewView: cameraView)
        recorder.delegate = self
    }
    
    @IBAction func start(_ sender: Any) {
        recorder.startRecording()
    }
    
    @IBAction func stop(_ sender: Any) {
        recorder.stopRecording()
    }
}

extension ViewController: RecorderDelegate {
    
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
        //print("recorderDidUpdate: \(recordingSeconds)")
    }
    
    func recorderDidFail(with error: LocalizedError) {
        print("recorderDidFail: \(error)")
    }
    
    func recorderFaceDetectionError(with error: FaceDetectionError) {
        print("recorderFaceDetectionError: \(error)")
        if !isErrorShown {
            let alert = UIAlertController(title: "Error", message: "Face detection error: \(error)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Retry",
                                          style: .default,
                                          handler: { [weak self] action in
                                            self?.isErrorShown = false
            }))
            self.present(alert, animated: true, completion: nil)
            isErrorShown = true
        }
        
    }
    
    
}
