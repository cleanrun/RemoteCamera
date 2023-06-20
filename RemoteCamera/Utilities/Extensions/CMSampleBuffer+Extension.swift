//
//  CMSampleBuffer+Extension.swift
//  RemoteCamera
//
//  Created by cleanmac on 07/06/23.
//

import UIKit
import CoreMedia

extension CMSampleBuffer {
    
    /// Indicate whether this specific sample buffer is a key frame or not.
    var isKeyFrame: Bool {
        let attachments = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: true) as? [[CFString: Any]]
        let isNotKeyFrame = (attachments?.first?[kCMSampleAttachmentKey_NotSync] as? Bool) ?? false
        return !isNotKeyFrame
    }
    
    /// Creates a `Data` from the sample buffer's image buffer.
    /// - Returns: Returns the created image data. Returns `nil`if the image data could not be created.
    func createCGImageDataFromBuffer() -> Data? {
        var data: Data? = nil
        
        if let image = createCGImageFromBuffer() {
            data = image.pngData
        }
        
        return data
    }
    
    /// Creates a `CGImage` from the sample buffer's image buffer.
    /// - Returns: Returns the created image. Returns `nil`if the image  could not be created.
    func createCGImageFromBuffer() -> CGImage? {
        var image: CGImage? = nil
        
        DispatchQueue.global(qos: .utility).sync {
            if let imageBuffer = CMSampleBufferGetImageBuffer(self) {
                let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                let ciContext = CIContext()
                if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                    image = cgImage
                }
            }
        }
        
        return image
    }
}
