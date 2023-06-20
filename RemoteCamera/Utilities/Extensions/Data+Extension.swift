//
//  Data+Extension.swift
//  RemoteCamera
//
//  Created by cleanmac on 20/06/23.
//

import Foundation

extension Data {
    
    /// Get the size of this Data object.
    /// - Parameter units: The unit for the size.
    /// - Returns: Returns a `String` representation of the size.
    ///
    /// Source: https://stackoverflow.com/a/42723243/8279130
    func size(units: ByteCountFormatter.Units) -> String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = units
        bcf.countStyle = .file
        return bcf.string(fromByteCount: Int64(self.count))
    }
}
