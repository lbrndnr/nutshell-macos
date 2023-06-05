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
    
    var transcriber = Transcriber()
    @State var recording = false
    @State var transcript = ""
    @State private var searchQuery = ""
    
    @State private var subscriptions = Set<AnyCancellable>()
    
    var body: some View {
        ScrollView {
            Text(verbatim: transcript)
                .font(.system(.body, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
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
            transcriber.$transcript
                .receive(on: RunLoop.main)
                .assign(to: \.transcript, on: self)
                .store(in: &subscriptions)
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(transcript: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vulputate semper lorem eget aliquam. Vivamus nulla turpis, interdum quis eleifend sed, sagittis sed felis. In ac velit pretium, facilisis erat quis, ullamcorper nulla. Vivamus non est sem. Nulla placerat, tortor vel tincidunt pretium, eros erat posuere risus, hendrerit commodo dui tortor eu ante. Nulla facilisi. Maecenas id neque ac dui rhoncus sollicitudin. Vestibulum mi leo, commodo eu posuere sed, consectetur sit amet massa. Suspendisse sit amet tempor quam. Vestibulum scelerisque massa massa, vel congue ex aliquet quis. Suspendisse fermentum erat id sem ornare pharetra. Aliquam sit amet nisl eget dui interdum tincidunt.")
    }
}
