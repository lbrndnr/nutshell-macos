//
//  NutshellApp.swift
//  Nutshell
//
//  Created by Laurin Brandner on 25.05.23.
//

import SwiftUI

@main
struct NutshellApp: App {
    
    @State private var meetings = loadMeetings()
    
    var body: some Scene {
        let terminatePublisher = NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        
        WindowGroup {
            MainView(meetings: $meetings)
                .onReceive(terminatePublisher, perform: { output in
                save(meetings)
            })
        }
    }
    
}

private func loadMeetings() -> [Meeting] {
    let fileManager = FileManager.default
    let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!.path()
    do {
        let items = try fileManager.contentsOfDirectory(atPath: dir)
        let decoder = JSONDecoder()
        return try items.map { fileName in
            let url = URL(filePath: dir.appending(fileName))
            let data = try Data(contentsOf: url)
            return try! decoder.decode(Meeting.self, from: data)
        }
    }
    catch {
        print(error)
        return []
    }
}

private func save(_ meetings: [Meeting]) {
    let fileManager = FileManager.default
    let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let encoder = JSONEncoder()
    do {
        for meeting in meetings {
            let fileName = String(meeting.date.timeIntervalSince1970)
            let url = dir.appending(path: "\(fileName).json")
            let data = try encoder.encode(meeting)
            try data.write(to: url)
        }
    }
    catch {
        print(error)
    }
}
