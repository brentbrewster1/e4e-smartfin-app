//
//  Item.swift
//  smartfin
//
//  Created by Brent Brewster on 1/22/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
