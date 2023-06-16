//
//  NALUParser.swift
//  RemoteCamera
//
//  Created by cleanmac on 15/06/23.
//

import Foundation

final class NALUParser {
    private var dataStream = Data()
    
    private var searchIndex = 0
    
    private lazy var parsingQueue = DispatchQueue(label: "parsing-queue", qos: .utility)
    
    var unitHandler: ((H264Unit) -> Void)?
    
    func enqueue(_ data: Data) {
        parsingQueue.async { [unowned self] in
            dataStream.append(data)
            
            while searchIndex < dataStream.endIndex - 3 {
                if (dataStream[searchIndex] | dataStream[searchIndex + 1] | dataStream[searchIndex + 2] | dataStream[searchIndex + 3]) == 1 {
                    
                    if searchIndex != 0 {
                        let unit = H264Unit(payload: dataStream[0..<searchIndex])
                        unitHandler?(unit)
                    }
                    
                    dataStream.removeSubrange(0...searchIndex + 3)
                    searchIndex = 0
                } else if dataStream[searchIndex + 3] != 0 {
                    searchIndex += 4
                } else {
                    searchIndex += 1
                }
            }
        }
    }
}
