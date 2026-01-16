//
//  VehicleAnnotationView.swift
//  RT Bus
//
//  Custom annotation view for buses and trams with centralized animation
//

import MapKit
import UIKit

/// Custom annotation view for buses and trams
final class VehicleAnnotationView: MKAnnotationView {
    
    static let reuseIdentifier = "VehicleAnnotationView"
    
    // MARK: - UI Components
    
    private let containerView: UIView = {
        let view = UIView()
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.white.cgColor
        return view
    }()
    
    // Container for the arrow to handle rotation/orbiting
    private let arrowContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private let lineLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private let arrowView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "arrowtriangle.up.fill")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    // MARK: - Animation State
    
    /// Current entry/scale animator (can be interrupted)
    private var entryAnimator: UIViewPropertyAnimator?
    
    /// Current heading animator (can be interrupted with velocity)
    private var headingAnimator: UIViewPropertyAnimator?
    
    /// Current heading in radians for velocity calculation
    private var currentHeadingRadians: CGFloat = 0
    
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
        frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        centerOffset = .zero
        
        addSubview(arrowContainer)
        arrowContainer.addSubview(arrowView)
        addSubview(containerView)
        containerView.addSubview(lineLabel)
    }
    
    // MARK: - Reuse
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Stop any ongoing property animators
        entryAnimator?.stopAnimation(true)
        entryAnimator = nil
        headingAnimator?.stopAnimation(true)
        headingAnimator = nil
        
        // Cancel Core Animation
        layer.removeAllAnimations()
        containerView.layer.removeAllAnimations()
        arrowContainer.layer.removeAllAnimations()
        
        // Reset the VIEW's own transform and alpha (exit animation targets self)
        transform = .identity
        alpha = 1
        
        // Reset subview state
        arrowContainer.transform = .identity
        arrowContainer.isHidden = true
        containerView.backgroundColor = .clear
        containerView.transform = .identity
        containerView.alpha = 1
        lineLabel.text = nil
        currentHeadingRadians = 0
    }
    
    // MARK: - Configuration (Layout Only)
    
    /// Configure the view for an annotation WITHOUT animations
    /// Animations are triggered separately via animate* methods
    func configure(with annotation: VehicleAnnotation) {
        // Reset arrow transform before layout
        arrowContainer.transform = .identity
        
        // Badge text
        lineLabel.text = annotation.lineName
        
        // Badge color
        let color = annotation.vehicleType.color
        containerView.backgroundColor = color
        arrowView.tintColor = color
        
        // Size badge to fit text, circular shape
        let textSize = lineLabel.intrinsicContentSize
        let diameter = max(38, textSize.width + 14)
        let totalSize: CGFloat = diameter + 32
        
        if frame.width != totalSize {
            frame = CGRect(x: 0, y: 0, width: totalSize, height: totalSize)
        }
        
        // Layout container (circle)
        containerView.frame = CGRect(
            x: (totalSize - diameter) / 2,
            y: (totalSize - diameter) / 2,
            width: diameter,
            height: diameter
        )
        containerView.layer.cornerRadius = diameter / 2
        
        // Layout label
        lineLabel.frame = containerView.bounds
        
        // Layout orbit container
        let orbitSize = diameter + 14
        arrowContainer.frame = CGRect(
            x: (totalSize - orbitSize) / 2,
            y: (totalSize - orbitSize) / 2,
            width: orbitSize,
            height: orbitSize
        )
        
        // Position arrow at top of orbit
        let arrowSize: CGFloat = 12
        arrowView.frame = CGRect(
            x: (orbitSize - arrowSize) / 2,
            y: 0,
            width: arrowSize,
            height: arrowSize
        )
        
        // Z-Priority: VEHICLES ON TOP
        displayPriority = .required
        zPriority = .max
    }
    
    // MARK: - Entry Animation
    
    /// Animate entry: spring scale 0.3 → 1.0
    func animateEntry(heading: Double, completion: (() -> Void)? = nil) {
        let headingRadians = CGFloat(heading) * .pi / 180
        let rotation = CGAffineTransform(rotationAngle: headingRadians)
        let scale = CGAffineTransform(scaleX: 0.3, y: 0.3)
        
        // Set initial small state without animation
        UIView.performWithoutAnimation {
            self.containerView.alpha = 1
            self.arrowContainer.alpha = 1
            self.containerView.transform = scale
            self.arrowContainer.transform = scale.concatenating(rotation)
            self.arrowContainer.isHidden = heading < 0
        }
        
        currentHeadingRadians = headingRadians
        
        // Spring animation to full size
        entryAnimator = UIViewPropertyAnimator(duration: 0.25, dampingRatio: 0.8) {
            self.containerView.transform = .identity
            self.arrowContainer.transform = rotation
        }
        
        entryAnimator?.addCompletion { _ in
            completion?()
        }
        
        entryAnimator?.startAnimation()
    }
    
    // MARK: - Update Animation
    
    /// Animate heading update with smooth linear animation
    func animateUpdate(toHeading heading: Double, headingVelocity: CGFloat = 0, completion: (() -> Void)? = nil) {
        guard heading >= 0 else {
            arrowContainer.isHidden = true
            completion?()
            return
        }
        
        arrowContainer.isHidden = false
        
        let targetRadians = CGFloat(heading) * .pi / 180
        let rotation = CGAffineTransform(rotationAngle: targetRadians)
        
        // Stop current heading animation
        headingAnimator?.stopAnimation(true)
        
        // Use linear animation for smooth, predictable rotation
        headingAnimator = UIViewPropertyAnimator(duration: 0.3, curve: .linear) {
            self.arrowContainer.transform = rotation
        }
        
        headingAnimator?.addCompletion { _ in
            self.currentHeadingRadians = targetRadians
            completion?()
        }
        
        headingAnimator?.startAnimation()
    }
    
    // MARK: - Exit Animation
    
    /// Animate exit: ease-in scale down + fade
    func animateExit(completion: @escaping () -> Void) {
        // Stop any entry animation
        entryAnimator?.stopAnimation(true)
        entryAnimator = nil
        
        UIView.animate(
            withDuration: 0.15,
            delay: 0,
            options: .curveEaseIn
        ) {
            self.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            self.alpha = 0
        } completion: { _ in
            completion()
        }
    }
    
    // MARK: - Immediate Heading Set (No Animation)
    
    /// Set heading immediately without animation
    func setHeading(_ heading: Double) {
        if heading >= 0 {
            arrowContainer.isHidden = false
            let radians = CGFloat(heading) * .pi / 180
            UIView.performWithoutAnimation {
                self.arrowContainer.transform = CGAffineTransform(rotationAngle: radians)
            }
            currentHeadingRadians = radians
        } else {
            arrowContainer.isHidden = true
        }
    }
}
