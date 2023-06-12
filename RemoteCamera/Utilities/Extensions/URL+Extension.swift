//
//  URL+Extension.swift
//  RemoteCamera
//
//  Created by cleanmac on 12/06/23.
//

import UIKit

/// Creates a asset target url using the current date and time
/// - Returns: Returns the created url
func URLCreateAssetWriterTargetPath() -> URL {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd-MM-yyyy-HH:mm"
    let currentDateString = dateFormatter.string(from: Date())
    let assetName = UIDevice.current.name + "_" + currentDateString
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
    return URL(fileURLWithPath: documentsPath.appendingPathComponent(assetName)).appendingPathExtension("mov")
}
