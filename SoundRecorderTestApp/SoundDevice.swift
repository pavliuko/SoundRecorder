//
//  SoundDevice.swift
//  SoundRecorderTestApp
//
//  Created by Aleksandr Pavliuk on 9/27/17.
//  Copyright © 2017 AP. All rights reserved.
//

protocol SoundDevice {
    
    typealias SoundBufferCallback = (UnsafeMutablePointer<Float>, UInt32) -> Void
    
    init(soundBufferCallback: @escaping SoundBufferCallback, processEndedCallback: @escaping () -> ())
    func process() throws
    func stop()
}
