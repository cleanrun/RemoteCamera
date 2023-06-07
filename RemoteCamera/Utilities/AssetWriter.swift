//
//  AssetWriter.swift
//  RemoteCamera
//
//  Created by cleanmac on 06/06/23.
//

import AVFoundation

protocol AssetWriterDelegate: AnyObject {
    /// Called after the writing process is finished
    func didFinishWriting()
}

/// A Video writer helper class to write video into a specified local URL.
final class AssetWriter {
    /// The delegate object for this writer
    weak var delegate: AssetWriterDelegate?
    
    /// The Output URL of the recorded video
    private let outputURL: URL
    
    /// A writer object to write the video and audio buffers
    private(set) var assetWriter: AVAssetWriter!
    
    /// The writer input object to write video frame buffers
    private(set) var assetVideoWriterInput: AVAssetWriterInput!
    
    /// The writer input object to write audio buffers
    private(set) var assetAudioWriterInput: AVAssetWriterInput!
    
    /// The starting time when the asset it being wrote
    private(set) var atSourceTime: CMTime?
    
    /// The recording status of the current writing process
    private(set) var isRecording: Bool = false
    
    /// A flag to indicate whether the current session is able to write the video or not
    var canWrite: Bool { isRecording && (assetWriter.status == .writing) }
    
    init(outputURL: URL) {
        self.outputURL = outputURL
        
        assetVideoWriterInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 720,
                AVVideoHeightKey: 1280,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 2300000
                ]
            ])
        assetAudioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
        
        assetVideoWriterInput.expectsMediaDataInRealTime = true
    }
    
    /// Tells the asset writer that the writing process is about to began.
    ///
    /// This method is to be called when the user taps a button to indicate that video recording is about to began.
    /// - Parameter sourceTime: The starting time of the writing process
    func prepareForWriting(at sourceTime: CMTime) {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            do {
                try FileManager.default.removeItem(atPath: outputURL.path)
            } catch {
                print(error.localizedDescription)
            }
        }
        
        // You have to initialize a new `AVAssetWriter` everytime you want to record a new video.
        assetWriter = try! AVAssetWriter(outputURL: outputURL, fileType: .mov)
        if assetWriter.canAdd(assetVideoWriterInput) {
            assetWriter.add(assetVideoWriterInput)
        }
        
        isRecording = true
        atSourceTime = sourceTime
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: sourceTime)
    }
    
    /// Append buffer frames to the writer inputs.
    /// - Parameter sbuf: The Sample Buffer object to write.
    func appendFrames(_ sbuf: CMSampleBuffer) {
        if assetVideoWriterInput.isReadyForMoreMediaData {
            assetVideoWriterInput.append(sbuf)
        }
    }
    
    /// Tells the writer that the recording process is finished and stops the recording process.
    func finishWriting() {
        isRecording = false
        assetVideoWriterInput.markAsFinished()
        
        assetWriter.finishWriting { [unowned self] in
            self.atSourceTime = nil
            self.assetWriter = nil
            self.delegate?.didFinishWriting()
        }
    }
    
}
