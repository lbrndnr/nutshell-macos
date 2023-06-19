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

class Transcriber: NSObject, ObservableObject, SCStreamDelegate, SCStreamOutput {
    
    var recording = false
    private var whisper = try! Whisper(path: Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin")!.path)
    private var stream: SCStream?
    private var availableContent: SCShareableContent?
    
    private var buffer = [Float]()
    private var oldBuffer = [Float]()
    private var iter = 0
    private var prompts = [Int32]()
    
    @Published private(set) var transcript = [String]()
    private var subscriptions = Set<AnyCancellable>()
    
    private var processQueue = DispatchQueue(label: "ch.laurinbrandner.processAudio")
    private var whisperQueue = DispatchQueue(label: "ch.laurinbrandner.whisper")
    
    func updateAvailableContent() {
        Task {
            do {
                self.availableContent = try await SCShareableContent.current
            }
            catch {
                print(error)
            }
            assert(self.availableContent?.displays.isEmpty != nil, "There needs to be at least one display connected")
        }
//        SCShareableContent.current { content, error in
//            if let error = error {
//                switch error {
//                    case SCStreamError.userDeclined: self.requestPermissions()
//                    default: print("[err] failed to fetch available content:", error.localizedDescription)
//                }
//                return
//            }
//            self.availableContent = content
//            assert(self.availableContent?.displays.isEmpty != nil, "There needs to be at least one display connected")
//        }
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
    
    func startRecording() {
        let conf = SCStreamConfiguration()
        conf.queueDepth = 6
        conf.width = 2
        conf.height = 2
        conf.capturesAudio = true
//        conf.minimumFrameInterval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(1))
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

        transcript = [""]
        recording = true
        Task {
            try! await stream!.startCapture()
        }
    }
    
    func stopRecording() {
        print("STOPPPIIING")
        stream!.stopCapture()
        recording = false
    }
    
    private func process(_ samples: [Float]) {
        buffer.append(contentsOf: samples)
        
        let n_samples_new = buffer.count
        let n_samples_step = 2 * sampleRate
        let n_samples_len = 10 * sampleRate
        let n_samples_keep = sampleRate
        let n_samples_take = min(oldBuffer.count, max(0, n_samples_keep + n_samples_len - n_samples_new))
        
//        print("processing: step = \(n_samples_step), take = \(n_samples_take), new = \(n_samples_new), old = \(oldBuffer.count)")
        
        if buffer.count > n_samples_step {
            oldBuffer = oldBuffer.suffix(n_samples_take) + buffer
            buffer = []
            let frame = oldBuffer
            
            let newLine = max(1, (n_samples_len / n_samples_step) - 1)
            iter += 1
            let startNewLine = (iter % newLine == 0)
            if startNewLine {
                oldBuffer = oldBuffer.suffix(n_samples_keep)
            }
            
            self.whisperQueue.async {
                let text = self.whisper.transcribe(samples: frame)
                self.transcript[self.transcript.count-1] = text
                
                if startNewLine {
                    self.transcript.append("")
                }
            }
        }
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        
        try? sampleBuffer.withAudioBufferList { audioBufferList, blockBuffer in
            guard let absd = sampleBuffer.formatDescription?.audioStreamBasicDescription,
                  let format = AVAudioFormat(standardFormatWithSampleRate: absd.mSampleRate, channels: absd.mChannelsPerFrame),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: audioBufferList.unsafePointer) else { return }
            let arraySize = Int(buffer.frameLength)
            let data = Array<Float>(UnsafeBufferPointer(start: buffer.floatChannelData![0], count:arraySize))
            
            self.processQueue.sync {
                self.process(data)
            }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        stopRecording()
    }
    
}

