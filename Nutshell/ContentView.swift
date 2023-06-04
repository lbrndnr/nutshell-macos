//
//  ContentView.swift
//  Nutshell
//
//  Created by Laurin Brandner on 25.05.23.
//

import SwiftUI
import ScreenCaptureKit
import Combine

struct ContentView: View {
    
    @StateObject var transcriber = Transcriber()
    @State var recording = false
    @State private var searchQuery = ""
    
    var body: some View {
        ScrollView {
            Text(verbatim: transcriber.transcript)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toolbar {
            ToolbarItemGroup {
                TextField("􀊫 Search", text: $searchQuery)
                    .onExitCommand { searchQuery = "" }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minWidth: 250)
                Button(recording ? "Stop recording" : "Start recording", action: {
                    Task {
                        if recording {
                            transcriber.stopRecording()
                            recording = !recording
                        }
                        else {
                            recording = !recording
                            await transcriber.startRecording()
                        }
                    }
                })
                .buttonStyle(.bordered)
            }
        }
        .navigationTitle("Nutshell")
        .onAppear {
            self.transcriber.updateAvailableContent()
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
