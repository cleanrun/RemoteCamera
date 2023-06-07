//
//  StreamerViewModel.swift
//  RemoteCamera
//
//  Created by cleanmac on 06/06/23.
//

import Foundation
import Combine
import CoreMedia
import MultipeerConnectivity

final class StreamerViewModel: NSObject, ObservableObject {
    /// The peer ID for this device
    private let peerId = MCPeerID(displayName: UIDevice.current.name)
    
    /// An advertiser object for the host to find this peer
    private let peerAdvertiser: MCNearbyServiceAdvertiser
    
    /// The current peer session
    private let peerSession: MCSession
    
    /// The object to write buffer frames and locate it into a certain URL
    private var assetWriter: AssetWriter
    
    /// The view controller attached to this view model
    private weak var viewController: StreamerViewController?
    
    /// The local URL of the written file
    let fileUrl: URL
    
    /// The current recording state of the recording process
    @Published private(set) var recordingState: RecordingState = .notRecording
    
    /// The current connected host peer
    @Published private(set) var connectedPeer: MCPeerID? = nil
    
    init(viewController: StreamerViewController) {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        fileUrl = URL(fileURLWithPath: documentsPath.appendingPathComponent("output_video")).appendingPathExtension("mov")
        
        peerSession = MCSession(peer: peerId, securityIdentity: nil, encryptionPreference: .none)
        peerAdvertiser = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: nil, serviceType: bonjourServiceType)
        
        assetWriter = AssetWriter(outputURL: fileUrl)
        
        self.viewController = viewController
        
        super.init()
        
        assetWriter.delegate = self
        peerSession.delegate = self
        peerAdvertiser.delegate = self
        peerAdvertiser.startAdvertisingPeer()
    }
    
    /// Changes the current recording state
    func changeRecordingState(_ state: RecordingState) {
        recordingState = state
    }
    
    /// Process the sample buffer, append the buffers if currently recording a video
    func sampleBufferCallback(_ sbuf: CMSampleBuffer) {
        switch recordingState {
        case .notRecording:
            break
        case .prepareForRecording:
            let sourceTime = CMSampleBufferGetPresentationTimeStamp(sbuf)
            assetWriter.prepareForWriting(at: sourceTime)
            changeRecordingState(.isRecording)
        case .isRecording:
            assetWriter.appendFrames(sbuf)
        case .finishedRecording:
            assetWriter.finishWriting()
            changeRecordingState(.notRecording)
        }
    }
    
    /// A callback function to handle data income from another peer
    /// - Parameters:
    ///   - data: The data received from the peer
    @available(*, unavailable, message: "Use `PeerRequestCommands.handleIncomingData(data:completion:)` to handle incoming data.")
    private func receiveDataCallback(_ data: Data) {
        do {
            let decoder = JSONDecoder()
            let request = try decoder.decode(PeerRequest.self, from: data)
            switch request.type {
            case .changeRecordingStatus:
                let state = RecordingState(rawValue: String(data: request.data, encoding: .utf8)!)!
                changeRecordingState(state)
            default:
                break
            }
        } catch {
            print("error receiving data: \(error.localizedDescription)")
        }
    }
    
    /// Send the recorder video into the host peer
    func sendResourceVideo() {
        if let connectedPeer {
            peerSession.sendResource(at: fileUrl, withName: "output_video", toPeer: connectedPeer)
        }
    }
}

// MARK: Session Delegate

extension StreamerViewModel: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        connectedPeer = session.connectedPeers.first
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        PeerRequestCommands.handleIncomingData(data: data) { request in
            print("type: \(request.type.rawValue)")
            switch request.type {
            case .changeRecordingStatus:
                changeRecordingState(RecordingState(rawValue: request.dataToString!)!)
            case .changeFPS:
                viewController?.configureFrameRate(FPSState(rawValue: request.dataToString!)!)
            default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
}

// MARK: - Service Advertiser Delegate

extension StreamerViewModel: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        viewController?.showInvitationAlert(peerName: peerID.displayName, onAccept: { [unowned self] in
            invitationHandler(true, self.peerSession)
        }, onCancel: { [unowned self] in
            invitationHandler(false, self.peerSession)
        })
    }
}

// MARK: - Asset Writer Delegate

extension StreamerViewModel: AssetWriterDelegate {
    func didFinishWriting() {
        sendResourceVideo()
    }
}
