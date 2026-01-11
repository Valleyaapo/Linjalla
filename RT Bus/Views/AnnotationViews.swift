//
//  AnnotationViews.swift
//  RT Bus
//
//  Created by Aapo Laakso on 28.12.2025.
//

import SwiftUI

struct StopAnnotationView: View, Equatable {
    // Equatable: Since all stops are visually identical (white circles), 
    // we can strictly deduplicate them. The ID is handled by ForEach.
    // If we wanted to check content, we'd check properties.
    // Here, the view is static.
    nonisolated static func == (lhs: StopAnnotationView, rhs: StopAnnotationView) -> Bool {
        return true
    }
    
    var body: some View {
        Circle()
            .strokeBorder(.gray, lineWidth: 1)
            .background(Circle().fill(.white))
            .frame(width: 8, height: 8)
            .transaction { $0.animation = nil }
    }
}

struct BusAnnotationView: View, Equatable {
    let lineName: String
    let heading: Int?
    var color: Color = .hslBlue
    
    nonisolated static func == (lhs: BusAnnotationView, rhs: BusAnnotationView) -> Bool {
        lhs.lineName == rhs.lineName && lhs.heading == rhs.heading && lhs.color == rhs.color
    }
    
    var body: some View {
        ZStack {
            // Main Badge
            Text(lineName)
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .frame(minWidth: 38, minHeight: 38)
                .background(color)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white, lineWidth: 2)
                )
            
            // Direction Arrow (Integrated Orbit)
            if let heading = heading {
                Image(systemName: "arrowtriangle.up.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 8, height: 8)
                    .foregroundColor(color)
                    .shadow(color: .white, radius: 1)
                    .offset(y: -26)
                    .rotationEffect(.degrees(Double(heading)))
            }
        }
    }
}

// Separate modifier to handle entry animation independently from view state
private struct EntryAnimationModifier: ViewModifier {
    @State private var isAppearing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAppearing ? 1.0 : 0.5)
            .opacity(isAppearing ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    isAppearing = true
                }
            }
            .onDisappear {
                isAppearing = false
            }
    }
}

extension View {
    func animateEntry() -> some View {
        modifier(EntryAnimationModifier())
    }
}

#Preview("Stop") {
    StopAnnotationView()
}

#Preview("Bus") {
    BusAnnotationView(lineName: "550", heading: 2)
}
