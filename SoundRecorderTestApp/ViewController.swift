//
//  ViewController.swift
//  SoundRecorderTestApp
//
//  Created by Aleksandr Pavliuk on 9/27/17.
//  Copyright © 2017 AP. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var plotView: EZAudioPlotGL!
    @IBOutlet weak var recorderSegmentControl: UISegmentedControl!
    
    var recorder: SoundDevice?
    var smartRecorder: SmartSoundRecorder?
    var player: SoundDevice?
    
    enum Permissions {
        case granded, denied, undefined
    }
    var recordPermissions: Permissions = .undefined
    
    enum State {
        case recording, playing, idle
    }
    
    var state: State = .idle {
        didSet {
            switch state {
            case .recording:
                startButton.isEnabled = false
                stopButton.isEnabled = true
                playButton.isEnabled = false
            case .playing:
                startButton.isEnabled = false
                stopButton.isEnabled = true
                playButton.isEnabled = false
                
            default:
                startButton.isEnabled = true
                stopButton.isEnabled = false
                playButton.isEnabled = true
            }
        }
    }
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    
    @IBAction func playAction(_ sender: Any) {
        do {
            try player?.process()
        }
        catch {
            showErrorAlerWithMessage("Fail to play")
            return
        }
        state = .playing
    }
    
    @IBAction func startAction(_ sender: Any) {
        
        do {
            try selectedRecorder()?.process()
        }
        catch {
            showErrorAlerWithMessage("Fail to record")
            return
        }
        state = .recording
    }
    
    @IBAction func stopAction(_ sender: Any) {
        stop()
    }
    
    func stop() {
        switch state {
        case .recording:
            selectedRecorder()?.stop()
        case .playing:
            player?.stop()
        default:
            fatalError("Internal logic error")
        }
        
        state = .idle
    }
    
    func selectedRecorder() -> SoundDevice? {
        switch (recordPermissions, recorderSegmentControl.selectedSegmentIndex) {
        case (.granded, 0): return recorder
        case (.granded, 1): return smartRecorder
        default: return nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let callback: SoundDevice.SoundBufferCallback = { [weak self] (buffer, bufferSize) in
            DispatchQueue.main.async(execute: { () -> Void in
                self?.plotView?.updateBuffer(buffer, withBufferSize: bufferSize)
            })
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission {
            if $0 == true {
                self.recordPermissions = .granded
            } else {
                self.recordPermissions = .denied
            }
        }
        
        player = Player(soundBufferCallback: callback) { self.stop() }
        recorder = Recorder(soundBufferCallback: callback) {}
        smartRecorder = SmartSoundRecorder(soundBufferCallback: callback) { self.stop() }
        
        plotView?.plotType = EZPlotType.buffer
        state = .idle
    }
    
    func showErrorAlerWithMessage(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Close", style: .default, handler: { action in
            self.navigationController?.popViewController(animated: true)
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
}

