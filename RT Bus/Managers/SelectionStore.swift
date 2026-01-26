//
//  SelectionStore.swift
//  RT Bus
//
//  Created by Assistant on 16.01.2026.
//

import Foundation
import Observation
import RTBusCore

@MainActor
@Observable
final class SelectionStore {
    private let userDefaults: UserDefaults
    private let selectedLinesKey = "SelectedLinesState"
    private let busManager: BusManager
    private let tramManager: TramManager
    let stopManager: StopManager

    var selectedLines: Set<BusLine> = []
    private var updateTask: Task<Void, Never>?
    private let debounceInterval: UInt64 = 300_000_000 // 300ms

    init(
        busManager: BusManager,
        tramManager: TramManager,
        stopManager: StopManager? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.busManager = busManager
        self.tramManager = tramManager
        self.stopManager = stopManager ?? StopManager()
        self.userDefaults = userDefaults
    }

    func syncFavorites(old: [BusLine], new: [BusLine]) {
        let wasEmpty = selectedLines.isEmpty
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
            let shouldUpdateImmediately = wasEmpty && !selectedLines.isEmpty
            scheduleUpdateManagers(immediate: shouldUpdateImmediately)
        }
    }

    func toggleSelection(for line: BusLine) {
        let wasEmpty = selectedLines.isEmpty
        if selectedLines.contains(line) {
            selectedLines.remove(line)
        } else {
            selectedLines.insert(line)
        }
        saveSelectedLines()
        let shouldUpdateImmediately = wasEmpty && !selectedLines.isEmpty
        scheduleUpdateManagers(immediate: shouldUpdateImmediately)
    }

    func selectAllFavorites() {
        let wasEmpty = selectedLines.isEmpty
        let allFavorites = busManager.favoriteLines + tramManager.favoriteLines

        if selectedLines.count == allFavorites.count && !allFavorites.isEmpty {
            selectedLines.removeAll()
        } else {
            selectedLines = Set(allFavorites)
        }
        saveSelectedLines()
        let shouldUpdateImmediately = wasEmpty && !selectedLines.isEmpty
        scheduleUpdateManagers(immediate: shouldUpdateImmediately)
    }

    func loadSelectedLines() {
        if let data = userDefaults.data(forKey: selectedLinesKey),
           let decoded = try? JSONDecoder().decode([BusLine].self, from: data) {
            selectedLines = Set(decoded)
            scheduleUpdateManagers(immediate: true)
            return
        }

        let defaults = busManager.favoriteLines + tramManager.favoriteLines
        guard !defaults.isEmpty else { return }
        selectedLines = Set(defaults)
        saveSelectedLines()
        scheduleUpdateManagers(immediate: true)
    }

    private func saveSelectedLines() {
        if let encoded = try? JSONEncoder().encode(Array(selectedLines)) {
            userDefaults.set(encoded, forKey: selectedLinesKey)
        }
    }

    private func scheduleUpdateManagers(immediate: Bool = false) {
        updateTask?.cancel()

        if immediate {
            updateManagers()
            return
        }

        updateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: debounceInterval)
            guard !Task.isCancelled else { return }
            updateManagers()
        }
    }

    func cancelPendingUpdate() {
        updateTask?.cancel()
        updateTask = nil
    }

    private func updateManagers() {
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
}
