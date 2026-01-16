//
//  ContentView+Selection.swift
//  RT Bus
//
//  Selection wrappers for ContentView
//

import SwiftUI

extension ContentView {

    // MARK: - Selection Management

    func toggleSelection(for line: BusLine) {
        selectionStore.toggleSelection(for: line)
    }

    func loadSelectedLines() {
        selectionStore.loadSelectedLines()
    }

    func selectAllFavorites() {
        selectionStore.selectAllFavorites()
    }
}
