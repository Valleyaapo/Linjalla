//
//  LineSearchSheet.swift
//  RT Bus
//
//  Created by Refactor on 01.01.2026.
//

import SwiftUI
import OSLog

struct LineSearchSheet: View {
    let busManager: BusManager
    let tramManager: TramManager
    
    private enum SearchMode: String, CaseIterable {
        case bus = "Buses"
        case tram = "Trams"
        
        var localizedName: LocalizedStringKey {
            switch self {
            case .bus: return "ui.search.mode.bus"
            case .tram: return "ui.search.mode.tram"
            }
        }
    }
    
    @State private var searchMode: SearchMode = .bus
    @State private var searchText = ""
    @State private var searchResults: [BusLine] = []
    @State private var isFetching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearchPresented = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isSearchPresented && isIOS18OrLater {
                Spacer()
                    .frame(height: 20)
            }
            
            NavigationStack {
                VStack(spacing: 0) {
                    Picker("Mode", selection: $searchMode) {
                        ForEach(SearchMode.allCases, id: \.self) { mode in
                            Text(mode.localizedName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    List {
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.secondary)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        if isFetching {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        
                        let linesToShow = getLinesToShow()
                        let emptyMessage = searchText.isEmpty 
                            ? NSLocalizedString("ui.favorites.empty", comment: "") 
                            : NSLocalizedString("ui.search.empty", comment: "")
                        
                        if linesToShow.isEmpty && !isFetching {
                            ContentUnavailableView(
                                searchText.isEmpty ? NSLocalizedString("ui.favorites.noFavorites", comment: "") : NSLocalizedString("ui.search.noResults", comment: ""),
                                systemImage: searchText.isEmpty ? "star.slash" : "magnifyingglass",
                                description: Text(emptyMessage)
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .frame(maxWidth: .infinity, minHeight: 200)
                        }
                        
                        ForEach(linesToShow) { line in
                            LineSearchRow(
                                line: line,
                                isFavorite: checkFavorite(line),
                                onToggle: { toggleFavorite(line) },
                                color: searchMode == .tram ? .hslGreen : .hslBlue
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 4)
                            .transition(.slide)
                            .animation(.default, value: linesToShow)
                        }
                    }
                    .listStyle(.plain)
                }
                .navigationTitle(searchText.isEmpty ? Text("ui.title.yourLines") : Text("ui.title.search"))
                .searchable(text: $searchText, isPresented: $isSearchPresented, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("ui.placeholder.search"))
                .keyboardType(.numberPad)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
                .onChange(of: searchText) { _, newValue in
                    performDebouncedSearch(query: newValue)
                }
                .onChange(of: searchMode) { _, _ in
                    // Refresh list when mode changes
                    searchResults = []
                    if !searchText.isEmpty {
                        performDebouncedSearch(query: searchText)
                    }
                }
            }
        }
    }
    
    private var isIOS18OrLater: Bool {
        if #available(iOS 18, *) {
            return true
        }
        return false
    }
    
    private func getLinesToShow() -> [BusLine] {
        if searchText.isEmpty {
            switch searchMode {
            case .bus: return busManager.favoriteLines
            case .tram: return tramManager.favoriteLines
            }
        } else {
            return searchResults
        }
    }
    
    private func checkFavorite(_ line: BusLine) -> Bool {
        switch searchMode {
        case .bus: return busManager.favoriteLines.contains { $0.id == line.id }
        case .tram: return tramManager.favoriteLines.contains { $0.id == line.id }
        }
    }
    
    private func toggleFavorite(_ line: BusLine) {
        switch searchMode {
        case .bus: busManager.toggleFavorite(line)
        case .tram: tramManager.toggleFavorite(line)
        }
    }
    
    private func performDebouncedSearch(query: String) {
        // Cancel previous search task
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            searchResults = []
            isFetching = false
            errorMessage = nil
            return
        }
        
        isFetching = true
        errorMessage = nil
        searchTask = Task {
            // Debounce: wait 300ms before searching
            try? await Task.sleep(for: .milliseconds(300))
            
            guard !Task.isCancelled else { return }
            
            do {
                let lines: [BusLine]
                switch searchMode {
                case .bus:
                    lines = try await busManager.searchLines(query: query)
                case .tram:
                    lines = try await tramManager.searchLines(query: query)
                }
                
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.searchResults = lines
                    self.isFetching = false
                    self.errorMessage = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                Logger.network.error("Search error: \(error)")
                await MainActor.run {
                    self.isFetching = false
                    self.errorMessage = errorMessageKey(for: error)
                }
            }
        }
    }

    private func errorMessageKey(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                return NSLocalizedString("ui.error.offline", comment: "")
            default:
                break
            }
        }
        return NSLocalizedString("ui.error.searchFailed", comment: "")
    }
}

struct LineSearchRow: View {
    let line: BusLine
    let isFavorite: Bool
    let onToggle: () -> Void
    var color: Color = .hslBlue
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(line.shortName)
                        .font(.title3.bold())
                        .fontDesign(.rounded)
                        .foregroundColor(color)
                    
                    Spacer()
                }
                Text(line.longName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            AddButtonView(isFavorite: isFavorite) // Assume AddButtonView handles its own color or is neutral
                .onTapGesture {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation {
                        onToggle()
                    }
                }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

#Preview {
    LineSearchSheet(busManager: BusManager(), tramManager: TramManager())
}

#Preview("Row") {
    LineSearchRow(
        line: BusLine(id: "HSL:123", shortName: "550", longName: "Westendinasema - Itäkeskus"),
        isFavorite: true,
        onToggle: {}
    )
    .padding()
}
