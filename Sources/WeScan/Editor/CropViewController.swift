//
//  File.swift
//  
//
//  Created by Dan on 7/27/24.
//

import AVFoundation
import UIKit

/// The `CropScanViewController` offers an interface for the user to edit the detected quadrilateral.
final class CropScanViewController: UIViewController {
    weak var delegate: CropScanViewControllerDelegate?
    private var rotationAngle = Measurement<UnitAngle>(value: 0.0, unit: .degrees)
    
    private lazy var linearGauge: LinearGauge = {
        let uiControl = LinearGauge()
        uiControl.addTarget(self, action: #selector(gaugeValueChanged(_:)), for: .valueChanged)
        return uiControl
    }()
    
    private lazy var imageContainer: UIView = {
        let container = UIView()
        container.contentMode = .scaleAspectFill
        container.layer.borderColor = UIColor.red.cgColor
        container.layer.borderWidth = 2.0
        container.translatesAutoresizingMaskIntoConstraints = false
        
        container.layer.cornerRadius = 50
        container.clipsToBounds = true
        return container
    }()
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.isOpaque = true
        imageView.image = image
        imageView.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var quadView: QuadrilateralView = {
        let quadView = QuadrilateralView()
        quadView.editable = true
        quadView.translatesAutoresizingMaskIntoConstraints = false
        return quadView
    }()

    private lazy var doneButton: UIBarButtonItem = {
        let title = NSLocalizedString("wescan.crop.button.done",
                                      tableName: nil,
                                      bundle: Bundle(for: CropScanViewController.self),
                                      value: "Done",
                                      comment: "A generic done button"
        )
        let button = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(cropImage))
        button.tintColor = navigationController?.navigationBar.tintColor
        return button
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        let title = NSLocalizedString("wescan.scanning.cancel",
                                      tableName: nil,
                                      bundle: Bundle(for: EditScanViewController.self),
                                      value: "Cancel",
                                      comment: "A generic cancel button"
        )
        let button = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(cancelButtonTapped))
        button.tintColor = navigationController?.navigationBar.tintColor
        return button
    }()

    /// The image the quadrilateral was detected on.
    private let image: UIImage

    /// The detected quadrilateral that can be edited by the user. Uses the image's coordinates.
    private var quad: Quadrilateral

    private var zoomGestureController: ZoomGestureController!

    private var quadViewWidthConstraint = NSLayoutConstraint()
    private var quadViewHeightConstraint = NSLayoutConstraint()
    
    private let ocv = Ocv()

    // MARK: - Life Cycle

    init(image: UIImage, quad: Quadrilateral?, rotateImage: Bool = false) {
        self.image = rotateImage ? image.applyingPortraitOrientation() : image
        self.quad = quad ?? CropScanViewController.defaultQuad(forImage: image)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        title = NSLocalizedString("wescan.crop.title",
                                  tableName: nil,
                                  bundle: Bundle(for: EditScanViewController.self),
                                  value: "Crop Image",
                                  comment: "The title of the CropScanViewController"
        )
        navigationItem.rightBarButtonItem = doneButton
        if let firstVC = self.navigationController?.viewControllers.first, firstVC == self {
            navigationItem.leftBarButtonItem = cancelButton
        } else {
            navigationItem.leftBarButtonItem = nil
        }
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        
        zoomGestureController = ZoomGestureController(image: image, quadView: quadView)

        let touchDown = UILongPressGestureRecognizer(target: zoomGestureController, action: #selector(zoomGestureController.handle(pan:)))
        touchDown.minimumPressDuration = 0
        imageContainer.addGestureRecognizer(touchDown)
    }

    override public func viewDidLayoutSubviews() {
        NSLog("viewDidLayoutSubviews")
        super.viewDidLayoutSubviews()
        imageContainer.layoutIfNeeded() // Force the layout to update for the quadrilateral to calculate width and height properly
        
        adjustQuadViewConstraints()
        displayQuad()
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Work around for an iOS 11.2 bug where UIBarButtonItems don't get back to their normal state after being pressed.
        navigationController?.navigationBar.tintAdjustmentMode = .normal
        navigationController?.navigationBar.tintAdjustmentMode = .automatic
    }

    // MARK: - Setups

    private func setupViews() {
        NSLog("setupViews")
        setupImageContainer()
        setupLinearGauge()
    }
    
    private func setupImageContainer() {
        view.addSubview(imageContainer)
        // Constrain the UIView to the safe area
        NSLayoutConstraint.activate([
            imageContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            imageContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            imageContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100)
        ])
        
        imageContainer.addSubview(imageView)
        imageContainer.addSubview(quadView)
        
        // Constrain the UIImageView to fill the container UIView
        quadViewWidthConstraint = quadView.widthAnchor.constraint(equalToConstant: 0)
        quadViewHeightConstraint = quadView.heightAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            
            quadView.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            quadView.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            quadViewWidthConstraint,
            quadViewHeightConstraint
        ])
    }
    
    private func setupLinearGauge() {
        // Setup linear guage
        linearGauge.minValue = -180
        linearGauge.maxValue = 180
        linearGauge.majorTickInterval = 30
        linearGauge.minorTickInterval = 10
        linearGauge.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(linearGauge)
        
        NSLayoutConstraint.activate([
            linearGauge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            linearGauge.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60),
            linearGauge.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            linearGauge.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            linearGauge.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    // MARK: - Actions
    @objc func cancelButtonTapped() {
        navigationController?.dismiss(animated: true)
    }

    @objc func cropImage() {
        guard let quad = quadView.quad,
            let ciImage = CIImage(image: image) else {
                if let imageScannerController = navigationController as? ImageScannerController {
                    let error = ImageScannerControllerError.ciImageCreation
                    imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFailWithError: error)
                }
                return
        }
        let cgOrientation = CGImagePropertyOrientation(image.imageOrientation)
        let orientedImage = ciImage.oriented(forExifOrientation: Int32(cgOrientation.rawValue))
        let scaledQuad = quad.scale(quadView.bounds.size, image.size)
        self.quad = scaledQuad

        // Cropped Image
        var cartesianScaledQuad = scaledQuad.toCartesian(withHeight: image.size.height)
        cartesianScaledQuad.reorganize()

        let filteredImage = orientedImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: cartesianScaledQuad.bottomLeft),
            "inputTopRight": CIVector(cgPoint: cartesianScaledQuad.bottomRight),
            "inputBottomLeft": CIVector(cgPoint: cartesianScaledQuad.topLeft),
            "inputBottomRight": CIVector(cgPoint: cartesianScaledQuad.topRight)
        ])

        let croppedImage = UIImage.from(ciImage: filteredImage)
        let croppedImageQuad = Quadrilateral(
            topLeft: CGPoint(x: 0, y: 0),
            topRight: CGPoint(x: croppedImage.size.width, y: 0),
            bottomRight: CGPoint(x: croppedImage.size.width, y: croppedImage.size.height),
            bottomLeft: CGPoint(x: 0, y: croppedImage.size.height))
        var enhancedScan = ImageScannerScan(image: croppedImage)
        enhancedScan.rotate(by: self.rotationAngle)
        let results = ImageScannerResults(
            detectedRectangle: croppedImageQuad,
            originalScan: ImageScannerScan(image: image),
            croppedScan: ImageScannerScan(image: croppedImage),
            enhancedScan: enhancedScan
        )

        
        guard let delegate = self.delegate else { return }
        delegate.onImageCropped(results)
        navigationController?.popViewController(animated: true)
    }
    
    @objc func gaugeValueChanged(_ sender: LinearGauge) {
        let angle = sender.currentValue * .pi / 180
        self.rotationAngle.value = angle * 100
        imageView.transform = CGAffineTransform(rotationAngle: angle)
    }

    private func displayQuad() {
        NSLog("displayQuad")
        let imageSize = image.size
        let imageFrame = CGRect(
            origin: quadView.frame.origin,
            size: CGSize(width: quadViewWidthConstraint.constant, height: quadViewHeightConstraint.constant)
        )
        let scaleTransform = CGAffineTransform.scaleTransform(forSize: imageSize, aspectFillInSize: imageFrame.size)
        let transforms = [scaleTransform]
        let transformedQuad = quad.applyTransforms(transforms)

        quadView.drawQuadrilateral(quad: transformedQuad, animated: false)
    }

    /// The quadView should be lined up on top of the actual image displayed by the imageView.
    /// Since there is no way to know the size of that image before run time, we adjust the constraints
    /// to make sure that the quadView is on top of the displayed image.
    private func adjustQuadViewConstraints() {
        NSLog("adjustQuadViewConstraints")
        let frame = AVMakeRect(aspectRatio: image.size, insideRect: imageView.bounds)
        quadViewWidthConstraint.constant = frame.size.width
        quadViewHeightConstraint.constant = frame.size.height
    }

    /// Generates a `Quadrilateral` object that's centered and 90% of the size of the passed in image.
    private static func defaultQuad(forImage image: UIImage) -> Quadrilateral {
        let topLeft = CGPoint(x: image.size.width * 0.05, y: image.size.height * 0.05)
        let topRight = CGPoint(x: image.size.width * 0.95, y: image.size.height * 0.05)
        let bottomRight = CGPoint(x: image.size.width * 0.95, y: image.size.height * 0.95)
        let bottomLeft = CGPoint(x: image.size.width * 0.05, y: image.size.height * 0.95)

        let quad = Quadrilateral(topLeft: topLeft, topRight: topRight, bottomRight: bottomRight, bottomLeft: bottomLeft)

        return quad
    }

}

protocol CropScanViewControllerDelegate: class {
    func onImageCropped(_ results: ImageScannerResults)
}
