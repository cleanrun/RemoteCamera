//
//  Enums.swift
//  RemoteCamera
//
//  Created by cleanmac on 06/06/23.
//

import Foundation

enum RecordingState: String {
    case notRecording = "Not recording"
    case prepareForRecording = "Prepare for recording"
    case isRecording = "Is recording"
    case finishedRecording = "Finished recording"
}

enum PeerRequestType: String, Codable {
    case changeRecordingStatus
    case sendVideoPreviewFrame
    case changeFPS
}

enum FPSState: String, Codable {
    case twentyFour = "24"
    case sixty = "60"
    case oneTwenty = "120"
    case twoFourty = "240"
}

enum NALUType {
    case sps
    case pps
    case vcl
}

enum EncoderConfigurationError: Error {
    case failedCreateSession
    case failedSetProperties
    case cannotPrepareToEncode
}
