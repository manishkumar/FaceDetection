//  FaceDetector.swift
//
//  Created by Nino
//

import Foundation
import AVFoundation

protocol FaceDetecting {
    func start()
    func stop()
}

protocol FaceDetectionDelegate {
    func faceOutOfFrame()
    func faceTilted()
}

final class FaceDetector: NSObject, FaceDetecting {
    
    let delegate: FaceDetectionDelegate
    
    init(facedetectionDelegate: FaceDetectionDelegate) {
        self.delegate = facedetectionDelegate
    }
    
    func start() {
        
    }
    
    func stop() {
        
    }
    
}

extension FaceDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    
}
