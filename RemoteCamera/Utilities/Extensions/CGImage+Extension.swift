//
//  CGImage+Extension.swift
//  RemoteCamera
//
//  Created by cleanmac on 13/06/23.
//

import UIKit
import ImageIO

extension CGImage {
    
    /// Creates a PNG data representation
    /// Source: https://stackoverflow.com/a/48312429/8279130
    var pngData: Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil),
              let compressedImage = UIImage(data: UIImage(cgImage: self, scale: 1, orientation: .up).jpegData(compressionQuality: 0.05)!)?.cgImage
        else { return nil }
        
        CGImageDestinationAddImage(destination, compressedImage, nil)
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}
