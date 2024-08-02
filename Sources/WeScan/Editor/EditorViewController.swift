//
//  File.swift
//  
//
//  Created by Dan on 7/27/24.
//

import UIKit

/// The `EditorViewController` offers an interface to review the image after it
/// has been cropped and deskewed according to the passed in quadrilateral.
final class EditorViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    static var pages: [ImageScannerResults] = []
    static var selectedIndex: Int = 0
    
    private var rotationAngle = Measurement<UnitAngle>(value: 0, unit: .degrees)
    private var showEnhancedImage = false
    private var results: ImageScannerResults = ImageScannerResults(
        detectedRectangle: Quadrilateral(topLeft: CGPoint(), topRight: CGPoint(), bottomRight: CGPoint(), bottomLeft: CGPoint()),
        originalScan: ImageScannerScan(image: UIImage()),
        croppedScan: ImageScannerScan(image: UIImage()),
        enhancedScan: nil
    )
    private var zoomGestureController: ZoomGestureController!
    private var quadViewWidthConstraint = NSLayoutConstraint()
    private var quadViewHeightConstraint = NSLayoutConstraint()
    private var toolbarContainerBottomConstraint: NSLayoutConstraint!
    
    lazy var toolbarContainer: UIScrollView = {
        // Create the toolbar container view
        let toolbarContainer = UIScrollView()
        toolbarContainer.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainer.showsHorizontalScrollIndicator = false
        
        return toolbarContainer
    }()
    
    lazy var previewCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.itemSize = view.bounds.size
        
        previewCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        previewCollectionView.isPagingEnabled = true
        previewCollectionView.showsHorizontalScrollIndicator = false
        previewCollectionView.translatesAutoresizingMaskIntoConstraints = false
        previewCollectionView.backgroundColor = .clear
        previewCollectionView.dataSource = self
        previewCollectionView.delegate = self
        
        previewCollectionView.register(ImagePreviewCell.self, forCellWithReuseIdentifier: "ImagePreviewCell")
        return previewCollectionView
    }()
    
    lazy var thumbnailCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        
        thumbnailCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        thumbnailCollectionView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailCollectionView.backgroundColor = UIColor.black.withAlphaComponent(0.5) // Semi-transparent overlay
        thumbnailCollectionView.dataSource = self
        thumbnailCollectionView.delegate = self
        
        thumbnailCollectionView.register(ThumbnailCell.self, forCellWithReuseIdentifier: "ThumbnailCell")
        thumbnailCollectionView.isHidden = true
        return thumbnailCollectionView
    }()
    
    private lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "Cancel", style: .plain ,target: self, action: #selector(cancelScan))
        button.tintColor = navigationController?.navigationBar.tintColor
        return button
    }()
    
    private lazy var doneButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(finishScan))
        button.tintColor = navigationController?.navigationBar.tintColor
        return button
    }()
    
    private lazy var cancelAlert: UIAlertController = {
        let alert = UIAlertController(title: "Cancel", message: "This will remove all captured images. Would you like to proceed?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "No", style: .default, handler: {_ in
            NSLog("No")
        }))
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {_ in
            NSLog("Yes")
            EditorViewController.selectedIndex = 0
            EditorViewController.pages = []
            self.navigationController?.popViewController(animated: true)
        }))
        
        return alert
    }()

    private lazy var cropButton: UIView = {
        let button = createImageButton(self, systemName: "crop", named: "crop", action: #selector(cropImage))
        return button
    }()
    
    private lazy var enhanceButton: UIView = {
        let button = createImageButton(self, systemName: "wand.and.rays.inverse", named: "enhance", action: #selector(toggleEnhancedImage))
        return button
    }()
    
    private lazy var rotateButton: UIView = {
        let button = createImageButton(self, systemName: "rotate.right", named: "rotate", action: #selector(rotateImage))
        return button
    }()
    
    private lazy var deleteButton: UIView = {
        let button = createImageButton(self, systemName: "trash", named: "delete", action: #selector(deletePage))
        if #available(iOS 16.0, *) {
            button.isHidden = EditorViewController.pages.count == 0
        }
        return button
    }()
    
    private lazy var plusButton: UIView = {
        let button = createImageButton(self, systemName: "plus", named: "plus", action: #selector(addPage))
        return button
    }()
    
    private lazy var moreButton: UIView = {
        if #available(iOS 16.0, *) {
            return createImageButton(self, systemName: "ellipsis", named: "more", action: #selector(moreMenu))
        } else {
            return UIView()
        }
    }()
    
    private func createImageButton(_ target: Any?, systemName: String, named: String, action: Selector) -> UIView {
        let button = UIButton(type: .system)
        if let image = UIImage(systemName: systemName) {
            button.setImage(image, for: .normal)
            button.tintColor = .systemBlue
        }
        button.addTarget(target, action: action, for: .touchUpInside)
        
        button.frame.size = CGSize(width: 50, height: 50)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 50).isActive = true
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        return button
    }
    

    // MARK: - Initializers

    init(image: UIImage, quad: Quadrilateral? = nil, rotateImage: Bool = false) {
        super.init(nibName: nil, bundle: nil)
        var img = image
        if rotateImage {
            rotationAngle.value = 180
            img = image.rotated(by: rotationAngle)!
        }
        self.addPageImage(image: img, quad: quad)
    }
    
    init(results: ImageScannerResults) {
        self.results = results
        
        EditorViewController.pages[EditorViewController.selectedIndex] = self.results
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Life Cycle

    override func viewDidLoad() {
        NSLog("viewDidLoad")
        super.viewDidLoad()

        setupPreviewCollectionView()
        setupThumbnailCollectionView()
        setupCustomToolbar()
        
        title = NSLocalizedString("wescan.review.title",
                                  tableName: nil,
                                  bundle: Bundle(for: ReviewViewController.self),
                                  value: "Review",
                                  comment: "The review title of the ReviewController"
        )
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = doneButton
    }

    override func viewWillAppear(_ animated: Bool) {
        NSLog("viewWillAppear")
        super.viewWillAppear(animated)

        navigationController?.setToolbarHidden(true, animated: false)
        navigationController?.setNavigationBarHidden(false, animated: false)
        
        // Check if there's a transition coordinator and animate scrollView after the navigation animation completes
        if let coordinator = transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in
                self.animateScrollView()
            }
        } else {
            // No transition coordinator, directly animate scrollView
            animateScrollView()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        NSLog("viewDidAppear")
        super.viewDidAppear(animated)
        
        let newIndexPath = IndexPath(item: EditorViewController.selectedIndex, section: 0)
        self.thumbnailCollectionView.selectItem(at: newIndexPath, animated: true, scrollPosition: .centeredHorizontally)
        self.previewCollectionView.scrollToItem(at: newIndexPath, at: .centeredHorizontally, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        NSLog("viewWillDisappear")
        super.viewWillDisappear(animated)
        navigationController?.setToolbarHidden(true, animated: true)
    }

    // MARK: Setups
    
    private func addPageImage(image: UIImage, quad: Quadrilateral?) {
        var img = image.applyingPortraitOrientation()
        if let quad = quad, let ciImage = CIImage(image: image) {
            
            // Cropped Image
            var cartesianScaledQuad = quad.toCartesian(withHeight: image.size.height)
            cartesianScaledQuad.reorganize()
            
            let cgOrientation = CGImagePropertyOrientation(image.imageOrientation)
            let orientedImage = ciImage.oriented(forExifOrientation: Int32(cgOrientation.rawValue))
            let filteredImage = orientedImage.applyingFilter("CIPerspectiveCorrection", parameters: [
                "inputTopLeft": CIVector(cgPoint: cartesianScaledQuad.bottomLeft),
                "inputTopRight": CIVector(cgPoint: cartesianScaledQuad.bottomRight),
                "inputBottomLeft": CIVector(cgPoint: cartesianScaledQuad.topLeft),
                "inputBottomRight": CIVector(cgPoint: cartesianScaledQuad.topRight)
            ])
            img = UIImage.from(ciImage: filteredImage)
        }
        self.results.croppedScan = ImageScannerScan(image: img)
        self.results.detectedRectangle = Quadrilateral(
            topLeft: CGPoint(x: 0, y: 0),
            topRight: CGPoint(x: img.size.width, y: 0),
            bottomRight: CGPoint(x: img.size.width, y: img.size.height),
            bottomLeft: CGPoint(x: 0, y: img.size.height))
        
        EditorViewController.pages.append(self.results)
        EditorViewController.selectedIndex = EditorViewController.pages.count - 1
        
        if EditorViewController.pages.count > 1 {
            self.thumbnailCollectionView.reloadData()
            self.previewCollectionView.reloadData()
            
            self.thumbnailCollectionView.layoutIfNeeded()
            self.previewCollectionView.layoutIfNeeded()
        }
    }
    
    func setupPreviewCollectionView() {
        NSLog("setupPreviewCollectionView")
        view.addSubview(previewCollectionView)
        
        NSLayoutConstraint.activate([
            previewCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewCollectionView.topAnchor.constraint(equalTo: view.topAnchor),
            previewCollectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100) // Adjust height as needed
        ])
    }
    
    private func setupThumbnailCollectionView() {
        NSLog("setupThumbnailCollectionView")
        view.addSubview(thumbnailCollectionView)
        
        NSLayoutConstraint.activate([
            thumbnailCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            thumbnailCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            thumbnailCollectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            thumbnailCollectionView.heightAnchor.constraint(equalToConstant: 80) // Adjust height as needed
        ])
        
        if EditorViewController.pages.count > 0 {
            self.thumbnailCollectionView.isHidden = false
        }
    }
    
    func setupCustomToolbar() {
        NSLog("setupCustomToolbar")
        self.view.addSubview(toolbarContainer)
        
        // Create the toolbar stack view
        let toolbarStackView = UIStackView()
        toolbarStackView.axis = .horizontal
        toolbarStackView.spacing = 20
        toolbarStackView.translatesAutoresizingMaskIntoConstraints = false
        toolbarStackView.backgroundColor = .systemBackground //systemGray.withAlphaComponent(0.1) // Translucent background color
        toolbarContainer.addSubview(toolbarStackView)
        
        // Add buttons to the toolbar
        toolbarStackView.addArrangedSubview(cropButton)
        toolbarStackView.addArrangedSubview(enhanceButton)
        toolbarStackView.addArrangedSubview(rotateButton)
        toolbarStackView.addArrangedSubview(deleteButton)
        toolbarStackView.addArrangedSubview(plusButton)
        toolbarStackView.addArrangedSubview(moreButton)
        
        // Ensure the content size of the stack view is large enough to scroll
        toolbarStackView.widthAnchor.constraint(greaterThanOrEqualTo: self.view.widthAnchor).isActive = true
        
       
        // Setting up initial constraints
        NSLayoutConstraint.activate([
            toolbarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarContainer.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        // Bottom constraint, initially off-screen
        toolbarContainerBottomConstraint = toolbarContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 80)
        toolbarContainerBottomConstraint.isActive = true
        
        // Set constraints for the stack view
        NSLayoutConstraint.activate([
            toolbarStackView.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor, constant: 10),
            toolbarStackView.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor, constant: -10),
            toolbarStackView.topAnchor.constraint(equalTo: toolbarContainer.topAnchor, constant: 30),
            toolbarStackView.bottomAnchor.constraint(equalTo: toolbarContainer.bottomAnchor)
        ])
    }
    
    private func animateScrollView() {
        // Update the bottom constraint to the final position
        toolbarContainerBottomConstraint.constant = 0
        
        // Animate the constraint change
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseOut], animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
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

    // MARK: - Actions

    @objc private func reloadImage() {
//        if showEnhancedImage {
//            let ciImage = CIImage(image: results.croppedScan.image)
//            let enhancedImage = ciImage?.applyingAdaptiveThreshold()?.withFixedOrientation()
//            let enhancedScan = enhancedImage.flatMap { ImageScannerScan(image: $0) }
//            results.enhancedScan = enhancedScan
//            
//            imageView.image = results.enhancedScan?.image.rotated(by: rotationAngle)
//        } else {
//            imageView.image = results.croppedScan.image.rotated(by: rotationAngle)
//        }
//        
//        if let image = imageView.image {
//            self.results.detectedRectangle = Quadrilateral(
//                topLeft: CGPoint(x: 0, y: 0),
//                topRight: CGPoint(x: image.size.width, y: 0),
//                bottomRight: CGPoint(x: image.size.width, y: image.size.height),
//                bottomLeft: CGPoint(x: 0, y: image.size.height))
//        }
    }

    @objc func toggleEnhancedImage() {
        NSLog("toggleEnhancedImage")
        showEnhancedImage.toggle()
        reloadImage()

        if showEnhancedImage {
            enhanceButton.tintColor = .yellow
        } else {
            enhanceButton.tintColor = .white
        }
    }

    @objc func rotateImage() {
        NSLog("rotateImage")
        rotationAngle.value += 90

        if rotationAngle.value == 360 {
            rotationAngle.value = 0
        }

        reloadImage()
    }
    
    @objc private func cancelScan() {
        NSLog("cancelScan")
        self.present(cancelAlert, animated: true, completion: nil)
    }

    @objc private func finishScan() {
        NSLog("finishScan")
        guard let imageScannerController = navigationController as? ImageScannerController else { return }

        results.croppedScan.rotate(by: rotationAngle)
        results.enhancedScan?.rotate(by: rotationAngle)
        results.doesUserPreferEnhancedScan = showEnhancedImage
        imageScannerController.imageScannerDelegate?
            .imageScannerController(imageScannerController, didFinishScanningWithResults: results)
    }
    
    @objc private func cropImage() {
        NSLog("cropImage")
        let cropVC = CropScanViewController(image: results.croppedScan.image.rotated(by: rotationAngle)!, quad: results.detectedRectangle)
        navigationController?.pushViewController(cropVC, animated: false)
    }
    
    @objc private func addPage() {
        NSLog("addPage")
        if (EditorViewController.pages.first(where: { $0 == results }) == nil) {
            EditorViewController.pages.append(results)
            EditorViewController.selectedIndex = EditorViewController.pages.count - 1
        }
        
        let scannerViewController = ScannerViewController(
            cancelAction: {
                self.navigationController?.popViewController(animated: false)
            },
            captureAction: { image, quad in
                self.addPageImage(image: image, quad: quad)
                self.navigationController?.popViewController(animated: false)
            }
        )
        self.navigationController?.pushViewController(scannerViewController, animated: true)
    }
    
    @objc private func deletePage() {
        NSLog("deletePage")
        guard EditorViewController.pages.indices.contains(EditorViewController.selectedIndex) else { return }
        EditorViewController.pages.remove(at: EditorViewController.selectedIndex)
        
        guard EditorViewController.pages.count > 0 else {
            navigationController?.popViewController(animated: true)
            return
        }
        
        self.previewCollectionView.reloadData()
        self.thumbnailCollectionView.reloadData()
        
        NSLog("Min Index = \(EditorViewController.selectedIndex) or \(EditorViewController.pages.count - 1)")
        EditorViewController.selectedIndex = min(EditorViewController.selectedIndex, EditorViewController.pages.count - 1)
        let indexPath = IndexPath(item: EditorViewController.selectedIndex, section: 0)
        NSLog("select Index = \(indexPath.item)")
        self.previewCollectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
        self.thumbnailCollectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
    }
    
    @available(iOS 16.0, *)
    @objc private func moreMenu() {
        NSLog("moreMenu")
        // Show the bottom sheet when the button is tapped
        let bottomSheetVC = BottomSheetViewController()
        bottomSheetVC.modalPresentationStyle = .pageSheet
        bottomSheetVC.preferredContentSize = CGSize(width: view.frame.width, height: 100) // Set preferred content size
        
        if let sheet = bottomSheetVC.sheetPresentationController {
            sheet.detents = [.custom { _ in return 100 }] // Set a custom detent for the height
            sheet.prefersGrabberVisible = true
        }
        present(bottomSheetVC, animated: true, completion: nil)
    }
    
    
    // MARK: UICollectionViewDataSource methods
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return EditorViewController.pages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == self.previewCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImagePreviewCell", for: indexPath) as! ImagePreviewCell
            cell.imageView.image = EditorViewController.pages[indexPath.item].croppedScan.image
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ThumbnailCell", for: indexPath) as! ThumbnailCell
            cell.imageView.image = EditorViewController.pages[indexPath.item].croppedScan.image
            return cell
        }
    }
    
    // UICollectionViewDelegateFlowLayout method
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == self.previewCollectionView {
            return collectionView.bounds.size
        } else {
            return CGSize(width: 60, height: 60) // Adjust size as needed
        }
    }
    
    // Handle cell selection
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        NSLog("Tapped image at index: \(indexPath.item)")
        if collectionView == self.thumbnailCollectionView {
            EditorViewController.selectedIndex = indexPath.item
            self.previewCollectionView.reloadData()
            self.previewCollectionView.layoutIfNeeded()
            self.previewCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }
    }
    
    // Detect scroll end to update the selected index
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        NSLog("scrollViewDidEndDecelerating")
        if scrollView == previewCollectionView, let indexPath = getVisibleIndexPath(for: scrollView) {
            updateSelectedImageIndex(to: indexPath)
        }
    }
    
    func getVisibleIndexPath(for scrollView: UIScrollView) -> IndexPath? {
        NSLog("getVisibleIndexPath")
        let visibleRect = CGRect(origin: scrollView.contentOffset, size: scrollView.bounds.size)
        let visiblePoint = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
        return previewCollectionView.indexPathForItem(at: visiblePoint)
    }
    
    func updateSelectedImageIndex(to indexPath: IndexPath) {
        NSLog("updateSelectedImageIndex")
        EditorViewController.selectedIndex = indexPath.item
        thumbnailCollectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
    }
}

class ImagePreviewCell: UICollectionViewCell {
    let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.layer.masksToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
       
        return iv
    }()
    
  
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class ThumbnailCell: UICollectionViewCell {
    let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 10 // Rounded corners
        iv.layer.masksToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        
        iv.layer.shadowColor = UIColor.black.cgColor
        iv.layer.shadowOffset = CGSize(width: 0, height: 2)
        iv.layer.shadowOpacity = 0.5
        iv.layer.shadowRadius = 4
        iv.layer.borderWidth = 1
        iv.layer.borderColor = UIColor.gray.cgColor

        return iv
    }()
    
    let overlayView: UIView = {
        let view = UIView()
        view.layer.borderColor = UIColor.red.cgColor
        view.layer.borderWidth = 2
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true
        view.isHidden = true // Hidden by default
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.addSubview(imageView)
        contentView.addSubview(overlayView)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            overlayView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isSelected: Bool {
        didSet {
            overlayView.isHidden = !isSelected // Show overlay if selected
        }
    }
}

class BottomSheetViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure the bottom sheet view
        view.backgroundColor = .white
        
        // Create a horizontally scrollable view
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Create a stack view to hold the content
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        // Add some sample views to the stack view
        for i in 1...10 {
            let label = UILabel()
            label.text = "Item \(i)"
            label.textAlignment = .center
            label.backgroundColor = .lightGray
            label.widthAnchor.constraint(equalToConstant: 100).isActive = true
            label.heightAnchor.constraint(equalToConstant: 100).isActive = true
            stackView.addArrangedSubview(label)
        }
        
        // Set up constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }
}
