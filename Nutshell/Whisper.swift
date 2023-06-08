//
//  Whisper.swift
//  Nutshell
//
//  Created by Laurin Brandner on 25.05.23.
//

import Foundation
import whisper

enum WhisperError: Error {
    case couldNotInitializeContext
}

class Whisper {
    
    private var context: OpaquePointer
    
    var currentTokens: [Int32] {
        let segmentCount = whisper_full_n_segments(context)
        return (0 ..< segmentCount)
            .map { ($0, whisper_full_n_tokens(context, $0)) }
            .map { whisper_full_get_token_id(context, $0, $1) }
    }
    
    init(path: String) throws {
        guard let context = whisper_init_from_file(path) else {
            throw WhisperError.couldNotInitializeContext
        }
        
        self.context = context
    }
    
    deinit {
        whisper_free(context)
    }
    
    func transcribe(samples: [Float]) -> String {
        // Leave 2 processors free (i.e. the high-efficiency cores).
        let cpuCount = ProcessInfo.processInfo.processorCount
        let maxThreads = max(1, min(8, cpuCount - 2))
        "en".withCString { en in
//            prompts.withUnsafeBufferPointer { promptsPointer in
            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            params.print_realtime = false
            params.print_progress = false
            params.print_timestamps = false
            params.print_special = false
            params.translate = false
            params.single_segment = true
            params.max_tokens = 32
            params.language = en
            params.n_threads = Int32(maxThreads)
            
//                params.temperature_inc = 0.0
//                params.prompt_tokens = promptsPointer.baseAddress
//                params.prompt_n_tokens = Int32(prompts.count)
            
            samples.withUnsafeBufferPointer { samples in
                if (whisper_full(context, params, samples.baseAddress, Int32(samples.count)) != 0) {
                    print("Failed to run the model")
                }
            }
        }
        
        var transcription = ""
        for i in 0..<whisper_full_n_segments(context) {
            transcription += String.init(cString: whisper_full_get_segment_text(context, i))
        }
        return transcription
    }
    
}
