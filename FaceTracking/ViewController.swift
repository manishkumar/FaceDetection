//
//  ViewController.swift
//  FaceTracking
//
//  Created by Nino
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    lazy var frontCamera: AVCaptureDevice? = {
        guard let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] else { return nil }
        return devices.filter { $0.position == .front }.first
    }()
    
    var faceDetector: FaceDetecting?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let camera = frontCamera else { return }
        faceDetector = FaceDetector(captureDevice: camera)
        faceDetector?.delegate = self
        faceDetector?.start()
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
