//
//  ContentView.swift
//  Amaris
//
//  Created by Tey Kai Ying on 09/10/2026.
//

import SwiftUI
import SwiftData

/// Temporary screen to confirm the database works. Replaced by the real
/// library / quotes / calendar views later.
struct ContentView: View {
    @Query private var books: [Book]
    @Query private var quotes: [Quote]

    var body: some View {
        VStack(spacing: 8) {
            Text("Amaris")
                .font(.largeTitle)
            Text("\(books.count) books · \(quotes.count) quotes")
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}

#Preview {
    ContentView()
        .modelContainer(try! AmarisStore.makeContainer(inMemory: true))
}
