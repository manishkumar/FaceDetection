//
//  Capture.swift
//  FaceTracking
//
//  Created by Nino
//

import Foundation
import AVFoundation
import UIKit

final class Capture {
    
    weak var delegate: CaptureDelegate?
    weak var videoDataOutputSampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    weak var audioDataOutputSampleBufferDelegate: AVCaptureAudioDataOutputSampleBufferDelegate?
    
    let queue = DispatchQueue(label: "caputre_session_queue")
    
    private(set) var session: AVCaptureSession?
    private var audioDevice: AVCaptureDevice!
    private var videoDevice: AVCaptureDevice!
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var previewView: UIView
    
    private var videoDeviceInput: AVCaptureDeviceInput? {
        do {
            return try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            delegate?.captureDidFail(with: .couldNotObtainVideoDeviceInput(error))
            return nil
        }
    }
    
    private var audioDeviceInput: AVCaptureDeviceInput? {
        do {
            return try AVCaptureDeviceInput(device: audioDevice)
        } catch {
            delegate?.captureDidFail(with: .couldNotObtainAudioDeviceInput(error))
            return nil
        }
    }
    
    // create and configure video data output
    private var videoDataOutput: AVCaptureVideoDataOutput {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            // CoreImage wants BGRA pixel format
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(videoDataOutputSampleBufferDelegate, queue: queue)
        return output
    }
    
    private var audioDataOutput: AVCaptureAudioDataOutput {
        // configure audio data output
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(audioDataOutputSampleBufferDelegate, queue: queue)
        return output
    }
    
    init(devicePosition: AVCaptureDevice.Position,
         preset: String,
         delegate: CaptureDelegate,
         videoDataOutputSampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate,
         audioDataOutputSampleBufferDelegate: AVCaptureAudioDataOutputSampleBufferDelegate,
         previewView: UIView) {
        self.delegate = delegate
        self.videoDataOutputSampleBufferDelegate = videoDataOutputSampleBufferDelegate
        self.audioDataOutputSampleBufferDelegate = audioDataOutputSampleBufferDelegate
        self.previewView = previewView
        
        // Check the availability of video and audio devices. Create and start the capture session only if the devices are present
        do {
            if #available(iOS 10.0, *) {
                guard let device = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: devicePosition),
                    device.supportsAVCaptureSessionPreset(preset) else {
                        delegate.captureDidFail(with: .couldNotGetVideoDevice)
                        return
                }
                
                self.videoDevice = device
                
                guard let audioDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInMicrophone, mediaType: AVMediaTypeAudio, position: .unspecified) else {
                    delegate.captureDidFail(with: .couldNotGetAudioDevice)
                    return
                }
                
                self.audioDevice = audioDevice
                
            } else {
                // Fallback on earlier versions
            }
            
            start(preset)
        }
    }
    
    func addPreview() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        self.previewLayer?.frame = self.previewView.bounds
        self.previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        guard let previewLayer = self.previewLayer else { return }
        self.previewView.layer.addSublayer(previewLayer)
    }
    
    func start(_ preset: String) {
        if session != nil {
            return
        }
        
        delegate?.captureWillStart()
        
        queue.async {
            
            // obtain device input
            guard let videoDeviceInput = self.videoDeviceInput,
                let audioDeviceInput = self.audioDeviceInput else {
                    return                    
            }
            
            // create the capture session
            let session = AVCaptureSession()
            session.sessionPreset = preset
            session.automaticallyConfiguresApplicationAudioSession = false
            self.session = session
            
            // obtain data output
            let videoDataOutput = self.videoDataOutput
            let audioDataOutput = self.audioDataOutput
            
            if !session.canAddOutput(videoDataOutput) {
                self.delegate?.captureDidFail(with: .couldNotAddVideoDataOutput)
                self.session = nil
                return
            }
            
            if !session.canAddOutput(audioDataOutput) {
                self.delegate?.captureDidFail(with: .couldNotAddAudioDataOutput)
                self.session = nil
                return
            }
            
            // begin configure capture session
            session.beginConfiguration()
            // connect the video device input and video data and still image outputs
            session.addInput(videoDeviceInput)
            session.addOutput(videoDataOutput)
            session.addInput(audioDeviceInput)
            session.addOutput(audioDataOutput)
            session.commitConfiguration()
            session.startRunning()
            
            DispatchQueue.main.async {
                self.delegate?.captureDidStart()
                self.addPreview()
            }
        }
    }
    
    func stop() {
        guard let session = session,
            session.isRunning else {
                return
        }
        
        delegate?.captureWillStop()
        session.stopRunning()
        
        queue.async {
            print("waiting for capture session to end")
        }
        
        self.session = nil
        
        delegate?.captureDidStop()
    }
    
    func focus(at point: CGPoint) {
        do {
            try videoDevice.lockForConfiguration()
            if videoDevice.isFocusPointOfInterestSupported == true {
                videoDevice.focusPointOfInterest = point
                videoDevice.focusMode = .autoFocus
            }
            videoDevice.exposurePointOfInterest = point
            videoDevice.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
            videoDevice.unlockForConfiguration()
        } catch {
            // just ignore
        }
    }
}
