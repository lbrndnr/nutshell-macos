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
private var timeFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .positional
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.zeroFormattingBehavior = .pad

    return formatter
}()

struct MainView: View {
    
    var transcriber = Transcriber()
    @State var recording = false
    @State private var durationInfo: String?
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    @State var transcript = ""
    
    @State private var searchQuery = ""
    
    @State private var selectedMeeting: Meeting?
    @Binding var meetings: [Meeting] {
        didSet {
            selectedMeeting = selectedMeeting ?? meetings.first
        }
    }
    
    @State private var subscriptions = Set<AnyCancellable>()
    
    var body: some View {
        NavigationSplitView(sidebar: sidebar, detail: detail)
        .toolbar(content: toolbar)
        .navigationTitle("Nutshell")
        .frame(minWidth: 600)
        .onAppear {
            transcriber.updateAvailableContent()
            transcriber.$transcript
                .throttle(for: 1, scheduler: RunLoop.main, latest: true)
                .map { $0.reduce("", +) }
                .assign(to: \.transcript, on: self)
                .store(in: &subscriptions)
        }
    }
    
    @ViewBuilder fileprivate func toolbar() -> some View {
        TextField("􀊫 Search", text: $searchQuery)
            .onExitCommand { searchQuery = "" }
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 250)
        Button(action: toggleRecording) {
            Image(systemName: "record.circle")
        }
        if let durationInfo = durationInfo {
            Text(durationInfo)
                .monospaced()
        }
    }
    
    @ViewBuilder private func sidebar() -> some View {
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
    
    @ViewBuilder private func detail() -> some View {
        ScrollView {
            Text(verbatim: selectedMeeting?.text ?? transcript)
                .font(.system(.body, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
    
    private func toggleRecording() {
        if recording {
            transcriber.stopRecording()
            let newMeeting = Meeting(date: .now, title: "New Meeting", text: transcript)
            meetings.append(newMeeting)
            timer.upstream.connect().cancel()
            durationInfo = nil
        }
        else {
            let startDate = Date.now
            transcriber.startRecording()
            timer.map { timeFormatter.string(from: startDate, to: $0) }
                .assign(to: \.durationInfo, on: self)
                .store(in: &subscriptions)
            
        }
        recording = !recording
    }
    
}

struct MainView_Previews: PreviewProvider {
    
    static var previews: some View {
        let text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In vulputate semper lorem eget aliquam. Vivamus nulla turpis, interdum quis eleifend sed, sagittis sed felis. In ac velit pretium, facilisis erat quis, ullamcorper nulla. Vivamus non est sem. Nulla placerat, tortor vel tincidunt pretium, eros erat posuere risus, hendrerit commodo dui tortor eu ante. Nulla facilisi. Maecenas id neque ac dui rhoncus sollicitudin. Vestibulum mi leo, commodo eu posuere sed, consectetur sit amet massa. Suspendisse sit amet tempor quam. Vestibulum scelerisque massa massa, vel congue ex aliquet quis. Suspendisse fermentum erat id sem ornare pharetra. Aliquam sit amet nisl eget dui interdum tincidunt."
        let meeting = Meeting(date: Date.now, title: "Super cool meeting", text: text)
        
//        MainView(transcript: text, meetings: [meeting])
        MainView(meetings: .constant([meeting]))
    }
    
}
