//
//  TrainStationAnnotationView.swift
//  RT Bus
//
//  Icon-only train station annotation view
//

import MapKit
import UIKit
import RTBusCore

final class TrainStationAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "TrainStationAnnotationView"

    private let actionButton = UIButton(type: .system)
    private var tapHandler: (() -> Void)?
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        canShowCallout = false
        isUserInteractionEnabled = true
        backgroundColor = .clear

        actionButton.addTarget(self, action: #selector(handleTap), for: .touchDown)
        addSubview(actionButton)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        tapHandler = nil
        actionButton.accessibilityIdentifier = nil
        actionButton.accessibilityLabel = nil
    }

    func configure(with station: TrainStation, zoomLevel: Double, onTap: @escaping () -> Void) {
        tapHandler = onTap
        let showDotOnly = zoomLevel >= MapConstants.showStopsThreshold

        if showDotOnly {
            applyDotStyle()
            actionButton.isUserInteractionEnabled = false
            isUserInteractionEnabled = false
        } else {
            applyIconStyle()
            actionButton.isUserInteractionEnabled = true
            isUserInteractionEnabled = true
        }

        let safeId = station.id.replacingOccurrences(of: ":", with: "_")
        actionButton.accessibilityIdentifier = "TrainStation_\(safeId)"
        actionButton.accessibilityLabel = station.name

        layoutButtonForCurrentStyle()

        displayPriority = .required
        zPriority = .max
        centerOffset = CGPoint(x: 0, y: -bounds.height / 2)
    }

    @objc private func handleTap() {
        haptic.prepare()
        haptic.impactOccurred()
        tapHandler?()
    }

    private func applyIconStyle() {
        var config = UIButton.Configuration.filled()
        config.title = nil
        config.image = UIImage(systemName: "tram.fill")
        config.imagePadding = 0
        config.baseBackgroundColor = UIColor(red: 140/255, green: 71/255, blue: 153/255, alpha: 0.8)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        actionButton.configuration = config
    }

    private func applyDotStyle() {
        var config = UIButton.Configuration.filled()
        config.title = nil
        config.image = nil
        config.baseBackgroundColor = UIColor(red: 140/255, green: 71/255, blue: 153/255, alpha: 0.9)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        actionButton.configuration = config
    }

    private func layoutButtonForCurrentStyle() {
        let hasIcon = actionButton.configuration?.image != nil
        if hasIcon {
            actionButton.sizeToFit()
            let side = max(actionButton.bounds.width, actionButton.bounds.height)
            frame = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        } else {
            let dotSize: CGFloat = 12
            frame = CGRect(origin: .zero, size: CGSize(width: dotSize, height: dotSize))
            actionButton.bounds = CGRect(origin: .zero, size: CGSize(width: dotSize, height: dotSize))
        }
        actionButton.frame = bounds
        actionButton.layer.cornerRadius = bounds.height / 2
        actionButton.clipsToBounds = true
    }
}
