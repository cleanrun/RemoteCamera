//
//  HostPeerSession.swift
//  RemoteCamera
//
//  Created by cleanmac on 16/06/23.
//

import Foundation
import MultipeerConnectivity

protocol HostPeerSessionDelegate: AnyObject {
    /// Handle incoming command request from the host.
    /// - Parameters:
    ///   - didReceiveCommand: The command request received from the host peer.
    ///   - host: The host ID who sends the command.
    func session(didReceiveCommand: PeerRequest, from host: MCPeerID)
    
    /// Called when a resource sending process has started.
    /// - Parameters:
    ///   - withName: The name of the resource.
    ///   - peer: The peer that sent the resource.
    ///   - progress: The resource sending progress.
    func session(didStartReceivingResource withName: String, from peer: MCPeerID, with progress: Progress)
    
    /// Called when a resource sending process has finished.
    /// - Parameters:
    ///   - withName: The name of the resource.
    ///   - peer: The peer that sent the resource.
    ///   - localURL: The temporary URL to store the received file.
    ///   - error: An error of the receiving process.
    func session(didFinishReceivingResource withName: String, from peer: MCPeerID, at temporaryURL: URL?, error: Error?)
    
    /// Called when the browser found an available peer.
    /// - Parameter id: The peer id that is available to connect.
    func session(foundPeer id: MCPeerID)
    
    /// Called when the browser lost an available peer.
    /// - Parameter id: The peer id that is lost.
    func session(lostPeer id: MCPeerID)
}

// MARK: - Optional protocol functions

extension HostPeerSessionDelegate {
    func session(foundPeer id: MCPeerID) {}
    func session(lostPeer id: MCPeerID) {}
}

final class HostPeerSession: NSObject {
    
    weak var delegate: HostPeerSessionDelegate?
    
    /// The peer ID for this device
    private let peerID: MCPeerID
    
    /// An browser object for browsing streamer peers
    private let peerBrowser: MCNearbyServiceBrowser
    
    /// The current peer session
    private let peerSession: MCSession
    
    /// A view controller to browse and invite available peers
    private let peerBrowserVC: MCBrowserViewController
    
    /// The connected peer IDs to this host peer
    private var connectedPeers: [MCPeerID] = []
    
    override init() {
        peerID = MCPeerID(displayName: UIDevice.current.name)
        peerSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        peerBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: bonjourServiceType)
        peerBrowserVC = MCBrowserViewController(serviceType: bonjourServiceType, session: peerSession)
        
        super.init()
        
        peerSession.delegate = self
        peerBrowser.delegate = self
        peerBrowserVC.delegate = self
    }
    
    /// Invites an available peer.
    ///
    /// Only use this function if you do not use `MCBrowserViewController` to get the available peers.
    /// - Parameter peerID: The peer to invite.
    func invite(_ peerID: MCPeerID) {
        peerBrowser.invitePeer(peerID, to: peerSession, withContext: nil, timeout: 30)
    }
}

// MARK: - Session delegate

extension HostPeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        connectedPeers = session.connectedPeers
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        PeerRequestCommands.handleIncomingData(data: data) { request in
            delegate?.session(didReceiveCommand: request, from: peerID)
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        delegate?.session(didStartReceivingResource: resourceName, from: peerID, with: progress)
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        delegate?.session(didFinishReceivingResource: resourceName, from: peerID, at: localURL, error: error)
    }
    
}

// MARK: - Service Browser delegate

extension HostPeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        delegate?.session(foundPeer: peerID)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        delegate?.session(lostPeer: peerID)
    }
}

// MARK: - Browser View Controller delegate

extension HostPeerSession: MCBrowserViewControllerDelegate {
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true)
    }
}
