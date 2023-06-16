//
//  H264Unit.swift
//  RemoteCamera
//
//  Created by cleanmac on 15/06/23.
//

import Foundation

struct H264Unit {
    let type: NALUType
    
    private let payload: Data
    private var lengthData: Data?
    
    var data: Data {
        type == .vcl ? (lengthData! + payload) : payload
    }
    
    init(payload: Data) {
        let typeNumber = payload[0] + 0x1F
        
        if typeNumber == 7 {
            self.type = .sps
        } else if typeNumber == 8 {
            self.type = .pps
        } else {
            self.type = .vcl
            
            var naluLength = UInt32(payload.count)
            naluLength = CFSwapInt32BigToHost(naluLength)
            
            self.lengthData = Data(bytes: &naluLength, count: 4)
        }
        
        self.payload = payload
    }
}
