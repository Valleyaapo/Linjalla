//
//  SelectionOverlay.swift
//  RT Bus
//
//  Created by Refactor on 01.01.2026.
//

import SwiftUI
import RTBusCore

struct SelectionOverlay: View {
    let busLines: [BusLine]
    let tramLines: [BusLine]
    let selectedLines: Set<BusLine>
    let isLoading: Bool
    let onToggle: (BusLine) -> Void
    let onSelectAll: () -> Void
    let onAdd: () -> Void
    let onCenter: () -> Void
    let onCenterUser: () -> Void
    let onTickets: () -> Void
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State private var hapticTrigger = 0
    
    var body: some View {
        VStack {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Spacer()
                    ticketButton
                        .padding(.trailing, 20)
                }
                
                VStack(alignment: .trailing, spacing: 12) {
                    ticketButton
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 20)
            }
            .padding(.top, 60)
            
            Spacer()
            
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Button(action: {
                        bumpHaptic()
                        onCenter()
                    }) {
                        Image(systemName: "tram.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .accessibilityIdentifier("CenterStationButton")
                    .accessibilityLabel(Text("access.button.centerStation"))
                    
                    Button(action: {
                        bumpHaptic()
                        onCenterUser()
                    }) {
                        Image(systemName: "location.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .accessibilityIdentifier("CenterUserButton")
                    .accessibilityLabel(Text("access.button.centerUser"))
                }
                .padding(.trailing, 20)
                .padding(.bottom, 10)
            }
            
            if dynamicTypeSize >= .accessibility1 {
                VStack(spacing: 20) {
                    // Select All (Full Width)
                    let totalCount = busLines.count + tramLines.count
                    if totalCount > 0 {
                        Button(action: {
                            bumpHaptic()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                onSelectAll()
                            }
                        }) {
                            HStack {
                                Image(systemName: selectedLines.count == totalCount ? "eye.circle.fill" : "eye.circle")
                                Text(selectedLines.count == totalCount ? "access.button.deselectAll" : "access.button.selectAll")
                            }
                            .font(.headline)
                            .foregroundStyle(.black).opacity(0.8)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    
                    // List of Lines (Grid)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                        ForEach(busLines) { line in
                            LineToggleView(
                                line: line,
                                isSelected: selectedLines.contains(line),
                                color: .hslBlue,
                                onToggle: { onToggle(line) }
                            )
                        }
                        ForEach(tramLines) { line in
                            LineToggleView(
                                line: line,
                                isSelected: selectedLines.contains(line),
                                color: .hslGreen,
                                onToggle: { onToggle(line) }
                            )
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: busLines + tramLines)
                    
                    // Add Button (Full Width)
                    Button(action: {
                        bumpHaptic()
                        onAdd()
                    }) {
                        HStack {

                            Image(systemName: "plus")
                            Text("ui.button.add")
                        }
                        .font(.headline)
                        .foregroundStyle(.black).opacity(0.8)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            } else {
                HStack(spacing: 0) {
                    let totalCount = busLines.count + tramLines.count
                    if totalCount > 0 {
                        Button(action: {
                            bumpHaptic()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                onSelectAll()
                            }
                        }) {
                            Image(systemName: selectedLines.count == totalCount ? "eye.circle.fill" : "eye.circle")
                                .font(.title2.bold()) // Slightly larger for clarity
                                .foregroundStyle(.black).opacity(0.7)
                                .padding(10)
                                .background(Circle().fill(.white.opacity(0.2)))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .accessibilityLabel(selectedLines.count == totalCount ? Text("access.button.deselectAll") : Text("access.button.selectAll"))
                        .padding(.leading, 20)
                    }
                    
                    ScrollView(.horizontal) {
                        LazyHGrid(rows: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ], spacing: 15) {
                            ForEach(busLines) { line in
                                LineToggleView(
                                    line: line,
                                    isSelected: selectedLines.contains(line),
                                    color: .hslBlue,
                                    onToggle: { onToggle(line) }
                                )
                            }
                            ForEach(tramLines) { line in
                                LineToggleView(
                                    line: line,
                                    isSelected: selectedLines.contains(line),
                                    color: .hslGreen,
                                    onToggle: { onToggle(line) }
                                )
                            }
                        }
                        .padding(.leading, totalCount == 0 ? 20 : 10)
                        .padding(.vertical, 16)
                        .frame(height: 120)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: busLines + tramLines)
                    }
                    .accessibilityIdentifier("LineToggleScroll")
                    .scrollIndicators(.hidden)
                    
                    Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 1, height: 24)
                    .padding(.horizontal, 10)
                    
                    Button(action: {
                        bumpHaptic()
                        onAdd()
                    }) {
                        Image(systemName: "plus")
                        .font(.headline)
                        .foregroundStyle(.black).opacity(0.7)
                        .padding(10)
                        .background(Circle().fill(.white.opacity(0.2)))
                    }
                    .accessibilityIdentifier("AddLineButton")
                    .accessibilityLabel(Text("access.button.addLine"))
                    .padding(.trailing, 20)
                }
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.bottom, 40)
                .frame(maxWidth: 600)
                .padding(.horizontal, 20)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }
    
    private var ticketButton: some View {
        Button(action: {
            bumpHaptic()
            onTickets()
        }) {
            HStack {
                Image(systemName: "ticket.fill")
                Text("ui.button.tickets")
            }
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.hslOrange.opacity(0.75))
            .clipShape(Capsule())
            .shadow(radius: 4)
        }
        .accessibilityIdentifier("TicketsButton")
    }
}

struct LineToggleView: View {
    let line: BusLine
    let isSelected: Bool
    var color: Color = .hslBlue
    let onToggle: () -> Void
    private var safeLineId: String { line.id.replacingOccurrences(of: ":", with: "_") }
    
    var body: some View {
        Button(action: {
            bumpHaptic()
            onToggle()
        }) {
            Text(line.shortName)
                .font(.body.bold().monospacedDigit())
                .fontDesign(.rounded)
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(color.gradient)
                            .shadow(color: color.opacity(0.5), radius: 8, x: 0, y: 4)
                    } else {
                        Capsule()
                            .fill(Color.primary.opacity(0.2))
                    }
                }
        }
        .accessibilityLabel("\(line.shortName)")
        .accessibilityIdentifier("LineToggle_\(safeLineId)")
        .accessibilityValue(isSelected ? Text("access.line.selected") : Text("access.line.unselected"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    @State private var hapticTrigger = 0

    private func bumpHaptic() {
        hapticTrigger += 1
    }
}

struct AddButtonView: View {
    let isFavorite: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isFavorite ? "star.fill" : "plus")
            Text(isFavorite ? NSLocalizedString("ui.button.saved", comment: "") : NSLocalizedString("ui.button.add", comment: ""))
                .font(.subheadline.bold())
        }
        .foregroundStyle(isFavorite ? .yellow : .white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isFavorite ? Color.black.opacity(0.8) : Color.hslBlue)
        .clipShape(Capsule())
    }
}

private extension SelectionOverlay {
    func bumpHaptic() {
        hapticTrigger += 1
    }
}

#Preview {
    ZStack {
        Color.gray
        SelectionOverlay(
            busLines: [
                BusLine(id: "1", shortName: "55", longName: ""),
                BusLine(id: "2", shortName: "500", longName: "")
            ],
            tramLines: [
                BusLine(id: "4", shortName: "4", longName: "")
            ],
            selectedLines: [],
            isLoading: false,
            onToggle: { _ in },
            onSelectAll: {},
            onAdd: {},
            onCenter: {},
            onCenterUser: {},
            onTickets: {}
        )
    }
}
