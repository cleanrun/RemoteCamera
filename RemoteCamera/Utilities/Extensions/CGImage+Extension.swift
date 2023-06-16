//
//  CGImage+Extension.swift
//  RemoteCamera
//
//  Created by cleanmac on 13/06/23.
//

import Foundation
import CoreGraphics
import ImageIO

extension CGImage {
    
    /// Creates a PNG data representation
    /// source: https://stackoverflow.com/a/48312429/8279130
    var pngData: Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil)
        else { return nil }
        
        CGImageDestinationAddImage(destination, self, nil)
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}
