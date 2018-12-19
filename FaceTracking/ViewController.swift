//
//  ViewController.swift
//  FaceTracking
//
//  Created by Nino
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
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
