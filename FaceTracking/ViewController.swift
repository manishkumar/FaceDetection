//
//  ViewController.swift
//  FaceTracking
//
//  Created by Nino
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    let videoRecorder: VideoRecording = VideoRecorder(cameraPosition: .front)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        videoRecorder.startPreview(frame: view.frame, parent: view)
        videoRecorder.delegate = self
    }
    
}


extension ViewController: VideoRecorderDelegate {
    func onError(error: VideoRecorderError) {
        switch error {
        case .errorConfiguringInputDevice:
            print("errorConfiguringInputDevice")
        case .errorStartingRecording:
            print("errorStartingRecording")
        case .faceDetectionError(let error):
            print("faceDetectionError \(error)")
        }
    }
    
    
}

