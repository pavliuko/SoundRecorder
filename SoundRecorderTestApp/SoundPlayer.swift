//
//  SoundPlayer.swift
//  SoundRecorderTestApp
//
//  Created by Aleksandr Pavliuk on 9/27/17.
//  Copyright © 2017 AP. All rights reserved.
//

import AVFoundation

final class Player: NSObject, SoundDevice, EZAudioPlayerDelegate {
    
    private var player: EZAudioPlayer?
    private var callback: (UnsafeMutablePointer<Float>, UInt32) -> Void
    private var processEndedCallback: () -> Void
    
    init(soundBufferCallback: @escaping SoundBufferCallback, processEndedCallback: @escaping() -> ()) {
        
        callback = soundBufferCallback
        self.processEndedCallback = processEndedCallback
        
        super.init()
    }

    func process() throws {
        try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
        try AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
        
        guard FileManager.default.fileExists(atPath: urlForRecordedTrack.path) else { return }
        guard let audioFile = EZAudioFile(url: urlForRecordedTrack) else { return }
        player = EZAudioPlayer(audioFile: audioFile, delegate: self)
        
        player?.play()
    }

    func stop() {
        player?.pause()
    }
    
    //MARK: EZAudioPlayerDelegate
    func audioPlayer(_ audioPlayer: EZAudioPlayer!,
                     playedAudio buffer: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!,
                     withBufferSize bufferSize: UInt32,
                     withNumberOfChannels numberOfChannels: UInt32,
                     in audioFile: EZAudioFile!) {
        callback(buffer[0]!, bufferSize)
    }
    
    func audioPlayer(_ audioPlayer: EZAudioPlayer!, reachedEndOf audioFile: EZAudioFile!) {
        self.processEndedCallback()
    }
}
