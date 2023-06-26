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
    func createResizedPngData(orientation: UIImage.Orientation = .left, resizeTo size: CGSize = CGSizeMake(180, 240)) -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil),
              let compressedImage = UIImage(data: UIImage(cgImage: self, scale: 1, orientation: .left).jpegData(compressionQuality: 0.05)!)?.cgImage,
              let orientedImage = compressedImage.createMatchingBackingDataWithImage(imageRef: compressedImage, orientation: orientation)?.resize(to: size)
        else { return nil }
        
        CGImageDestinationAddImage(destination, orientedImage, nil)
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
    
    /// Creates a new `CGImage` based on a given image reference and orientation
    /// Source: https://stackoverflow.com/a/43531485/8279130
    func createMatchingBackingDataWithImage(imageRef: CGImage?, orientation: UIImage.Orientation) -> CGImage? {
        var orientedImage: CGImage?

        if let imageRef = imageRef {
            let originalWidth = imageRef.width
            let originalHeight = imageRef.height
            let bitsPerComponent = imageRef.bitsPerComponent
            let bytesPerRow = imageRef.bytesPerRow

            let colorSpace = imageRef.colorSpace
            let bitmapInfo = imageRef.bitmapInfo

            var degreesToRotate: Double
            var swapWidthHeight: Bool
            var mirrored: Bool
            switch orientation {
            case .up:
                degreesToRotate = 0.0
                swapWidthHeight = false
                mirrored = false
                break
            case .upMirrored:
                degreesToRotate = 0.0
                swapWidthHeight = false
                mirrored = true
                break
            case .right:
                degreesToRotate = 90.0
                swapWidthHeight = true
                mirrored = false
                break
            case .rightMirrored:
                degreesToRotate = 90.0
                swapWidthHeight = true
                mirrored = true
                break
            case .down:
                degreesToRotate = 180.0
                swapWidthHeight = false
                mirrored = false
                break
            case .downMirrored:
                degreesToRotate = 180.0
                swapWidthHeight = false
                mirrored = true
                break
            case .left:
                degreesToRotate = -90.0
                swapWidthHeight = true
                mirrored = false
                break
            case .leftMirrored:
                degreesToRotate = -90.0
                swapWidthHeight = true
                mirrored = true
                break
            @unknown default:
                degreesToRotate = 0.0
                swapWidthHeight = false
                mirrored = false
                break
            }
            let radians = degreesToRotate * Double.pi / 180

            var width: Int
            var height: Int
            if swapWidthHeight {
                width = originalHeight
                height = originalWidth
            } else {
                width = originalWidth
                height = originalHeight
            }

            if let contextRef = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace!, bitmapInfo: bitmapInfo.rawValue) {

                contextRef.translateBy(x: CGFloat(width) / 2.0, y: CGFloat(height) / 2.0)
                if mirrored {
                    contextRef.scaleBy(x: -1.0, y: 1.0)
                }
                contextRef.rotate(by: CGFloat(radians))
                if swapWidthHeight {
                    contextRef.translateBy(x: -CGFloat(height) / 2.0, y: -CGFloat(width) / 2.0)
                } else {
                    contextRef.translateBy(x: -CGFloat(width) / 2.0, y: -CGFloat(height) / 2.0)
                }
                contextRef.draw(imageRef, in: CGRect(x: 0, y: 0, width: originalWidth, height: originalHeight))

                orientedImage = contextRef.makeImage()
            }
        }

        return orientedImage
    }
    
    // Resizes the image based on a given width and size
    /// - Parameter size: The desired size for resizing
    /// - Returns: Returns the resized image. Returns`nil` if failed.
    /// Source: https://rockyshikoku.medium.com/resize-cgimage-baf23a0f58ab
    func resize(to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        
        let bytesPerPixel = bitsPerPixel / bitsPerComponent
        let destBytesPerRow = width * bytesPerPixel
        
        guard
            let colorSpace,
            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: destBytesPerRow, space: colorSpace, bitmapInfo: alphaInfo.rawValue)
        else { return nil }
        
        context.interpolationQuality = .high
        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()
    }
}
