//
//  CMTime+Extension.swift
//  RemoteCamera
//
//  Created by cleanmac on 07/06/23.
//

import CoreMedia

extension CMTime {
    
    /// A String representation of the `CMTime` object
    /// Source: https://stackoverflow.com/a/37452185/8279130
    var durationText: String {
        let totalSeconds = Int(CMTimeGetSeconds(self))
        let hours = Int(totalSeconds / 3600)
        let minutes = Int(totalSeconds % 3600 / 60)
        let seconds = Int((totalSeconds % 3600) % 60)
        
        if hours > 0 {
            return String(format: "%i:%02i:%02i", hours, minutes, seconds)
        } else {
            return String(format: "%02i:%02i", minutes, seconds)
        }
    }
}
