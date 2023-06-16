//
//  H264Encoder.swift
//  RemoteCamera
//
//  Created by cleanmac on 15/06/23.
//

import VideoToolbox

final class H264Encoder: NSObject {
    
    /// The current video compression session
    private var session: VTCompressionSession!
    
    private static let naluStartCode = Data([UInt8](arrayLiteral: 0x00, 0x00, 0x00, 0x01))
    
    var naluHandler: ((Data) -> Void)?
    
    override init() {
        super.init()
    }
    
    /// The ouput callback to handle encoded video frame buffers
    private var encodingOutputCallback: VTCompressionOutputCallback = { outputCallbackRefcon, _, status, flags, sbuf in
        guard let sbuf else {
            print("\(#function): Sample Buffer is nil")
            return
        }
        
        guard let outputCallbackRefcon else {
            print("\(#function): Output callback refcon is nil")
            return
        }
        
        guard status == noErr else {
            print("\(#function): Encoding status error with code: \(status)")
            return
        }
        
        guard CMSampleBufferDataIsReady(sbuf) else {
            print("\(#function): Sample buffer is not ready")
            return
        }
        
        guard flags != .frameDropped else {
            print("\(#function): Frame was dropped")
            return
        }
        
        let encoder: H264Encoder = Unmanaged.fromOpaque(outputCallbackRefcon).takeUnretainedValue()
        
        if sbuf.isKeyFrame {
            encoder.extractSPSAndPPS(sbuf)
        }
        
        guard let dataBuffer = sbuf.dataBuffer else {
            print("\(#function): Sample buffer does not contain data buffer")
            return
        }
        
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let error = CMBlockBufferGetDataPointer(dataBuffer,
                                                atOffset: 0,
                                                lengthAtOffsetOut: nil,
                                                totalLengthOut: &totalLength,
                                                dataPointerOut: &dataPointer)
        
        guard error == kCMBlockBufferNoErr,
              let dataPointer else {
            print("\(#function): There's an error with code: \(error) or data pointer is nil")
            return
        }
        
        var packageStartIndex = 0
        
        while packageStartIndex < totalLength {
            var nextNALULength: UInt32 = 0
            memcpy(&nextNALULength, dataPointer.advanced(by: packageStartIndex), 4)
            
            nextNALULength = CFSwapInt32BigToHost(nextNALULength)
            
            var nalu = Data(bytes: dataPointer.advanced(by: packageStartIndex + 4), count: Int(nextNALULength))
            packageStartIndex += (4 + Int(nextNALULength))
            
            encoder.naluHandler?(H264Encoder.naluStartCode + nalu)
        }
    }
    
    /// Configures the compression session and prepares to encode incoming frames
    func configureCompressionSession() throws {
        let error = VTCompressionSessionCreate(allocator: kCFAllocatorDefault,
                                               width: Int32(720),
                                               height: Int32(1280),
                                               codecType: kCMVideoCodecType_H264,
                                               encoderSpecification: nil,
                                               imageBufferAttributes: nil,
                                               compressedDataAllocator: kCFAllocatorDefault,
                                               outputCallback: encodingOutputCallback,
                                               refcon: Unmanaged.passUnretained(self).toOpaque(),
                                               compressionSessionOut: &session)
        
        guard error == errSecSuccess, let session else {
            throw EncoderConfigurationError.failedCreateSession
        }
        
        let propertyDictionary = [
            kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_Baseline_AutoLevel,
            kVTCompressionPropertyKey_MaxKeyFrameInterval: 60,
            kVTCompressionPropertyKey_RealTime: true,
            kVTCompressionPropertyKey_Quality: 0.5
        ] as CFDictionary
        
        guard VTSessionSetProperties(session, propertyDictionary: propertyDictionary) == noErr else {
            throw EncoderConfigurationError.failedSetProperties
        }
        
        guard VTCompressionSessionPrepareToEncodeFrames(session) == noErr else {
            throw EncoderConfigurationError.cannotPrepareToEncode
        }
    }
    
    /// Extracts the SPS and PPS information from a sample buffer.
    ///
    /// Note that only use this function if you are sure that the provided sample buffer is a key-frame frame buffer.
    /// - Parameter sbuf: The sample buffer to extract.
    func extractSPSAndPPS(_ sbuf: CMSampleBuffer) {
        guard let description = CMSampleBufferGetFormatDescription(sbuf) else {
            print("\(#function): Format description is nil")
            return
        }
        
        var parameterSetCount = 0
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                           parameterSetIndex: 0,
                                                           parameterSetPointerOut: nil,
                                                           parameterSetSizeOut: nil,
                                                           parameterSetCountOut: &parameterSetCount,
                                                           nalUnitHeaderLengthOut: nil)
        
        guard parameterSetCount == 2 else {
            print("\(#function): Parameter set count is greater/lesser than 2")
            return
        }
        
        var spsSize: Int = 0
        var sps: UnsafePointer<UInt8>?
        
        // Getting the SPS value, parameter set index is 0 because I'm assuming SPS value is in the first index
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                           parameterSetIndex: 0,
                                                           parameterSetPointerOut: &sps,
                                                           parameterSetSizeOut: &spsSize,
                                                           parameterSetCountOut: nil,
                                                           nalUnitHeaderLengthOut: nil)
        
        var ppsSize: Int = 0
        var pps: UnsafePointer<UInt8>?
        
        // Getting the PPS value, parameter set index is 1 because I'm assuming PPS value is in the second index
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                           parameterSetIndex: 1,
                                                           parameterSetPointerOut: &pps,
                                                           parameterSetSizeOut: &ppsSize,
                                                           parameterSetCountOut: nil,
                                                           nalUnitHeaderLengthOut: nil)
        
        guard let sps, let pps else {
            print("\(#function): Either SPS or PPS information is nil")
            return
        }
        
        [Data(bytes: sps, count: spsSize), Data(bytes: pps, count: ppsSize)].forEach {
            naluHandler?(H264Encoder.naluStartCode + $0)
        }
        
    }
    
    /// Encodes the provided sample buffer using the current compression session.
    /// - Parameter sbuf: The `CMSampleBuffer` object to encode.
    func encode(_ sbuf: CMSampleBuffer) {
        guard let session,
              let imageBuffer = CMSampleBufferGetImageBuffer(sbuf)
        else { return }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sbuf)
        let duration = CMSampleBufferGetDuration(sbuf)
        
        VTCompressionSessionEncodeFrame(session,
                                        imageBuffer: imageBuffer,
                                        presentationTimeStamp: timestamp,
                                        duration: duration,
                                        frameProperties: nil,
                                        sourceFrameRefcon: nil,
                                        infoFlagsOut: nil)
    }
}
