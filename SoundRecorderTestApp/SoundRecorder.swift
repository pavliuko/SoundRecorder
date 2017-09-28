//
//  SoundRecorder.swift
//  SoundRecorderTestApp
//
//  Created by Aleksandr Pavliuk on 9/27/17.
//  Copyright © 2017 AP. All rights reserved.
//

import AVFoundation

//MARK: It's possible to create sound recording with EZAudioRecorder, but decided to make with native AVAudioRecorder

final class Recorder: NSObject, SoundDevice, EZMicrophoneDelegate, AVAudioRecorderDelegate {
    
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioRecorder: AVAudioRecorder?
    private var ezMicrophone: EZMicrophone?
    private var processEndedCallback: () -> Void
    
    private var soundBufferCallback: (UnsafeMutablePointer<Float>, UInt32) -> Void
    
    init(soundBufferCallback: @escaping SoundDevice.SoundBufferCallback, processEndedCallback: @escaping () -> ()) {
        
        self.soundBufferCallback = soundBufferCallback
        self.processEndedCallback = processEndedCallback
        
        super.init()
        
        ezMicrophone = EZMicrophone(delegate: self)
    }
    
    func prepare() throws {
        
        if audioRecorder != nil { return }
        
        try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
        
            let settings: [String : Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 8,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: urlForRecordedTrack, settings: settings)
            audioRecorder?.delegate = self
    }
    
    func process() throws {
        
        try prepare()
        
        ezMicrophone?.startFetchingAudio()
        audioRecorder?.record()
    }
    
    func stop() {
        audioRecorder?.stop()
        ezMicrophone?.stopFetchingAudio()
        processEndedCallback()
    }
    
    //MARK: EZMicrophoneDelegate
    func microphone(_ microphone: EZMicrophone!,
                    hasAudioReceived buffer: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!,
                    withBufferSize bufferSize: UInt32,
                    withNumberOfChannels numberOfChannels: UInt32) {
        self.soundBufferCallback(buffer[0]!, bufferSize)
    }
}
