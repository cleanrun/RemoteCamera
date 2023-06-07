//
//  HostViewController.swift
//  RemoteCamera
//
//  Created by cleanmac on 06/06/23.
//

import UIKit
import Combine

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
                    self?.fpsSegmentedControl.isHidden = true
                    return
                }
                
                let peers = String(describing: value.map{ $0.displayName })
                self?.connectionStatusLabel.text = "Connected to: \(peers)"
                self?.recordButton.isHidden = false
                self?.fpsSegmentedControl.isHidden = false
            }.store(in: &disposables)
        
        viewModel
            .$recordingState
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.recordButton.setTitle(value == .isRecording ? "Stop Recording" : "Start Recording", for: .normal)
            }.store(in: &disposables)
    }
    
    /// Shows the peer browser modal to browse available peers to connect
    private func showPeerBrowserModal() {
        present(viewModel.peerBrowserVc, animated: true)
    }
    
    @IBAction private func buttonActions(_ sender: UIButton) {
        if sender == connectButton {
            showPeerBrowserModal()
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
