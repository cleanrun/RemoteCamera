//
//  H264Decoder.swift
//  RemoteCamera
//
//  Created by cleanmac on 15/06/23.
//

import CoreMedia

final class H264Decoder {
    
    private var sps: H264Unit?
    private var pps: H264Unit?
    
    private var description: CMVideoFormatDescription?
    
    private lazy var decodingQueue = DispatchQueue(label: "decoding-queue", qos: .utility)
    
    var sbufCallback: ((CMSampleBuffer) -> Void)?
    
    private func createFormatDescription(using unit: H264Unit) {
        if unit.type == .sps {
            sps = unit
        } else if unit.type == .pps {
            pps = unit
        }
        
        guard let sps, let pps else {
            print("\(#function): Either SPS or PPS is nil")
            return
        }
        
        let spsPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: sps.data.count)
        sps.data.copyBytes(to: spsPointer, count: sps.data.count)
        
        let ppsPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: pps.data.count)
        pps.data.copyBytes(to: ppsPointer, count: pps.data.count)
        
        let parameterSet = [UnsafePointer(spsPointer), UnsafePointer(ppsPointer)]
        let parameterSetSizes = [sps.data.count, pps.data.count]
        
        defer {
            parameterSet.forEach { $0.deallocate() }
        }
        
        let error = CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault,
                                                            parameterSetCount: 2,
                                                            parameterSetPointers: parameterSet,
                                                            parameterSetSizes: parameterSetSizes,
                                                            nalUnitHeaderLength: 4,
                                                            formatDescriptionOut: &description)
        
        print("status: \(error), \(noErr)")
    }
    
    private func createBlockBuffer(using unit: H264Unit) -> CMBlockBuffer? {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: unit.data.count)
        
        unit.data.copyBytes(to: pointer, count: unit.data.count)
        var blockBuffer: CMBlockBuffer?
        
        let error = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                       memoryBlock: pointer,
                                                       blockLength: unit.data.count,
                                                       blockAllocator: kCFAllocatorDefault,
                                                       customBlockSource: nil,
                                                       offsetToData: 0,
                                                       dataLength: unit.data.count,
                                                       flags: .zero,
                                                       blockBufferOut: &blockBuffer)
        
        guard error == kCMBlockBufferNoErr else {
            print("\(#function): Failed to create block buffer")
            return nil
        }
        
        return blockBuffer
    }
    
    private func createSampleBuffer(using blockBuffer: CMBlockBuffer) -> CMSampleBuffer? {
        var sbuf: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo()
        timingInfo.decodeTimeStamp = .invalid
        timingInfo.duration = .invalid
        timingInfo.presentationTimeStamp = .zero
        
        let error = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault,
                                              dataBuffer: blockBuffer,
                                              formatDescription: description,
                                              sampleCount: 1,
                                              sampleTimingEntryCount: 1,
                                              sampleTimingArray: &timingInfo,
                                              sampleSizeEntryCount: 0,
                                              sampleSizeArray: nil,
                                              sampleBufferOut: &sbuf)
        
        guard error == noErr, let sbuf else {
            print("\(#function): Failed to create sample buffer with code -> \(error)")
            return nil
        }
        
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sbuf, createIfNecessary: true) {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(), Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        
        return sbuf
    }
    
    func decode(_ unit: H264Unit) {
        decodingQueue.async { [unowned self] in
            if unit.type == .sps || unit.type == .pps {
                description = nil
                self.createFormatDescription(using: unit)
                return
            } else {
                sps = nil
                pps = nil
            }
            
            guard let blockBuffer = self.createBlockBuffer(using: unit),
                  let sbuf = self.createSampleBuffer(using: blockBuffer) else {
                print("\(#function): Failed to create either block buffer or sample buffer")
                return
            }
            
            sbufCallback?(sbuf)
        }
    }
    
}
