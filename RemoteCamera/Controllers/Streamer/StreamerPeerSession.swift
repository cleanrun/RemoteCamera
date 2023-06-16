//
//  StreamerPeerSession.swift
//  RemoteCamera
//
//  Created by cleanmac on 16/06/23.
//

import Foundation
import MultipeerConnectivity

protocol StreamerPeerSessionDelegate: AnyObject {
    
    /// Handle incoming command request from the host.
    /// - Parameters:
    ///   - didReceiveCommand: The command request received from the host peer.
    ///   - host: The host ID who sends the command.
    func session(didReceiveCommand: PeerRequest, from host: MCPeerID)
    
    /// Handle incoming invitaiton from a specific host peer.
    /// - Parameter from: The host peer ID who invited this peer.
    /// - Returns: The invitation status. Return `true` if you want to accept the invitation, and `false` if you want to reject the invitation.
    func session(didReceiveInvitation from: MCPeerID) -> Bool
}

/// A helper object to manage streamer session, receiving commands, etc.
final class StreamerPeerSession: NSObject {
    
    weak var delegate: StreamerPeerSessionDelegate?
    
    /// The ID of this peer device
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    
    /// An advertiser object to make this device discoverable to other peers.
    private let peerAdvertiser: MCNearbyServiceAdvertiser
    
    /// The current peer session.
    private let peerSession: MCSession
    
    /// The ID of the connected host peer.
    private var connectedHost: MCPeerID? = nil
    
    override init() {
        peerSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        peerAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: bonjourServiceType)
        
        super.init()
        
        peerSession.delegate = self
        peerAdvertiser.delegate = self
    }
    
    /// Start advertising this peer so other peers can find it.
    func startAdvertising() {
        peerAdvertiser.startAdvertisingPeer()
    }
    
    /// Stop advertising this peer so others unable to find it.
    func stopAdvertising() {
        peerAdvertiser.stopAdvertisingPeer()
    }
    
    /// Send a file from a specific local URL.
    /// - Parameters:
    ///   - url: The location of the file to send.
    ///   - name: The name of the file.
    /// - Returns: The progress of the sending process.
    @discardableResult
    func sendResourceFile(in url: URL, name: String) throws -> Progress? {
        if let connectedHost {
            return peerSession.sendResource(at: url, withName: name, toPeer: connectedHost)
        } else {
            throw "No connected host"
        }
    }
    
}

// MARK: - Peer Session delegate

extension StreamerPeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        connectedHost = session.connectedPeers.first
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        PeerRequestCommands.handleIncomingData(data: data) { [weak self] request in
            if let self {
                self.delegate?.session(didReceiveCommand: request, from: peerID)
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    
}

// MARK: - Nearby Advertiser delegate

extension StreamerPeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        if let invitationStatus = delegate?.session(didReceiveInvitation: peerID) {
            invitationHandler(invitationStatus, peerSession)
        }
    }
    
}
