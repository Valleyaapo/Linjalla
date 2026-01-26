//
//  StopAnnotationView.swift
//  RT Bus
//
//  Created by Automation on 12.01.2026.
//

import MapKit
import UIKit

/// Custom annotation view for bus/tram stops
final class StopAnnotationView: MKAnnotationView {
    
    static let reuseIdentifier = "StopAnnotationView"
    
    // MARK: - UI Components
    
    private let circleView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gray.cgColor
        return view
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = .label // Adapts to light/dark mode
        label.textAlignment = .center
        label.backgroundColor = .systemBackground.withAlphaComponent(0.9)
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        return label
    }()
    
    // MARK: - Properties
    
    private var circleSize: CGFloat = 8
    
    // MARK: - Initialization
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        canShowCallout = false
        // Default frame, will be adjusted in configure
        frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        
        addSubview(circleView) // Add first (bottom)
        addSubview(nameLabel)  // Add second (top)
    }
    
    // MARK: - Configuration
    
    func configure(with annotation: StopAnnotation, zoomLevel: Double) {
        // Dynamic circle size based on zoom
        circleSize = calculateCircleSize(for: zoomLevel)
        
        // Setup frame to center the annotation
        // Unlike VehicleAnnotationView requiring offset, we want this centered 
        centerOffset = .zero
        
        // Layout circle (centered)
        let circleOrigin = (frame.width - circleSize) / 2
        circleView.frame = CGRect(x: circleOrigin, y: circleOrigin, width: circleSize, height: circleSize)
        circleView.layer.cornerRadius = circleSize / 2
        
        // Name label
        if annotation.showName {
            nameLabel.text = " \(annotation.stopName) " // Padding
            nameLabel.sizeToFit()
            
            // Re-center label below the stop
            // X: Center of frame - half label width
            // Y: Below circle
            nameLabel.frame.origin = CGPoint(
                x: (frame.width - nameLabel.frame.width) / 2,
                y: frame.height / 2 + circleSize / 2 + 4 // 4pt padding below circle
            )
            nameLabel.isHidden = false
        } else {
            nameLabel.isHidden = true
        }
        
        // Z-Priority: STOPS UNDERNEATH
        displayPriority = .defaultLow
        zPriority = .min
    }
    
    private func calculateCircleSize(for zoomLevel: Double) -> CGFloat {
        // zoomLevel is latitudeDelta
        // 0.001 = very zoomed in -> 8pt
        // 0.05 = zoomed out -> 4pt
        let minSize: CGFloat = 4
        let maxSize: CGFloat = 8
        
        // Invert: smaller delta (zoomed in) = larger size
        // We map 0.001...0.05 -> 1.0...0.0
        let normalized = 1.0 - min(max((zoomLevel - 0.001) / (0.05 - 0.001), 0), 1)
        return minSize + (maxSize - minSize) * CGFloat(normalized)
    }
}
