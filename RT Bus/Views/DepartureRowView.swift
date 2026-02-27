//
//  DepartureRowView.swift
//  RT Bus
//
//  Created by Codex on 22.01.2026.
//

import SwiftUI
import RTBusCore

struct DepartureRowView: View {
    let departure: Departure
    
    var body: some View {
        HStack(spacing: 12) {
            Text(departure.lineName)
                .font(.title3.bold())
                .fontDesign(.rounded)
                .frame(minWidth: 50, alignment: .leading)
                .foregroundStyle(Color.hslBlue)
            
            VStack(alignment: .leading) {
                Text(departure.headsign)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let platform = departure.platform {
                        Text(String(format: NSLocalizedString("ui.label.platform", comment: ""), platform))
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(.rect(cornerRadius: 4))
                    }
                    
                    Text(DepartureFormatting.formatTime(departure.departureDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text(DepartureFormatting.timeUntil(departure.departureDate))
                .font(.callout.monospacedDigit())
                .bold()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .clipShape(.rect(cornerRadius: 8))
                .foregroundStyle(.green)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(departure.lineName) \(NSLocalizedString("to", comment: "")) \(departure.headsign). \(DepartureFormatting.timeUntilAccessible(departure.departureDate))"
        )
        .accessibilityIdentifier("DepartureRow_\(departure.lineName)")
    }
}

enum DepartureFormatting {
    // Static formatter to avoid recreation per cell
    fileprivate static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    static func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
    
    static func timeUntil(_ date: Date) -> String {
        let diff = Int(date.timeIntervalSinceNow / 60)
        if diff <= 0 {
            return NSLocalizedString("ui.time.now", comment: "")
        }
        return String(format: NSLocalizedString("ui.time.min", comment: ""), diff)
    }

    static func timeUntilAccessible(_ date: Date) -> String {
        let diff = Int(date.timeIntervalSinceNow / 60)
        if diff <= 0 {
            return NSLocalizedString("ui.time.now", comment: "")
        }
        if diff == 1 {
            return NSLocalizedString("ui.time.minute.accessible.one", comment: "")
        }
        return String(format: NSLocalizedString("ui.time.minute.accessible.other", comment: ""), diff)
    }
}
