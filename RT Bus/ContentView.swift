//
//  ContentView.swift
//  RT Bus
//
//  Updated on 13.01.2026.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @Bindable var busManager: BusManager

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 60.1699, longitude: 24.9384),
        span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
    )
    @State private var selectedLines: Set<BusLine> = []
    @State private var isLinePickerPresented = false

    private var sortedSelection: [BusLine] {
        selectedLines.sorted { $0.shortName < $1.shortName }
    }

    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: busManager.vehicleList) { vehicle in
                MapAnnotation(coordinate: vehicle.coordinate) {
                    BusMarker(lineName: vehicle.lineName)
                        .animation(.easeInOut(duration: 0.35), value: vehicle.latitude)
                        .animation(.easeInOut(duration: 0.35), value: vehicle.longitude)
                }
            }
            .ignoresSafeArea()

            VStack {
                header
                Spacer()
                if !sortedSelection.isEmpty {
                    lineChips
                }
            }
            .padding()
        }
        .sheet(isPresented: $isLinePickerPresented) {
            LineSelectionView(lines: busManager.favoriteLines, selectedLines: $selectedLines)
        }
        .onAppear {
            guard selectedLines.isEmpty else { return }
            selectedLines = Set(busManager.favoriteLines)
        }
        .onChange(of: selectedLines) { newSelection in
            busManager.updateSubscriptions(selectedLines: Array(newSelection))
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("HSL Bus Tracker")
                    .font(.headline)
                Text("\(busManager.busDictionary.count) vehicles on the map")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                isLinePickerPresented = true
            } label: {
                Label("Lines", systemImage: "bus")
                    .font(.callout)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(radius: 6)
    }

    private var lineChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sortedSelection) { line in
                    Text(line.shortName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 12)
                        .background(Color.blue)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        )
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private struct BusMarker: View {
        let lineName: String

        var body: some View {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 34, height: 34)
                    .shadow(radius: 4)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                Text(lineName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }

    private struct LineSelectionView: View {
        let lines: [BusLine]
        @Binding var selectedLines: Set<BusLine>
        @Environment(\.dismiss) private var dismiss
        @State private var searchText = ""

        private var filteredLines: [BusLine] {
            guard !searchText.isEmpty else { return lines }
            return lines.filter { line in
                line.shortName.localizedCaseInsensitiveContains(searchText) ||
                line.longName.localizedCaseInsensitiveContains(searchText)
            }
        }

        var body: some View {
            NavigationStack {
                List(filteredLines) { line in
                    Button {
                        toggle(line)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.shortName)
                                    .font(.headline)
                                Text(line.longName)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedLines.contains(line) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Filter lines")
                .navigationTitle("Select lines")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }

        private func toggle(_ line: BusLine) {
            if selectedLines.contains(line) {
                selectedLines.remove(line)
            } else {
                selectedLines.insert(line)
            }
        }
    }
}

#Preview {
    ContentView(busManager: BusManager())
}
