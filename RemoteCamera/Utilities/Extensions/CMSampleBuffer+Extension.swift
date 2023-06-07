//
//  CMSampleBuffer+Extension.swift
//  RemoteCamera
//
//  Created by cleanmac on 07/06/23.
//

import UIKit
import CoreMedia

extension CMSampleBuffer {
    
    /// Creates a `Data` from the sample buffer's image buffer
    /// - Returns: Returns the created image data. Returns `nil`if the image data could not be created
    func createImageDataFromBuffer() -> Data? {
        var data: Data? = nil
        
        // For some reason I had to use sync, using async won't return the image
        DispatchQueue.global(qos: .userInitiated).sync {
            let imageBuffer = CMSampleBufferGetImageBuffer(self)
            
            if let imageBuffer {
                CVPixelBufferLockBaseAddress(imageBuffer, [])
                let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
                let bytesPerRow: size_t? = CVPixelBufferGetBytesPerRow(imageBuffer)
                let width: size_t? = CVPixelBufferGetWidth(imageBuffer)
                let height: size_t? = CVPixelBufferGetHeight(imageBuffer)
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let newContext = CGContext(data: baseAddress,
                                           width: width ?? 0,
                                           height: height ?? 0,
                                           bitsPerComponent: 8,
                                           bytesPerRow: bytesPerRow ?? 0,
                                           space: colorSpace,
                                           bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
                
                if let newImage = newContext?.makeImage() {
                    let image = UIImage(cgImage: newImage,
                                        scale: 0.2,
                                        orientation: .right)
                    
                    CVPixelBufferUnlockBaseAddress(imageBuffer, [])
                    
                    if let imageData = image.jpegData(compressionQuality: 0.2) {
                        data = imageData
                    }
                }
            }
        }
        
        return data
    }
}
