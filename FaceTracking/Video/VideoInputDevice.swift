//
//  FaceTracking
//  VideoInputDevice.swift
//
//  Created by Nino
//

import Foundation
import AVFoundation

protocol VideoInput: class {
    func getDevice() -> AVCaptureDevice?
}

final class VideoInputDevice: VideoInput {
    
    let position: AVCaptureDevice.Position
    
    init(position: AVCaptureDevice.Position) {
        self.position = position
    }
    
    func getDevice() -> AVCaptureDevice? {
        guard let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] else { return nil }
        return devices.filter { $0.position == position }.first
    }
    
}
