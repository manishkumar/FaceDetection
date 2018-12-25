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

enum RecorderError: Error {
    case couldNotCreateAssetWriter(Error)
    case couldNotAddAssetWriterVideoInput
    case couldNotAddAssetWriterAudioInput
    case couldNotGetAudioSampleBufferFormatDescription
    case couldNotGetStreamBasicDescriptionOfAudioSampleBuffer
    case couldNotCompleteWritingVideo
    case couldNotApplyAudioOutputSettings
    case couldNotWriteAudioData
    case couldNotWriteVideoData
}

extension RecorderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .couldNotCreateAssetWriter(error):
            return "Could not create asset writer, error: \(error)"
        case .couldNotAddAssetWriterVideoInput:
            return "Could not add asset writer video input"
        case .couldNotAddAssetWriterAudioInput:
            return "Could not add asset writer audio input"
        case .couldNotGetAudioSampleBufferFormatDescription:
            return "Could not get current audio sample buffer format description"
        case .couldNotGetStreamBasicDescriptionOfAudioSampleBuffer:
            return "Could not get stream basic description of audio sample buffer"
        case .couldNotCompleteWritingVideo:
            return "Could not complete writing the video"
        case .couldNotApplyAudioOutputSettings:
            return "Could not apply audio output settings"
        case .couldNotWriteAudioData:
            return "Could not write audio data, recording aborted"
        case .couldNotWriteVideoData:
            return "Could not write video data, recording aborted"
        }
    }
}

protocol RecorderDelegate: class {
    func recorderDidUpdate(drawingImage: CIImage)
    func recorderDidStartRecording()
    func recorderDidAbortRecording()
    func recorderDidFinishRecording()
    func recorderWillStartWriting()
    func recorderDidFinishWriting(outputURL: URL)
    func recorderDidUpdate(recordingSeconds: Int)
    func recorderDidFail(with error: Error & LocalizedError)
}

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
        static let tempVideoFilename = "recording"
        static let tempVideoFileExtention = "mov"
    }
    
    private var capture: Capture!
    private var videoWritingStarted = false
    private var videoWritingStartTime = CMTime()
    private(set) var assetWriter: AVAssetWriter?
    private var assetWriterAudioInput: AVAssetWriterInput?
    private var assetWriterVideoInput: AVAssetWriterInput?
    private var assetWriterInputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private var currentAudioSampleBufferFormatDescription: CMFormatDescription?
    private var currentVideoDimensions: CMVideoDimensions?
    private var currentVideoTime = CMTime()
    
    private var timer: Timer?
    private let timerUpdateInterval = 0.25
    
    fileprivate var faceDetector: FaceDetecting = FaceDetector()
    
    private var temporaryVideoFileURL: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(Constants.tempVideoFilename)
            .appendingPathExtension(Constants.tempVideoFileExtention)
    }
    
    
    init(devicePosition: AVCaptureDevice.Position,
         preset: String,
         previewFrame: CGRect,
         previewSuperView: UIView) {
        super.init()
        
        capture = Capture(devicePosition: devicePosition,
                          preset: preset,
                          delegate: self,
                          videoDataOutputSampleBufferDelegate: self,
                          audioDataOutputSampleBufferDelegate: self,
                          previewFrame: previewFrame,
                          previewSuperView: previewSuperView)
        faceDetector.delegate = self
        
        // handle AVCaptureSessionWasInterruptedNotification (such as incoming phone call)
        /*NotificationCenter.default.addObserver(self, selector: #selector(avCaptureSessionWasInterrupted(_:)),
                                               name: .AVCaptureSessionWasInterrupted,
                                               object: nil)
        
        // handle UIApplicationDidEnterBackgroundNotification
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)),
                                               name: .UIApplicationDidEnterBackground,
                                               object: nil)*/
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
                AVVideoWidthKey: currentVideoDimensions?.width ?? 200,
                AVVideoHeightKey: currentVideoDimensions?.height ?? 200,
            ]
        } else {
            settings = [
                AVVideoCodecKey: AVVideoCodecH264,
                AVVideoWidthKey: currentVideoDimensions?.width ?? 200,
                AVVideoHeightKey: currentVideoDimensions?.height ?? 200,
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
            kCVPixelBufferWidthKey as String: currentVideoDimensions?.width ?? 0,
            kCVPixelBufferHeightKey as String: currentVideoDimensions?.height ?? 0,
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
            timer = Timer.scheduledTimer(withTimeInterval: timerUpdateInterval,
                                         repeats: true) { [weak self] _ in
                                            guard let strongSelf = self else { return }
                                            DispatchQueue.main.async {
                                                strongSelf.delegate?.recorderDidUpdate(recordingSeconds: strongSelf.recordingSeconds)
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
        faceDetector.captureOutput(sampleBuffer: buffer)
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(buffer)
        
        // update the video dimensions information
        guard let formatDesc = CMSampleBufferGetFormatDescription(buffer),
            let writer = assetWriter,
            let pixelBufferAdaptor = assetWriterInputPixelBufferAdaptor else {
                return
        }
        currentVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDesc)
        
        
        
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
        
    }    
}
