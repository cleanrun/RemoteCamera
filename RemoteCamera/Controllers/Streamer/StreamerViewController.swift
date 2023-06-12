//
//  StreamerViewController.swift
//  RemoteCamera
//
//  Created by cleanmac on 06/06/23.
//

import UIKit
import Combine
import AVKit

final class StreamerViewController: UIViewController {
    
    /// An indicator label to indicate the connection status between the host peer
    @IBOutlet private weak var peerStatusLabel: UILabel!
    
    /// A view to preview the camera feed
    @IBOutlet private weak var previewLayerView: UIView!
    
    /// A button to start and stop the recording process
    @IBOutlet private weak var recordButton: UIButton!
    
    /// A button to see the recorded video, if exists
    @IBOutlet private weak var seeVideoButton: UIButton!
    
    /// An indicator label to indicate the recording process status
    @IBOutlet private weak var recordingStatusLabel: UILabel!
    
    /// A capture session for the device's camera
    private(set) var captureSession: AVCaptureSession!
    
    /// The video capture device used for this session
    private(set) var captureDevice: AVCaptureDevice!
    
    /// A layer object to preview the camera buffer stream
    private(set) var previewLayer: AVCaptureVideoPreviewLayer!
    
    /// An object to record a video and write it into a local URL
    private(set) var movieOutput: AVCaptureMovieFileOutput!
    private(set) var movieFileOutputConnection: AVCaptureConnection?
    
    /// An object to get the buffers of each frame from the camera feed
    private(set) var videoDataOutput: AVCaptureVideoDataOutput!
    
    private var captureQueue = DispatchQueue(label: "capture-queue")
    private var viewModel: StreamerViewModel!
    private var disposables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel = StreamerViewModel(viewController: self)
        setupBindings()
        setupPreviewLayer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.global(qos: .background).async { [unowned self] in
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    /// Sets up the property observers from the view model
    private func setupBindings() {
        viewModel
            .$connectedPeer
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] value in
                guard let value else {
                    self?.peerStatusLabel.text = "Not connected"
                    return
                }
                
                self?.peerStatusLabel.text = "Connected to: \(value.displayName)"
            }).store(in: &disposables)
        
        viewModel
            .$recordingState
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.recordingStatusLabel.text = value.rawValue
                let recordButtonText = value == .isRecording ? "Stop recording" : "Start recording"
                self?.recordButton.setTitle(recordButtonText, for: .normal)
            }.store(in: &disposables)
    }
    
    /// Sets up the preview layer and capture sessions
    private func setupPreviewLayer() {
        captureSession = AVCaptureSession()
        // This is set to reduce memory consumption, bigger resolution means more memory consumption
        captureSession.sessionPreset = .hd1280x720
        
        let devices = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices
        
        guard let videoCaptureDevice = devices.first,
              let audioCaptureDevice = AVCaptureDevice.default(for: .audio) else {
            return
        }
        
        captureDevice = videoCaptureDevice
        
        let videoInput: AVCaptureDeviceInput
        let audioInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            audioInput = try AVCaptureDeviceInput(device: audioCaptureDevice)
        } catch {
            return
        }
        
        if captureSession.canAddInput(videoInput),
           captureSession.canAddInput(audioInput) {
            captureSession.addInput(videoInput)
            captureSession.addInput(audioInput)
        } else {
            return
        }
        
        videoDataOutput = AVCaptureVideoDataOutput()
        setupDataOutput()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        DispatchQueue.main.async { [unowned self] in
            self.previewLayer.frame = self.previewLayerView.bounds
            self.previewLayerView.layer.addSublayer(self.previewLayer)
        }
        
        previewLayerView.layer.cornerRadius = 10
        
        captureSession.beginConfiguration()
        for vFormat in videoCaptureDevice.formats {
            let ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
            let frameRate = ranges.first!
            
            if frameRate.maxFrameRate == 240 {
                do {
                    try videoCaptureDevice.lockForConfiguration()
                    videoCaptureDevice.activeFormat = vFormat
                    videoCaptureDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(120))
                    videoCaptureDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(120))
                    videoCaptureDevice.unlockForConfiguration()
                } catch {
                    print("Could not lock for configuration")
                }
            }
        }
        captureSession.commitConfiguration()
    }
    
    /// Configure the video capture device's frame rate
    /// - Parameter rate: The rate to change
    func configureFrameRate(_ rate: FPSState) {
        let rateToInt = Int(rate.rawValue)!
        
        do {
            try captureDevice.lockForConfiguration()
            captureDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(rateToInt))
            captureDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(rateToInt))
            captureDevice.unlockForConfiguration()
        } catch {
            print("Could not lock for configuration")
        }
    }
    
    /// Sets up the data output and add it to the capture session
    private func setupDataOutput() {
        videoDataOutput.videoSettings = [
            String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)
        ]
        
        if captureSession.canAddOutput(videoDataOutput) {
            DispatchQueue.main.async { [unowned self] in
                self.captureSession.addOutput(videoDataOutput)
            }
            videoDataOutput.setSampleBufferDelegate(self, queue: captureQueue)
            videoDataOutput.alwaysDiscardsLateVideoFrames = false
        }
    }
    
    /// Show a video player controller modal
    private func showPlayerModal() {
        //let asset = AVAsset(url: viewModel.fileUrl)
        
        let player = AVPlayer(url: viewModel.fileUrl)
        let vc = AVPlayerViewController()
        vc.player = player
        present(vc, animated: true) {
            player.play()
        }
    }
    
    /// Shows an alert for invitation handling process
    /// - Parameters:
    ///   - peerName: The peer name who sent an invite to this device
    ///   - onAccept: A closure to accept the invitation
    ///   - onCancel: A closure to reject the invitation
    func showInvitationAlert(peerName: String, onAccept: @escaping () -> Void, onCancel: @escaping () -> Void) {
        let alert = UIAlertController(title: "Invitation alert",
                                      message: "\(peerName) just invited you to connect. Do you accept?", preferredStyle: .alert)
        let yesAction = UIAlertAction(title: "Yes", style: .default) { _ in onAccept() }
        let noAction = UIAlertAction(title: "No", style: .destructive) { _ in onCancel() }
        alert.addAction(noAction)
        alert.addAction(yesAction)
        present(alert, animated: true)
    }
    
    @IBAction private func buttonAction(_ sender: UIButton) {
        if sender == recordButton {
            if viewModel.recordingState == .notRecording {
                viewModel.changeRecordingState(.prepareForRecording)
            } else {
                viewModel.changeRecordingState(.finishedRecording)
            }
        } else if sender == seeVideoButton {
            showPlayerModal()
        }
    }
    
    /// Returns a `CMFormatDescription` and recommended settings dictionary to set up an asset writer
    /// - Returns: The format description and recommended settings
    func getFormatDescriptionAndRecommendedSettings() -> (CMFormatDescription, [String: Any]?) {
        return (captureDevice.activeFormat.formatDescription,
                videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov))
    }

}

// MARK: - Video Data Output Delegate

extension StreamerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        viewModel.sampleBufferCallback(sampleBuffer)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // FIXME: Handle dropped frames here, might need some research on how to handle it.
        print("did drop sample buffer")
    }
}

