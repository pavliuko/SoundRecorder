//
//  SmartSoundRecorder.swift
//  SoundRecorderTestApp
//
//  Created by Aleksandr Pavliuk on 9/28/17.
//  Copyright © 2017 AP. All rights reserved.
//

final class SmartSoundRecorder: NSObject, SoundDevice, EZMicrophoneDelegate {
    
    enum RecordState {
        case ready, recording, ended
    }
    
    private var ezMicrophone: EZMicrophone?
    
    private var soundBufferCallback: (UnsafeMutablePointer<Float>, UInt32) -> Void
    private var processEndedCallback: () -> Void
    
    private var recordState = RecordState.ready
    
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioQueue: AudioQueueRef? = nil
    private var format = AudioStreamBasicDescription()
    private var audioFileID: AudioFileID? = nil
    private var currentByte: Int64 = 0
    
    private let callback: AudioQueueInputCallback = {
        userData, queue, bufferRef, startTimeRef, numPackets, packetDescriptions in
        
        guard let userData = userData else { return }
        let audioRecorder = Unmanaged<SmartSoundRecorder>.fromOpaque(userData).takeUnretainedValue()
        
        let buffer = bufferRef.pointee
        let startTime = startTimeRef.pointee

        var power: Float? = {
            var meters = [AudioQueueLevelMeterState(mAveragePower: 0, mPeakPower: 0)]
            var metersSize = UInt32(meters.count * MemoryLayout<AudioQueueLevelMeterState>.stride)
            let meteringProperty = kAudioQueueProperty_CurrentLevelMeterDB
            let meterStatus = AudioQueueGetProperty(queue, meteringProperty, &meters, &metersSize)
            guard meterStatus == 0 else { return nil }
            return meters[0].mAveragePower
        }()
        
        if let power = power, power > -50.0, audioRecorder.recordState != .ended {
            audioRecorder.recordState = .recording
            
            var ioBytes: UInt32 = audioRecorder.format.mBytesPerPacket * numPackets
            
            AudioFileWriteBytes(audioRecorder.audioFileID!,
                                false,
                                Int64(audioRecorder.currentByte),
                                &ioBytes,
                                buffer.mAudioData)
            
            audioRecorder.currentByte += Int64(ioBytes)
        }
        
        if let power = power, power <= -50.0, audioRecorder.recordState == .recording {
            audioRecorder.recordState = .ended
            audioRecorder.processEndedCallback()
        }
        
        
        if let queue = audioRecorder.audioQueue {
            AudioQueueEnqueueBuffer(queue, bufferRef, 0, nil)
        }
    }
    
    func stop() {
        try! stopRecording()
    }

    func process() throws {
        try startRecording()
    }

    init(soundBufferCallback: @escaping SoundDevice.SoundBufferCallback, processEndedCallback: @escaping () -> ()) {
        
        self.soundBufferCallback = soundBufferCallback
        self.processEndedCallback = processEndedCallback
        
        var formatFlags = AudioFormatFlags()
        formatFlags |= kLinearPCMFormatFlagIsSignedInteger
        formatFlags |= kLinearPCMFormatFlagIsPacked
        format = AudioStreamBasicDescription(
            mSampleRate: 16000.0,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: formatFlags,
            mBytesPerPacket: UInt32(1*MemoryLayout<Int16>.stride),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(1*MemoryLayout<Int16>.stride),
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        
        super.init()
        
        ezMicrophone = EZMicrophone(delegate: self)
    }
    
    private func prepareToRecord() {
        currentByte = 0
        recordState = .ready
        
        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        AudioQueueNewInput(&format, callback, pointer, nil, nil, 0, &audioQueue)
        
        guard let queue = audioQueue else { return }
        
        var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.stride)
        AudioQueueGetProperty(queue, kAudioQueueProperty_StreamDescription, &format, &formatSize)
        
        let numBuffers = 5
        let bufferSize = deriveBufferSize(seconds: 0.5)
        for _ in 0..<numBuffers {
            let bufferRef = UnsafeMutablePointer<AudioQueueBufferRef?>.allocate(capacity: 1)
            AudioQueueAllocateBuffer(queue, bufferSize, bufferRef)
            if let buffer = bufferRef.pointee {
                AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
            }
        }
        
        var metering: UInt32 = 1
        let meteringSize = UInt32(MemoryLayout<UInt32>.stride)
        let meteringProperty = kAudioQueueProperty_EnableLevelMetering
        AudioQueueSetProperty(queue, meteringProperty, &metering, meteringSize)
        
        AudioFileCreateWithURL(urlForRecordedTrack as CFURL,
                               kAudioFileWAVEType,
                               &format,
                               AudioFileFlags.eraseFile,
                               &audioFileID)
    }
    
    func startRecording() throws {
        
        try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
        
        self.prepareToRecord()
        guard let queue = self.audioQueue else { return }
        AudioQueueStart(queue, nil)
        
        
        ezMicrophone?.startFetchingAudio()
    }
    
    func stopRecording() throws {
        guard let queue = audioQueue else { return }
        AudioQueueStop(queue, true)
        AudioQueueDispose(queue, false)
        AudioFileClose(audioFileID!)
        
        ezMicrophone?.stopFetchingAudio()
    }
    
    private func deriveBufferSize(seconds: Float64) -> UInt32 {
        guard let queue = audioQueue else { return 0 }
        let maxBufferSize = UInt32(0x50000)
        var maxPacketSize = format.mBytesPerPacket
        if maxPacketSize == 0 {
            var maxVBRPacketSize = UInt32(MemoryLayout<UInt32>.stride)
            AudioQueueGetProperty(
                queue,
                kAudioQueueProperty_MaximumOutputPacketSize,
                &maxPacketSize,
                &maxVBRPacketSize
            )
        }
        
        let numBytesForTime = UInt32(format.mSampleRate * Float64(maxPacketSize) * seconds)
        let bufferSize = (numBytesForTime < maxBufferSize ? numBytesForTime : maxBufferSize)
        return bufferSize
    }
    
    //MARK: EZMicrophoneDelegate
    func microphone(_ microphone: EZMicrophone!,
                    hasAudioReceived buffer: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!,
                    withBufferSize bufferSize: UInt32,
                    withNumberOfChannels numberOfChannels: UInt32) {
        self.soundBufferCallback(buffer[0]!, bufferSize)
    }
}
