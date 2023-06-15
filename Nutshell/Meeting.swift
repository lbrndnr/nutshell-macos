//
//  Meeting.swift
//  Nutshell
//
//  Created by Laurin Brandner on 15.06.23.
//

import Foundation

struct Meeting: Codable {
 
    var date: Date
    var title: String
    var text: String
    
}

extension Meeting: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(date.hashValue)
        hasher.combine(title.hashValue)
        hasher.combine(text.hashValue)
    }
    
}

extension Meeting: Comparable {
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.date < rhs.date
    }
    
}
