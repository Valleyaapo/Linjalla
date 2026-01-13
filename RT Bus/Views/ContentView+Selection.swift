//
//  ContentView+Selection.swift
//  RT Bus
//
//  Selection management for ContentView
//

import SwiftUI

extension ContentView {
    
    // MARK: - Selection Management
    
    func updateSelectionFromFavorites(old: [BusLine], new: [BusLine]) {
        let oldSet = Set(old)
        let newSet = Set(new)
        
        let addedLines = newSet.subtracting(oldSet)
        let removedLines = oldSet.subtracting(newSet)
        
        var selectionChanged = false
        
        if !addedLines.isEmpty {
            selectedLines.formUnion(addedLines)
            selectionChanged = true
        }
        
        if !removedLines.isEmpty {
            selectedLines.subtract(removedLines)
            selectionChanged = true
        }
        
        if selectionChanged {
            saveSelectedLines()
            updateManagers()
        }
    }
    
    func toggleSelection(for line: BusLine) {
        if selectedLines.contains(line) {
            selectedLines.remove(line)
        } else {
            selectedLines.insert(line)
        }
        saveSelectedLines()
        updateManagers()
    }
    
    func saveSelectedLines() {
        if let encoded = try? JSONEncoder().encode(Array(selectedLines)) {
            UserDefaults.standard.set(encoded, forKey: "SelectedLinesState")
        }
    }
    
    func loadSelectedLines() {
        if let data = UserDefaults.standard.data(forKey: "SelectedLinesState"),
           let decoded = try? JSONDecoder().decode([BusLine].self, from: data) {
            selectedLines = Set(decoded)
            updateManagers()
        }
    }
    
    func updateManagers() {
        let selectedArray = Array(selectedLines)

        // Filter lines by type - each manager only gets its relevant lines
        let busLineIds = Set(busManager.favoriteLines.map { $0.id })
        let tramLineIds = Set(tramManager.favoriteLines.map { $0.id })

        let selectedBusLines = selectedArray.filter { busLineIds.contains($0.id) }
        let selectedTramLines = selectedArray.filter { tramLineIds.contains($0.id) }

        busManager.updateSubscriptions(selectedLines: selectedBusLines)
        tramManager.updateSubscriptions(selectedLines: selectedTramLines)
        stopManager.updateStops(for: selectedArray)
    }
    
    func selectAllFavorites() {
        let allFavorites = busManager.favoriteLines + tramManager.favoriteLines
        
        if selectedLines.count == allFavorites.count && !allFavorites.isEmpty {
            selectedLines.removeAll()
        } else {
            selectedLines = Set(allFavorites)
        }
        saveSelectedLines()
        updateManagers()
    }
}
