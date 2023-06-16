//
//  PeerRequest.swift
//  RemoteCamera
//
//  Created by cleanmac on 06/06/23.
//

import Foundation

struct PeerRequest: Codable {
    let type: PeerRequestType
    let data: Data
    
    /// A String representation of the data
    var dataToString: String? {
        String(data: data, encoding: .utf8)
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case data
    }
    
    fileprivate init(type: PeerRequestType, data: Data) {
        self.type = type
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(PeerRequestType.self, forKey: .type)
        data = try values.decode(Data.self, forKey: .data)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(data, forKey: .data)
    }
}

/// Creates a request to change the streamers recording status
/// - Parameter status: The status to change
/// - Returns: Returns a `PeerRequest` object based on the requirements
func PeerRequestMakeChangeRecordingStatusRequest(_ status: RecordingState) -> PeerRequest {
    PeerRequest(type: .changeRecordingStatus, data: status.rawValue.data(using: .utf8)!)
}

/// Creates a request to send a video frame data
/// - Parameter image: The video frame data, this should be a `CGImage` converted to `Data`
/// - Returns: Returns a `PeerRequest` object based on the requirements
func PeerRequestMakeSendVideoFrameRequest(_ image: Data) -> PeerRequest {
    PeerRequest(type: .sendVideoPreviewFrame, data: image)
}

/// Creates a request to send a video frame data
/// - Parameter image: The video frame data, this should be a `CGImage` converted to `Data`
/// - Returns: Returns a `PeerRequest` object based on the requirements
func PeerRequestMakeChangeFPSRequest(_ fps: FPSState) -> PeerRequest {
    PeerRequest(type: .changeFPS, data: fps.rawValue.data(using: .utf8)!)
}
