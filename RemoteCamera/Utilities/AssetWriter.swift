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
    @available(iOS, deprecated: 15.0, message: "Output URLS is not set at the beginning of the initialization process anymore, rather than when setting the writer input")
    private var outputURL: URL!
    
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
    }
    
    /// Sets up all of the writer input objects to start writing video frames
    /// - Parameters:
    ///   - metadata: The camera metadata information for this specific writing session
    ///   - vFormateDescription: The format desctiption used for format hint
    ///   - recommendedVideoSettings: The recommended video settings retrieved from video data output
    private func setupWriterInput(metadata: AssetWritingMetadata, vFormatDescription: CMFormatDescription? = nil,recommendedVideoSettings: [String: Any]? = nil) throws {
        
        // You have to initialize a new `AVAssetWriter` everytime you want to record a new video.
        assetWriter = try AVAssetWriter(url: metadata.targetURL, fileType: .mov)
        assetWriter.shouldOptimizeForNetworkUse = false
        
        var recommendedVideoSettings = recommendedVideoSettings
        if recommendedVideoSettings == nil {
            let bitsPerPixel: CGFloat
            if metadata.resolutionWidth * metadata.resolutionHeight < 640 * 480 {
                bitsPerPixel = 4.05 // Relative to AVCaptureSessionPresetMedium/Low
            } else {
                bitsPerPixel = 10.1 // Relative to AVCaptureSessionPresetHigh
            }
            
            let compressionProperties: NSDictionary = [
                AVVideoAverageBitRateKey: CGFloat(metadata.resolutionWidth) * CGFloat(metadata.resolutionHeight) * bitsPerPixel,
                AVVideoExpectedSourceFrameRateKey: Double(metadata.fps.rawValue)!,
                AVVideoMaxKeyFrameIntervalKey: Double(metadata.fps.rawValue)!
            ]
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: metadata.resolutionWidth,
                AVVideoHeightKey: metadata.resolutionHeight,
                AVVideoCompressionPropertiesKey: compressionProperties
            ]
            
            recommendedVideoSettings = videoSettings
        }
        
        if assetWriter.canApply(outputSettings: recommendedVideoSettings, forMediaType: .video) {
            assetVideoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: recommendedVideoSettings, sourceFormatHint: vFormatDescription)
            assetVideoWriterInput.expectsMediaDataInRealTime = true
            assetVideoWriterInput.transform = CGAffineTransform(rotationAngle: .pi/2)
            
            if assetWriter.canAdd(assetVideoWriterInput) {
                assetWriter.add(assetVideoWriterInput)
            } else {
                throw "Asset Writer couldn't add the input"
            }
        } else {
            throw "Asset Writer couldn't apply the output settings"
        }
    }

    /// Tells the asset writer that the writing process is about to began.
    ///
    /// This method is to be called when the user taps a button to indicate that video recording is about to began.
    /// - Parameters:
    ///   - metadata: The camera metadata information for this specific writing session
    ///   - vFormatDescription: The format desctiption used for format hint
    ///   - recommendedVideoSettings: The recommended video settings retrieved from video data output
    ///   - sourceTime: The starting time of the writing process
    func prepareForWriting(metadata: AssetWritingMetadata, vFormatDescription: CMFormatDescription? = nil, recommendedVideoSettings: [String: Any]? = nil, at sourceTime: CMTime) {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            do {
                try FileManager.default.removeItem(atPath: outputURL.path)
            } catch {
                print(error.localizedDescription)
            }
        }
        
        // You have to initialize a new `AVAssetWriter` everytime you want to record a new video.
//        assetWriter = try! AVAssetWriter(outputURL: outputURL, fileType: .mov)
//        if assetWriter.canAdd(assetVideoWriterInput) {
//            assetWriter.add(assetVideoWriterInput)
//        }
        do {
            try setupWriterInput(metadata: metadata, vFormatDescription: vFormatDescription, recommendedVideoSettings: recommendedVideoSettings)
        } catch {
            print(error.localizedDescription)
            fatalError("Failed to setup writer input")
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
            self.assetVideoWriterInput = nil
            self.delegate?.didFinishWriting()
        }
    }
    
}
