//
//  ContentView.swift
//  smartfin
//
//  Created by Brent Brewster on 1/22/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {


    var body: some View {
        DashboardView()
    }


}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
