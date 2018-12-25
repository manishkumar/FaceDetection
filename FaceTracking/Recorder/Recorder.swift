//
//  Recorder.swift
//  FaceTracking
//
//  Created by Nino
//

import Foundation
import AVFoundation
import CoreImage
import UIKit

final class Recorder: NSObject {
    
    weak var delegate: RecorderDelegate?
    
    var recordingSeconds: Int {
        guard let _ = assetWriter else { return 0 }
        let diff = currentVideoTime - videoWritingStartTime
        let seconds = CMTimeGetSeconds(diff)
        guard !(seconds.isNaN || seconds.isInfinite) else { return 0 }
        return Int(seconds)
    }
    
    fileprivate struct Constants {
        static let tempVideoFilename = "recording2"
        static let tempVideoFileExtention = "mov"
        static let timerUpdateInterval = 1.0
        static let defaultHeight = 100
        static let defaultWidth = 100
    }
    
    private let ciContext: CIContext!
    private var capture: Capture!
    
    private(set) var assetWriter: AVAssetWriter?
    private var assetWriterAudioInput: AVAssetWriterInput?
    private var assetWriterVideoInput: AVAssetWriterInput?
    private var assetWriterInputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var currentAudioSampleBufferFormatDescription: CMFormatDescription?
    private var currentVideoDimensions: CMVideoDimensions?
    private var timer: Timer?
    private var currentVideoTime = CMTime()
    private var videoWritingStarted = false
    private var videoWritingStartTime = CMTime()

    fileprivate var faceDetector: FaceDetecting = FaceDetector()
    
    private var temporaryVideoFileURL: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(Constants.tempVideoFilename)
            .appendingPathExtension(Constants.tempVideoFileExtention)
    }
    
    init(devicePosition: AVCaptureDevice.Position,
         preset: String,
         previewView: UIView) {
        guard let eaglContext = EAGLContext(api: .openGLES2) else {
            fatalError("Could not create EAGLContext")
        }
        
        self.ciContext = CIContext(eaglContext: eaglContext, options: [kCIContextWorkingColorSpace: NSNull()])
        
        super.init()
        
        capture = Capture(devicePosition: devicePosition,
                          preset: preset,
                          delegate: self,
                          videoDataOutputSampleBufferDelegate: self,
                          audioDataOutputSampleBufferDelegate: self,
                          previewView: previewView)
        faceDetector.delegate = self
        
        // handle AVCaptureSessionWasInterruptedNotification (such as incoming phone call)
        NotificationCenter.default.addObserver(self, selector: #selector(avCaptureSessionWasInterrupted(_:)),
                                               name: .AVCaptureSessionWasInterrupted,
                                               object: nil)
        
        // handle UIApplicationDidEnterBackgroundNotification
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)),
                                               name: .UIApplicationDidEnterBackground,
                                               object: nil)
    }
    
    private func makeAssetWriter() -> AVAssetWriter? {
        do {
            return try AVAssetWriter(url: temporaryVideoFileURL, fileType: AVFileTypeQuickTimeMovie)
        } catch {
            DispatchQueue.main.async {
                self.delegate?.recorderDidFail(with: RecorderError.couldNotCreateAssetWriter(error))
            }
            return nil
        }
    }
    
    private func makeAssetWriterVideoInput() -> AVAssetWriterInput {
        let settings: [String: Any]
        if #available(iOS 11.0, *) {
            settings = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: currentVideoDimensions?.width ?? Constants.defaultWidth,
                AVVideoHeightKey: currentVideoDimensions?.height ?? Constants.defaultHeight,
            ]
        } else {
            settings = [
                AVVideoCodecKey: AVVideoCodecH264,
                AVVideoWidthKey: currentVideoDimensions?.width ?? Constants.defaultWidth,
                AVVideoHeightKey: currentVideoDimensions?.height ?? Constants.defaultHeight,
            ]
        }
        let input = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        return input
    }
    
    // create a pixel buffer adaptor for the asset writer; we need to obtain pixel buffers for rendering later from its pixel buffer pool
    private func makeAssetWriterInputPixelBufferAdaptor(with input: AVAssetWriterInput) -> AVAssetWriterInputPixelBufferAdaptor {
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: currentVideoDimensions?.width ?? Constants.defaultWidth,
            kCVPixelBufferHeightKey as String: currentVideoDimensions?.height ?? Constants.defaultHeight,
            kCVPixelFormatOpenGLESCompatibility as String: kCFBooleanTrue,
            ]
        return AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attributes
        )
    }
    
    private func makeAudioCompressionSettings() -> [String: Any]? {
        guard let currentAudioSampleBufferFormatDescription = self.currentAudioSampleBufferFormatDescription else {
            DispatchQueue.main.async {
                self.delegate?.recorderDidFail(with: RecorderError.couldNotGetAudioSampleBufferFormatDescription)
            }
            return nil
        }
        
        let channelLayoutData: Data
        var layoutSize: size_t = 0
        if let channelLayout = CMAudioFormatDescriptionGetChannelLayout(currentAudioSampleBufferFormatDescription, &layoutSize) {
            channelLayoutData = Data(bytes: channelLayout, count: layoutSize)
        } else {
            channelLayoutData = Data()
        }
        
        guard let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(currentAudioSampleBufferFormatDescription) else {
            DispatchQueue.main.async {
                self.delegate?.recorderDidFail(with: RecorderError.couldNotGetStreamBasicDescriptionOfAudioSampleBuffer)
            }
            return nil
        }
        
        // record the audio at AAC format, bitrate 64000, sample rate and channel number using the basic description from the audio samples
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: basicDescription.pointee.mChannelsPerFrame,
            AVSampleRateKey: basicDescription.pointee.mSampleRate,
            AVEncoderBitRateKey: 64000,
            AVChannelLayoutKey: channelLayoutData,
        ]
    }
    
    private func getRenderedOutputPixelBuffer(adaptor: AVAssetWriterInputPixelBufferAdaptor?) -> CVPixelBuffer? {
        guard let pixelBufferPool = adaptor?.pixelBufferPool else {
            print("Cannot get pixel buffer pool")
            return nil
        }
        
        var pixelBuffer: CVPixelBuffer? = nil
        CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer)
        guard let renderedOutputPixelBuffer = pixelBuffer else {
            print("Cannot obtain a pixel buffer from the buffer pool")
            return nil
        }
        
        return renderedOutputPixelBuffer
    }
    
    func startRecording() {
        capture.queue.async {
            self.removeTemporaryVideoFileIfAny()
            
            guard let newAssetWriter = self.makeAssetWriter() else { return }
            
            let newAssetWriterVideoInput = self.makeAssetWriterVideoInput()
            let canAddInput = newAssetWriter.canAdd(newAssetWriterVideoInput)
            if canAddInput {
                newAssetWriter.add(newAssetWriterVideoInput)
            } else {
                DispatchQueue.main.async {
                    self.delegate?.recorderDidFail(with: RecorderError.couldNotAddAssetWriterVideoInput)
                }
                self.assetWriterVideoInput = nil
                return
            }
            
            let newAssetWriterInputPixelBufferAdaptor = self.makeAssetWriterInputPixelBufferAdaptor(with: newAssetWriterVideoInput)
            
            guard let audioCompressionSettings = self.makeAudioCompressionSettings() else { return }
            let canApplayOutputSettings = newAssetWriter.canApply(outputSettings: audioCompressionSettings, forMediaType: AVMediaTypeAudio)
            if canApplayOutputSettings {
                let assetWriterAudioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioCompressionSettings)
                assetWriterAudioInput.expectsMediaDataInRealTime = true
                self.assetWriterAudioInput = assetWriterAudioInput
                
                let canAddInput = newAssetWriter.canAdd(assetWriterAudioInput)
                if canAddInput {
                    newAssetWriter.add(assetWriterAudioInput)
                } else {
                    DispatchQueue.main.async {
                        self.delegate?.recorderDidFail(with: RecorderError.couldNotAddAssetWriterAudioInput)
                    }
                    self.assetWriterAudioInput = nil
                    return
                }
            } else {
                DispatchQueue.main.async {
                    self.delegate?.recorderDidFail(with: RecorderError.couldNotApplyAudioOutputSettings)
                }
                return
            }
            
            self.videoWritingStarted = false
            self.assetWriter = newAssetWriter
            self.assetWriterVideoInput = newAssetWriterVideoInput
            self.assetWriterInputPixelBufferAdaptor = newAssetWriterInputPixelBufferAdaptor
            
            DispatchQueue.main.async {
                self.delegate?.recorderDidStartRecording()
            }
        }
    }
    
    private func abortRecording() {
        guard let writer = assetWriter else { return }
        
        writer.cancelWriting()
        assetWriterVideoInput = nil
        assetWriterAudioInput = nil
        assetWriter = nil
        
        // remove the temp file
        let fileURL = writer.outputURL
        try? FileManager.default.removeItem(at: fileURL)
        
        DispatchQueue.main.async {
            self.delegate?.recorderDidAbortRecording()
        }
    }
    
    func stopRecording() {
        guard let writer = assetWriter else { return }
        
        assetWriterVideoInput = nil
        assetWriterAudioInput = nil
        assetWriterInputPixelBufferAdaptor = nil
        assetWriter = nil
        
        DispatchQueue.main.async {
            self.delegate?.recorderWillStartWriting()
        }
        
        capture.queue.async {
            writer.endSession(atSourceTime: self.currentVideoTime)
            writer.finishWriting {
                switch writer.status {
                case .failed:
                    DispatchQueue.main.async {
                        self.delegate?.recorderDidFail(with: RecorderError.couldNotCompleteWritingVideo)
                    }
                case .completed:
                    DispatchQueue.main.async {
                        self.delegate?.recorderDidFinishWriting(outputURL: writer.outputURL)
                    }
                default:
                    break
                }
            }
            DispatchQueue.main.async {
                self.delegate?.recorderDidFinishRecording()
            }
            self.startTimer()
        }
    }
    
    func focus(at point: CGPoint) {
        capture.focus(at: point)
    }
    
    fileprivate func startTimer() {
        if #available(iOS 10.0, *) {
            timer = Timer.scheduledTimer(withTimeInterval: Constants.timerUpdateInterval, repeats: true) { [weak self] _ in
                guard let `self` = self else { return }
                DispatchQueue.main.async {
                    self.delegate?.recorderDidUpdate(recordingSeconds: self.recordingSeconds)
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    fileprivate func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    fileprivate func handleAudioSampleBuffer(buffer: CMSampleBuffer) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(buffer) else { return }
        currentAudioSampleBufferFormatDescription = formatDesc
        
        // write the audio data if it's from the audio connection
        if assetWriter == nil { return }
        guard let input = assetWriterAudioInput else { return }
        if input.isReadyForMoreMediaData {
            let success = input.append(buffer)
            if !success {
                DispatchQueue.main.async {
                    self.delegate?.recorderDidFail(with: RecorderError.couldNotWriteAudioData)
                }
                abortRecording()
            }
        }
    }
    
    fileprivate func handleVideoSampleBuffer(buffer: CMSampleBuffer) {
        //faceDetector.captureOutput(sampleBuffer: buffer)
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(buffer)
        
        // update the video dimensions information
        guard let formatDesc = CMSampleBufferGetFormatDescription(buffer) else { return }
        currentVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDesc)
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return }
        let sourceImage = CIImage(cvPixelBuffer: imageBuffer)
        
        guard let writer = assetWriter,
            let pixelBufferAdaptor = assetWriterInputPixelBufferAdaptor else {
                DispatchQueue.main.async {
                    self.delegate?.recorderDidUpdate(drawingImage: sourceImage)
                }
                return
        }
        
        // if we need to write video and haven't started yet, start writing
        if !videoWritingStarted {
            videoWritingStarted = true
            let success = writer.startWriting()
            if !success {
                DispatchQueue.main.async {
                    self.delegate?.recorderDidFail(with: RecorderError.couldNotWriteVideoData)
                }
                abortRecording()
                return
            }
            
            writer.startSession(atSourceTime: timestamp)
            videoWritingStartTime = timestamp
        }
        
        guard let renderedOutputPixelBuffer = getRenderedOutputPixelBuffer(adaptor: pixelBufferAdaptor) else { return }
        
        // render the filtered image back to the pixel buffer (no locking needed as CIContext's render method will do that
        ciContext.render(sourceImage, to: renderedOutputPixelBuffer, bounds: sourceImage.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
        
        // pass option nil to enable color matching at the output, otherwise the color will be off
        let drawImage = CIImage(cvPixelBuffer: renderedOutputPixelBuffer)
        DispatchQueue.main.async {
            self.delegate?.recorderDidUpdate(drawingImage: drawImage)
        }
        
        currentVideoTime = timestamp
        
        // write the video data
        guard let input = assetWriterVideoInput else { return }
        if input.isReadyForMoreMediaData {
            let success = pixelBufferAdaptor.append(renderedOutputPixelBuffer, withPresentationTime: timestamp)
            if !success {
                DispatchQueue.main.async {
                    self.delegate?.recorderDidFail(with: RecorderError.couldNotWriteVideoData)
                }
            }
        }
    }
    
    private func removeTemporaryVideoFileIfAny() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: temporaryVideoFileURL.path) {
            try? fileManager.removeItem(at: temporaryVideoFileURL)
        }
    }
    
    @objc private func avCaptureSessionWasInterrupted(_ notification: Notification) {
        stopRecording()
    }
    
    @objc private func applicationDidEnterBackground(_ notification: Notification) {
        stopRecording()
    }
}

extension Recorder: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let mediaType = CMFormatDescriptionGetMediaType(formatDesc)
        if mediaType == kCMMediaType_Audio {
            handleAudioSampleBuffer(buffer: sampleBuffer)
        } else if mediaType == kCMMediaType_Video {
            handleVideoSampleBuffer(buffer: sampleBuffer)
        }
    }        
}

extension Recorder: CaptureDelegate {
    
    func captureWillStart() {
        stopTimer()
    }
    
    func captureDidStart() {
        startTimer()
    }
    
    func captureWillStop() {}
    
    func captureDidStop() {
        stopTimer()
        stopRecording()
    }
    
    func captureDidFail(with error: CaptureError) {
        DispatchQueue.main.async {
            self.delegate?.recorderDidFail(with: error)
        }
    }
}

extension Recorder: FaceDetectionDelegate {
    func onError(error: FaceDetectionError) {
        print("FaceDetectionError: \(error)")
    }    
}
