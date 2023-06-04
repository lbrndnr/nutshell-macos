//
//  Transcriber.swift
//  Nutshell
//
//  Created by Laurin Brandner on 02.06.23.
//

import Foundation
import AVFoundation
import ScreenCaptureKit
import Combine

private let sampleRate = 16000

@objc class Transcriber: NSObject, ObservableObject {
    
    var recording = false
    private var whisper = try! Whisper(path: Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin")!.path)
    private var stream: SCStream?
    private var availableContent: SCShareableContent?
    
    private var buffer = [Float]()
    private var oldBuffer = [Float]()
    
    @Published private(set) var transcript = String()
    
    func updateAvailableContent() {
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
            if let error = error {
                switch error {
                    case SCStreamError.userDeclined: self.requestPermissions()
                    default: print("[err] failed to fetch available content:", error.localizedDescription)
                }
                return
            }
            self.availableContent = content
            assert(self.availableContent?.displays.isEmpty != nil, "There needs to be at least one display connected")
        }
    }
    
    func requestPermissions() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Nutshell needs permissions!"
            alert.informativeText = "Nutshell needs screen recording permissions, even if you only intend on recording audio."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "No thanks, quit")
            alert.alertStyle = .informational
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            }
            NSApp.terminate(self)
        }
    }
    
    func startRecording() async {
        let conf = SCStreamConfiguration()
        conf.capturesAudio = true
        conf.sampleRate = sampleRate
        conf.channelCount = 1
        
        let excluded = self.availableContent?.applications.filter { app in
            Bundle.main.bundleIdentifier == app.bundleIdentifier
        }
        let screen = availableContent!.displays.first!
        let filter = SCContentFilter(display: screen, excludingApplications: excluded ?? [], exceptingWindows: [])

        stream = SCStream(filter: filter, configuration: conf, delegate: self)
        try! stream!.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
        try! stream!.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
        try! await stream!.startCapture()
        
        recording = true
    }
    
    func stopRecording() {
        print("STOPPPIIING")
        stream!.stopCapture()
        recording = false
    }
    
    // https://developer.apple.com/documentation/screencapturekit/capturing_screen_content_in_macos
    func createPCMBuffer(for sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        var ablPointer: UnsafePointer<AudioBufferList>?
        try? sampleBuffer.withAudioBufferList { audioBufferList, blockBuffer in
            ablPointer = audioBufferList.unsafePointer
        }
        
        guard let audioBufferList = ablPointer,
              let absd = sampleBuffer.formatDescription?.audioStreamBasicDescription,
              let format = AVAudioFormat(standardFormatWithSampleRate: absd.mSampleRate, channels: absd.mChannelsPerFrame) else { return nil }
        return AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: audioBufferList)
    }

}

extension Transcriber: SCStreamDelegate, SCStreamOutput {
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        guard let samples = createPCMBuffer(for: sampleBuffer) else { return }
        
        let arraySize = Int(samples.frameLength)
        let data = Array(UnsafeBufferPointer(start: samples.floatChannelData![0], count:arraySize))
        buffer.append(contentsOf: data)
        
        let n_samples_new = buffer.count
        let n_samples_step = 3 * sampleRate
        let n_samples_len = 5 * sampleRate
        let n_samples_keep = n_samples_step
        let n_samples_take = min(oldBuffer.count, max(0, n_samples_keep + n_samples_len - n_samples_new))
        
        if buffer.count > n_samples_step {
            Task {
                var frame = oldBuffer + buffer
                if frame.count > n_samples_new + n_samples_take {
                    frame = Array(frame[frame.count-1-n_samples_take-n_samples_new...frame.count-1])
                }
                
                let text = await whisper.transcribe(samples: frame)
                transcript.append(text)
            }
            
            oldBuffer = buffer
            buffer = []
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) { // stream error
        DispatchQueue.main.async {
            print("closing stream with error:", error)
            print("this might be due to the window closing")
            self.stopRecording()
        }
    }
    
}
