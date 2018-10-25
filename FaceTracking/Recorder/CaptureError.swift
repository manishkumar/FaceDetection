//
//  CaptureError.swift
//  FaceTracking
//
//  Created by Nino
//

import Foundation
import AVFoundation

enum CaptureError: Error {
    case presetNotSupportedByVideoDevice(AVCaptureSession.Preset)
    case couldNotGetVideoDevice
    case couldNotGetAudioDevice
    case couldNotObtainVideoDeviceInput(Error)
    case couldNotObtainAudioDeviceInput(Error)
    case couldNotAddVideoDataOutput
    case couldNotAddAudioDataOutput
}

extension CaptureError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .presetNotSupportedByVideoDevice(preset):
            return "Capture session preset not supported by video device: \(preset)"
        case .couldNotGetVideoDevice:
            return "Could not get video device"
        case .couldNotGetAudioDevice:
            return "Could not get video device"
        case .couldNotObtainVideoDeviceInput:
            return "Unable to obtain video device input"
        case .couldNotObtainAudioDeviceInput:
            return "Unable to obtain audio device input"
        case .couldNotAddVideoDataOutput:
            return "Could not add video data output"
        case .couldNotAddAudioDataOutput:
            return "Could not add audio data output"
        }
    }
}

protocol CaptureDelegate: class {
    func captureWillStart()
    func captureDidStart()
    func captureWillStop()
    func captureDidStop()
    func captureDidFail(with error: CaptureError)
}
