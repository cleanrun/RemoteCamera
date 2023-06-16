//
//  PeerRequestCommands.swift
//  RemoteCamera
//
//  Created by cleanmac on 07/06/23.
//

import Foundation
import MultipeerConnectivity

final class PeerRequestCommands {
    
    /// Sends a recording status changing command request
    /// - Parameters:
    ///   - session: The session used to send the request
    ///   - peers: The peers to receive the request
    ///   - status: The recording status to change
    static func sendChangeRecordingStatusCommand(
        using session: MCSession,
        to peers: [MCPeerID],
        status: RecordingState) throws {
            let request = PeerRequestMakeChangeRecordingStatusRequest(status)
            let encoder = JSONEncoder()
            let requestData = try encoder.encode(request)
            try session.send(requestData, toPeers: peers, with: .reliable)
    }
    
    /// Sends a video frame image data command request
    /// - Parameters:
    ///   - session: The session used to send the request
    ///   - peers: The peers to receive the request
    ///   - imageData: The image data to send
    static func sendVideoPreviewFrameCommand(
        using session: MCSession,
        to peers: [MCPeerID],
        imageData: Data) throws {
            let request = PeerRequestMakeSendVideoFrameRequest(imageData)
            let encoder = JSONEncoder()
            let requestData = try encoder.encode(request)
            try session.send(requestData, toPeers: peers, with: .reliable)
    }
    
    /// Sends a FPS changing command request
    /// - Parameters:
    ///   - session: The session used to send the request
    ///   - peers: The peers to receive the request
    ///   - fps: The FPS state to send
    static func sendChangeFPSCommand(
        using session: MCSession,
        to peers: [MCPeerID],
        fps: FPSState) throws {
            let request = PeerRequestMakeChangeFPSRequest(fps)
            let encoder = JSONEncoder()
            let requestData = try encoder.encode(request)
            try session.send(requestData, toPeers: peers, with: .reliable)
    }
    
    /// Handle incoming request data from another peer
    /// - Parameters:
    ///   - data: The incoming data to handle
    ///   - completion: A closure to handle the decoded data
    static func handleIncomingData(data: Data, completion: (PeerRequest) -> Void) {
        do {
            let decoder = JSONDecoder()
            let request = try decoder.decode(PeerRequest.self, from: data)
            completion(request)
        } catch {
            print("error receiving data: \(error.localizedDescription)")
        }
    }
    
}
