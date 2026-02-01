//
//  MapAnchorAnnotationView.swift
//  RT Bus
//
//  Map-anchored action buttons (train/bus)
//

import MapKit
import UIKit
import RTBusCore

final class MapAnchorAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "MapAnchorAnnotationView"

    private let actionButton = UIButton(type: .system)
    private var tapHandler: (() -> Void)?

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
        isAccessibilityElement = false
        actionButton.isAccessibilityElement = true
        actionButton.accessibilityTraits = .button

        actionButton.addTarget(self, action: #selector(handleTap), for: .touchDown)
        actionButton.titleLabel?.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: .systemFont(ofSize: 13, weight: .semibold)
        )
        actionButton.titleLabel?.adjustsFontForContentSizeCategory = true
        addSubview(actionButton)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        tapHandler = nil
        actionButton.accessibilityIdentifier = nil
        actionButton.accessibilityLabel = nil
        actionButton.accessibilityHint = nil
    }

    func configure(zoomLevel: Double, onTap: @escaping () -> Void) {
        tapHandler = onTap
        let showText = zoomLevel < MapConstants.showStopNamesThreshold

        let locationName = NSLocalizedString("Rautatientori", comment: "")
        let label = String(
            format: NSLocalizedString("access.button.departures", comment: ""),
            locationName
        )
        if showText {
            applyTextConfiguration(
                title: locationName,
                systemImage: "bus.fill",
                color: UIColor(red: 0/255, green: 122/255, blue: 201/255, alpha: 0.75),
                accessibilityIdentifier: "DeparturesButton",
                accessibilityLabel: label,
                accessibilityHint: NSLocalizedString("ui.departures.selectHint", comment: "")
            )
        } else {
            applyIconOnlyConfiguration(
                systemImage: "bus.fill",
                color: UIColor(red: 0/255, green: 122/255, blue: 201/255, alpha: 0.75),
                accessibilityIdentifier: "DeparturesButton",
                accessibilityLabel: label,
                accessibilityHint: NSLocalizedString("ui.departures.selectHint", comment: "")
            )
        }
    }

    private func applyTextConfiguration(
        title: String,
        systemImage: String,
        color: UIColor,
        accessibilityIdentifier: String,
        accessibilityLabel: String?,
        accessibilityHint: String?
    ) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: systemImage)
        config.imagePadding = 6
        config.baseBackgroundColor = color
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
                for: .systemFont(ofSize: 11, weight: .semibold)
            )
            return outgoing
        }
        applyConfiguration(
            config: config,
            accessibilityIdentifier: accessibilityIdentifier,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint,
            enforceCircle: false
        )
    }

    private func applyIconOnlyConfiguration(
        systemImage: String,
        color: UIColor,
        accessibilityIdentifier: String,
        accessibilityLabel: String?,
        accessibilityHint: String?
    ) {
        var config = UIButton.Configuration.filled()
        config.title = nil
        config.image = UIImage(systemName: systemImage)
        config.imagePadding = 0
        config.baseBackgroundColor = color
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        applyConfiguration(
            config: config,
            accessibilityIdentifier: accessibilityIdentifier,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint,
            enforceCircle: true
        )
    }

    private func applyConfiguration(
        config: UIButton.Configuration,
        accessibilityIdentifier: String,
        accessibilityLabel: String?,
        accessibilityHint: String?,
        enforceCircle: Bool
    ) {
        actionButton.configuration = config

        actionButton.accessibilityIdentifier = accessibilityIdentifier
        actionButton.accessibilityLabel = accessibilityLabel
        actionButton.accessibilityHint = accessibilityHint

        actionButton.sizeToFit()
        if enforceCircle {
            let side = max(actionButton.bounds.width, actionButton.bounds.height)
            frame = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        } else {
            frame = CGRect(origin: .zero, size: actionButton.bounds.size)
        }
        actionButton.frame = bounds
        actionButton.layer.cornerRadius = bounds.height / 2
        actionButton.clipsToBounds = true

        displayPriority = .required
        zPriority = .max
        centerOffset = CGPoint(x: 0, y: -bounds.height / 2)
    }

    @objc private func handleTap() {
        tapHandler?()
    }
}
