//
//  MainView.swift
//  Nutshell
//
//  Created by Laurin Brandner on 25.05.23.
//

import SwiftUI
import ScreenCaptureKit
import Combine

private var dateFormatter = DateFormatter()

struct MainView: View {
    
    var transcriber = Transcriber()
    @State var recording = false
    @State var transcript = ""
    @State private var searchQuery = ""
    
    @State private var selectedMeeting: Meeting?
    @State var meetings = [Meeting]()
    
    @State private var subscriptions = Set<AnyCancellable>()
    
    init() {
        let fileManager = FileManager.default
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!.path()
        do {
            let items = try fileManager.contentsOfDirectory(atPath: dir)
            let decoder = JSONDecoder()
            meetings = try items.map { path in
                let url = URL(filePath: path)
                let data = try Data(contentsOf: url)
                return try! decoder.decode(Meeting.self, from: data)
            }
        }
        catch {
            print(error)
        }
    }
    
    var body: some View {
        NavigationSplitView(sidebar: sidebar, detail: detail)
        .toolbar(content: toolbar)
        .navigationTitle("Nutshell")
        .onAppear {
            transcriber.updateAvailableContent()
            transcriber.$transcript
                .throttle(for: 1, scheduler: RunLoop.main, latest: true)
                .map { $0.reduce("", +) }
                .assign(to: \.transcript, on: self)
                .store(in: &subscriptions)
        }
        .onDisappear(perform: save)
    }
    
    func toolbar() -> some ToolbarContent {
        ToolbarItemGroup {
            TextField("􀊫 Search", text: $searchQuery)
                .onExitCommand { searchQuery = "" }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(minWidth: 250)
            Button(recording ? "Stop recording" : "Start recording", action: {
                if recording {
                    transcriber.stopRecording()
                }
                else {
                    transcriber.startRecording()
                }
                recording = !recording
            })
            .buttonStyle(.bordered)
        }
    }
    
    func sidebar() -> some View {
        List(selection: $selectedMeeting) {
            ForEach(Array(meetings.sorted()), id: \.self) { meeting in
                NavigationLink(value: meeting) {
                    VStack {
                        HStack {
                            Text(meeting.title)
                                .bold()
                                .lineLimit(2)
                            Text(dateFormatter.string(from: meeting.date))
                        }
                        Text(verbatim: meeting.text)
                            .lineLimit(3)
                    }
                }
            }
        }
    }
    
    func detail() -> some View {
        ScrollView {
            Text(verbatim: transcript)
                .font(.system(.body, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
    
    func save() {
        if transcript.lengthOfBytes(using: .utf8) > 0 {
            let fileManager = FileManager.default
            let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let encoder = JSONEncoder()
            do {
                for meeting in meetings {
                    let fileName = dateFormatter.string(from: meeting.date)
                    let url = dir.appending(path: "\(fileName).json")
                    let data = try encoder.encode(meeting)
                    try data.write(to: url)
                }
            }
            catch {
                print(error)
            }
        }
    }
    
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vulputate semper lorem eget aliquam. Vivamus nulla turpis, interdum quis eleifend sed, sagittis sed felis. In ac velit pretium, facilisis erat quis, ullamcorper nulla. Vivamus non est sem. Nulla placerat, tortor vel tincidunt pretium, eros erat posuere risus, hendrerit commodo dui tortor eu ante. Nulla facilisi. Maecenas id neque ac dui rhoncus sollicitudin. Vestibulum mi leo, commodo eu posuere sed, consectetur sit amet massa. Suspendisse sit amet tempor quam. Vestibulum scelerisque massa massa, vel congue ex aliquet quis. Suspendisse fermentum erat id sem ornare pharetra. Aliquam sit amet nisl eget dui interdum tincidunt."
        let meeting = Meeting(date: Date.now, title: "Super cool meeting", text: text)
        
//        MainView(transcript: text, meetings: [meeting])
        MainView()
    }
}