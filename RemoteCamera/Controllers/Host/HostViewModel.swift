//
//  HostViewModel.swift
//  RemoteCamera
//
//  Created by cleanmac on 06/06/23.
//

import Foundation
import MultipeerConnectivity
import AVKit

final class HostViewModel: NSObject, ObservableObject {
    /// The peer ID for this device
    private let peerId = MCPeerID(displayName: UIDevice.current.name)
    
    /// An browser object for browsing streamer peers
    private let peerBrowser: MCNearbyServiceBrowser
    
    /// The current peer session
    private let peerSession: MCSession
    
    /// A view controller to browse and invite available peers
    let peerBrowserVc: MCBrowserViewController
    
    private weak var viewController: HostViewController?
    
    let fileUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("output.mov")
    
    /// The connected peer IDs to this host peer
    @Published private(set) var connectedPeers: [MCPeerID] = []
    
    /// The current recording state of the recording process
    @Published private(set) var recordingState: RecordingState = .notRecording
    
    /// The current FPS of the streamer
    @Published private(set) var fpsState: FPSState = .sixty
    
    /// This is used to observe the resource sending progress
    private var observation: NSKeyValueObservation?
    
    init(viewController: HostViewController) {
        peerSession = MCSession(peer: peerId, securityIdentity: nil, encryptionPreference: .none)
        peerBrowser = MCNearbyServiceBrowser(peer: peerId, serviceType: bonjourServiceType)
        peerBrowserVc = MCBrowserViewController(serviceType: bonjourServiceType, session: peerSession)
        
        self.viewController = viewController
        
        super.init()
        
        peerSession.delegate = self
        peerBrowser.delegate = self
        peerBrowserVc.delegate = self
    }
    
    /// Changes the recording state of the current peer
    func changeRecordingState() {
        do {
            if recordingState == .notRecording {
                recordingState = .isRecording
                try PeerRequestCommands.sendChangeRecordingStatusCommand(using: peerSession, to: connectedPeers, status: .prepareForRecording)
            } else if recordingState == .isRecording {
                recordingState = .finishedRecording
                try PeerRequestCommands.sendChangeRecordingStatusCommand(using: peerSession, to: connectedPeers, status: .finishedRecording)
                recordingState = .notRecording
            }
        } catch {
            print(error.localizedDescription)
            recordingState = .notRecording
        }
    }
    
    /// Disconnects from the connected peer
    func disconnectFromPeer() {
        peerSession.disconnect()
    }
    
    /// Change the current FPS
    ///
    /// This will send a command request to all of the connected streamer peers.
    /// - Parameter fps: The FPS state to change
    func changeFPSState(_ fps: FPSState) {
        fpsState = fps
        do {
            try PeerRequestCommands.sendChangeFPSCommand(using: peerSession, to: connectedPeers, fps: fps)
        } catch {
            print("change FPS error: \(error.localizedDescription)")
        }
    }
    
    /// Send a request to the streamer peers
    /// - Parameter request: The request object to send
    @available(*, unavailable, message: "Use `PeerRequestCommands` to send command requests.")
    func sendPeerRequest(_ request: PeerRequest) throws {
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)
        try peerSession.send(requestData, toPeers: connectedPeers, with: .reliable)
    }
    
}

// MARK: - Session Delegate

extension HostViewModel: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        connectedPeers = session.connectedPeers
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        PeerRequestCommands.handleIncomingData(data: data) { request in
            switch request.type {
            case .sendVideoPreviewFrame:
                viewController?.setPreviewLayerContents(using: request.data)
            default:
                return
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        observation = progress.observe(\.fractionCompleted) { progress, _ in
            // FIXME: If we need a progress bar to indicate the sending process, this will be the starting point to update the bar
            print("completed: \(progress.fractionCompleted), unit count: \(progress.completedUnitCount)")
        }
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        observation = nil
        
        // FIXME: This is only for test purposes, change this soon
        if let localURL {
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                try! FileManager.default.removeItem(atPath: fileUrl.path)
            }
            
            do {
                try FileManager.default.moveItem(at: localURL, to: fileUrl)
            } catch {
                print("error moving file: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                let vc = AVPlayerViewController()
                let player = AVPlayer(url: self.fileUrl)
                vc.player = player
                self.viewController?.present(vc, animated: true) {
                    player.play()
                }
            }
        }
    }
    
}

// MARK: - Service Browser Delegate

extension HostViewModel: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) { }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) { }
    
}

// MARK: - Browser View Controller Delegate

extension HostViewModel: MCBrowserViewControllerDelegate {
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true)
    }
}
