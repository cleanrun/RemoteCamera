//
//  HostViewController.swift
//  RemoteCamera
//
//  Created by cleanmac on 06/06/23.
//

import UIKit
import Combine
import AVFoundation

class HostViewController: UIViewController {
    
    /// A button to connect and disconnect from a streamer
    @IBOutlet private weak var connectButton: UIButton!
    
    /// An indicator label to indictate the current connection status
    @IBOutlet private weak var connectionStatusLabel: UILabel!
    
    /// A button to start and stop recording the video
    @IBOutlet private weak var recordButton: UIButton!
    
    /// A button to see the sent video from a streamer
    @IBOutlet private weak var seeVideoButton: UIButton!
    
    /// A segmented control to switch FPS modes for the streamer peers
    @IBOutlet weak var fpsSegmentedControl: UISegmentedControl!
    
    /// A view that will have a `CALayer` acting as the preview layer for a connected streamer peer camera feed
    @IBOutlet weak var previewLayerView: UIView!
    
    /// A `CALayer` to display incoming video frame buffers from a stream
    private var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer!
    
    private var viewModel: HostViewModel!
    private var disposables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel = HostViewModel(viewController: self)
        setupBindings()
        setupUI()
    }
    
    /// Sets up the UI components
    private func setupUI() {
        fpsSegmentedControl.addTarget(self, action: #selector(segmentedControlAction(_:)), for: .valueChanged)
        
        //previewLayerView.layer.contentsGravity = .resizeAspectFill
        
        sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
        sampleBufferDisplayLayer.bounds = previewLayerView.bounds
        sampleBufferDisplayLayer.position = CGPoint(x: CGRectGetMidX(previewLayerView.bounds), y: CGRectGetMidY(previewLayerView.bounds))
        sampleBufferDisplayLayer.videoGravity = .resizeAspect
        previewLayerView.layer.addSublayer(sampleBufferDisplayLayer)
    }
    
    /// Sets up the property observers from the view model
    private func setupBindings() {
        viewModel
            .$connectedPeers
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard !value.isEmpty else {
                    self?.connectionStatusLabel.text = "Not connected"
                    self?.recordButton.isHidden = true
                    //self?.fpsSegmentedControl.isHidden = true
                    self?.connectButton.setTitle("Connect", for: .normal)
                    return
                }
                
                let peers = String(describing: value.map{ $0.displayName })
                self?.connectionStatusLabel.text = "Connected to: \(peers)"
                self?.recordButton.isHidden = false
                //self?.fpsSegmentedControl.isHidden = false
                self?.connectButton.setTitle("Disconnect", for: .normal)
            }.store(in: &disposables)
        
        viewModel
            .$recordingState
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.recordButton.setTitle(value == .isRecording ? "Stop Recording" : "Start Recording", for: .normal)
            }.store(in: &disposables)
    }
    
    /// Sets the preview layer view using the received video frame data
    /// - Parameter data: The data received from the streamer peer
    func setPreviewLayerContents(using data: Data) {
        let imageSource = CGImageSourceCreateWithData(data as CFData, nil)
        let imageData = CGImageSourceCreateImageAtIndex(imageSource!, 0, nil)
        DispatchQueue.main.async { [unowned self] in
            self.previewLayerView.layer.contents = imageData
        }
    }
    
    /// Shows the peer browser modal to browse available peers to connect
    private func showPeerBrowserModal() {
        present(viewModel.peerBrowserVc, animated: true)
    }
    
    func enqueueSampleBufferLayer(_ sbuf: CMSampleBuffer) {
        sampleBufferDisplayLayer.enqueue(sbuf)
    }
    
    @IBAction private func buttonActions(_ sender: UIButton) {
        if sender == connectButton {
            if viewModel.connectedPeers.isEmpty {
                showPeerBrowserModal()
            } else {
                viewModel.disconnectFromPeer()
            }
        } else if sender == recordButton {
            viewModel.changeRecordingState()
        } else if sender == seeVideoButton {
            //viewModel.showVideoResolutionAlert()
        }
    }
    
    @objc private func segmentedControlAction(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        
        switch index {
        case 0:
            viewModel.changeFPSState(.sixty)
        case 1:
            viewModel.changeFPSState(.oneTwenty)
        case 2:
            viewModel.changeFPSState(.twoFourty)
        default:
            break
        }
    }

}
