import UIKit
import AVFoundation
import CoreImage
import Vision

class VideoEditorViewController: UIViewController {
    // MARK: - Video
    var videoURL: URL? {
        didSet {
            if let url = videoURL {
                generateThumbnails(for: url)
            }
        }
    }
    
    @IBOutlet weak var previewContainer: UIView!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var bottomControls: UIStackView!
    @IBOutlet weak var viewLoader: UIView!
    @IBOutlet weak var loader: UIActivityIndicatorView!
    @IBOutlet weak var viewMainLoader: UIView!
    @IBOutlet weak var contextControlsContainer: UIView!
    @IBOutlet var allBtns: [UIButton]!

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var baseThumbnail: UIImage?
    private var filterThumbnails: [(name: String, image: UIImage?)] = []
    private let filterNames: [(display: String, ciName: String?)] = [
        ("Original", nil),
        ("Noir", "CIPhotoEffectNoir"),
        ("Chrome", "CIPhotoEffectChrome"),
        ("Fade", "CIPhotoEffectFade"),
        ("Instant", "CIPhotoEffectInstant"),
        ("Mono", "CIPhotoEffectMono"),
        ("Process", "CIPhotoEffectProcess"),
        ("Tonal", "CIPhotoEffectTonal"),
        ("Transfer", "CIPhotoEffectTransfer")
    ]
    private var selectedCIFilterName: String? = nil
    private var filterContext: CIContext?
    
    
    // MARK: - UI Elements
    private let filterScrollView = UIScrollView()
    private let filterStackView = UIStackView()
    
    private let speedStackView = UIStackView()
    private let speedSlider = UISlider()
    private let speedLabel = UILabel()
    private var currentSpeed: Float = 1.0
    private let speedValues: [Float] = [0.25, 0.50, 0.75, 1.0, 1.25, 1.50, 1.75, 2.0]
    
    private let adjustStackView = UIStackView()
    
    private let brighnessValue = UILabel()
    private let contrastValue = UILabel()
    private let saturationValue = UILabel()
    
    // Adjust properties
    private var brightness: Float = 0.0 {
        didSet {
            brighnessValue.text = String(format: "%.1f", brightness)
            updateVideoAdjustments()
        }
    }
    private var contrast: Float = 1.0 {
        didSet {
            contrastValue.text = String(format: "%.1f", contrast)
            updateVideoAdjustments()
        }
    }
    private var saturation: Float = 1.0 {
        didSet {
            saturationValue.text = String(format: "%.1f", saturation)
            updateVideoAdjustments()
        }
    }
    
    var videoSpeed: Float = 1.0
    var tintColor = UIColor()
    
    
    
    //Trim
    private let trimTimelineView = UIView()
    private let trimDeleteArea = UIView()
    private let trimDeleteLabel = UILabel()
    private let trimHandleLeft = UIView()
    private let trimHandleRight = UIView()
    private let trimHighlightView = UIView()
    private let trimThumbnailsStackView = UIStackView()
    private var trimThumbnails: [UIImageView] = []
    private var trimStartTime: Float = 0
    private var trimEndTime: Float = 0
    private let trimLeftButton = UIButton(type: .system)
    private let trimRightButton = UIButton(type: .system)
    private let trimApplyButton = UIButton(type: .system)
    private let trimUndoButton = UIButton(type: .system)
    private var originalTrimStartTime: Float = 0
    private var originalTrimEndTime: Float = 0
    private var isTrimming = false
    private var videoDuration: Float = 0
    private var isDraggingLeft = false
    private var isDraggingRight = false
    private var panStartX: CGFloat = 0
    private let thumbnailCount = 15
    
    private let blurStackView = UIStackView()
    private let blurSwitch = UISwitch()
    private let blurLabel = UILabel()
    private var isFaceBlurEnabled = false
    private var faceDetector: VNDetectFaceRectanglesRequest?
    private var blurredVideoURL: URL?
    private var timeObserver: Any?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        viewLoader.layer.cornerRadius = 10.0
        viewMainLoader.isHidden = true
        filterContext = CIContext(options: [.useSoftwareRenderer: false])
        setupPreview()
        
        setupFilterControls()
        setupSpeedControls()
        setupAdjustControls()
        setupBlurControls()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.setupTrimThumbnails()
        }
        
        self.allBtns.forEach { btn in
            btn.tintColor = self.tintColor
        }
        self.loader.color = self.tintColor
        self.blurSwitch.onTintColor = self.tintColor
    }
    
    func showLoader()
    {
        self.viewMainLoader.isHidden = false
        self.loader.startAnimating()
    }
    
    func hideLoader()
    {
        self.viewMainLoader.isHidden = true
        self.loader.stopAnimating()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let url = videoURL {
            setupPlayer(with: url, filterName: selectedCIFilterName)
        }
        
        let asset = AVAsset(url: self.videoURL!)
        videoDuration = Float(CMTimeGetSeconds(asset.duration))
        trimStartTime = 0
        trimEndTime = videoDuration
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = previewContainer.bounds
    }
    
    
    func setupPreview() {
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        playPauseButton.layer.cornerRadius = 25
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        
        previewContainer.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(playPauseTapped))
        previewContainer.addGestureRecognizer(tapGesture)
    }
    
    
    
    private func setupPlayer(with url: URL, filterName: String? = nil) {
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        let asset = AVAsset(url: url)
        let item: AVPlayerItem
        
        let composition = AVVideoComposition(asset: asset) { [weak self] request in
            guard let self = self else { return }
            var source = request.sourceImage.clampedToExtent()
            
            // Apply filter if any
            if let filterName = filterName, let ciFilter = CIFilter(name: filterName) {
                ciFilter.setValue(source, forKey: kCIInputImageKey)
                if let output = ciFilter.outputImage?.cropped(to: source.extent) {
                    source = output
                }
            }
            
            // Apply color adjustments
            if let colorControls = CIFilter(name: "CIColorControls") {
                colorControls.setValue(source, forKey: kCIInputImageKey)
                colorControls.setValue(self.brightness, forKey: kCIInputBrightnessKey)
                colorControls.setValue(self.contrast, forKey: kCIInputContrastKey)
                colorControls.setValue(self.saturation, forKey: kCIInputSaturationKey)
                
                if let output = colorControls.outputImage {
                    source = output.cropped(to: source.extent)
                }
            }
            
            request.finish(with: source, context: self.filterContext)
        }
        
        item = AVPlayerItem(asset: asset)
        item.videoComposition = composition
        
        player = AVPlayer(playerItem: item)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = previewContainer.bounds
        playerLayer?.videoGravity = .resizeAspect
        player?.rate = self.videoSpeed
        if let playerLayer = playerLayer {
            previewContainer.layer.insertSublayer(playerLayer, below: playPauseButton.layer)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseButton.isHidden = true
    }
    
    @objc private func playPauseTapped() {
        guard let player = player else { return }
        if player.timeControlStatus == .playing{
            player.pause()
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        } else {
            player.play()
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        player?.seek(to: .zero)
    }
    
    
    @IBAction func filterTapped()
    {
        self.filterStackView.isHidden = false
        self.speedStackView.isHidden = true
        self.adjustStackView.isHidden = true
        self.blurStackView.isHidden = true
        self.contextControlsContainer.isHidden = true
    }
    
    @IBAction func trimTapped() {
        self.filterStackView.isHidden = true
        self.speedStackView.isHidden = true
        self.adjustStackView.isHidden = true
        self.blurStackView.isHidden = true
        self.contextControlsContainer.isHidden = false
    }
    
    @IBAction func speedTapped() {
        self.filterStackView.isHidden = true
        self.speedStackView.isHidden = false
        self.adjustStackView.isHidden = true
        self.blurStackView.isHidden = true
        self.contextControlsContainer.isHidden = true
    }
    
    @IBAction func adjustTapped()
    {
        self.filterStackView.isHidden = true
        self.speedStackView.isHidden = true
        self.adjustStackView.isHidden = false
        self.blurStackView.isHidden = true
        self.contextControlsContainer.isHidden = true
    }

    @IBAction func blurTapped()
    {
        self.filterStackView.isHidden = true
        self.speedStackView.isHidden = true
        self.adjustStackView.isHidden = true
        self.blurStackView.isHidden = false
        self.contextControlsContainer.isHidden = true
    }
}


// MARK: - Filter Section
extension VideoEditorViewController
{
     func generateThumbnails(for url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0, preferredTimescale: 60)
            var baseImage: UIImage? = nil
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                baseImage = UIImage(cgImage: cgImage)
            } catch {
                print("Error generating thumbnail: \(error)")
            }
            self.baseThumbnail = baseImage
            var thumbs: [(String, UIImage?)] = []
            for filter in self.filterNames {
                if let ciName = filter.ciName, let base = baseImage {
                    thumbs.append((filter.display, self.applyFilter(ciName, to: base)))
                } else {
                    thumbs.append((filter.display, baseImage))
                }
            }
            DispatchQueue.main.async {
                self.filterThumbnails = thumbs
                self.reloadFilterStackView()
            }
        }
    }
    
     func applyFilter(_ name: String, to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let context = CIContext()
        guard let filter = CIFilter(name: name) else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
     func reloadFilterStackView() {
        for view in filterStackView.arrangedSubviews { view.removeFromSuperview() }
        for (i, thumb) in filterThumbnails.enumerated() {
            let imageView = UIImageView(image: thumb.image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = .white
            imageView.layer.cornerRadius = 8
            imageView.widthAnchor.constraint(equalToConstant: 60).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 60).isActive = true
            imageView.isUserInteractionEnabled = true
            imageView.tag = i
            let tap = UITapGestureRecognizer(target: self, action: #selector(filterTapped(_:)))
            imageView.addGestureRecognizer(tap)
            let label = UILabel()
            label.text = thumb.name
            label.font = UIFont.systemFont(ofSize: 12)
            label.textAlignment = .center
            let stack = UIStackView(arrangedSubviews: [imageView, label])
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 4
            filterStackView.addArrangedSubview(stack)
        }
    }
    
    @objc private func filterTapped(_ sender: UITapGestureRecognizer) {
        guard let tag = sender.view?.tag else { return }
        let filter = filterNames[tag]
        selectedCIFilterName = filter.ciName
        
        // Use blurred video URL if blur is enabled, otherwise use original video URL
        let videoToUse = isFaceBlurEnabled ? (blurredVideoURL ?? videoURL!) : videoURL!
        setupPlayer(with: videoToUse, filterName: selectedCIFilterName)
    }
    
    func setupFilterControls() {
        filterScrollView.showsHorizontalScrollIndicator = false
        filterScrollView.translatesAutoresizingMaskIntoConstraints = false
        filterStackView.axis = .horizontal
        filterStackView.spacing = 16
        filterStackView.translatesAutoresizingMaskIntoConstraints = false
        filterScrollView.addSubview(filterStackView)
        view.addSubview(filterScrollView)
        
        NSLayoutConstraint.activate([
            filterScrollView.bottomAnchor.constraint(equalTo: bottomControls.topAnchor, constant: -20),
            filterScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            filterScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            filterScrollView.heightAnchor.constraint(equalToConstant: 80),
            
            filterStackView.topAnchor.constraint(equalTo: filterScrollView.topAnchor),
            filterStackView.bottomAnchor.constraint(equalTo: filterScrollView.bottomAnchor),
            filterStackView.leadingAnchor.constraint(equalTo: filterScrollView.leadingAnchor),
            filterStackView.trailingAnchor.constraint(equalTo: filterScrollView.trailingAnchor)
        ])
    }
}

// MARK: - Speed Control Section
extension VideoEditorViewController
{
    func setupSpeedControls() {
        // Configure speed stack view
        speedStackView.axis = .vertical
        speedStackView.spacing = 16
        speedStackView.translatesAutoresizingMaskIntoConstraints = false
        speedStackView.isHidden = true
        view.addSubview(speedStackView)
        
        // Configure speed label
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        speedLabel.text = "Speed: 1.0x"
        speedLabel.textAlignment = .center
        speedLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        // Configure speed slider
        speedSlider.translatesAutoresizingMaskIntoConstraints = false
        speedSlider.minimumValue = 0
        speedSlider.maximumValue = Float(speedValues.count - 1)
        speedSlider.value = 3 // Default to 1.0x (index 3)
        speedSlider.addTarget(self, action: #selector(speedSliderValueChanged), for: .valueChanged)
        
        // Add subviews
        speedStackView.addArrangedSubview(speedLabel)
        speedStackView.addArrangedSubview(speedSlider)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            speedStackView.bottomAnchor.constraint(equalTo: bottomControls.topAnchor, constant: -20),
            speedStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            speedStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            speedSlider.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func speedSliderValueChanged(_ sender: UISlider) {
        // Round to nearest index
        let index = Int(round(sender.value))
        let speed = speedValues[index]
        currentSpeed = speed
        speedLabel.text = String(format: "Speed: %.2fx", speed)
        
        // Update player rate
        player?.rate = speed
        
        self.videoSpeed = speed
    }
    
    private func resetSpeed() {
        speedSlider.value = 3 // Reset to 1.0x
        currentSpeed = 1.0
        speedLabel.text = "Speed: 1.0x"
        player?.rate = 1.0
    }
}

// MARK: - Adjust Control Section
extension VideoEditorViewController
{
    private func createAdjustControl(valueLabel: UILabel, title: String, min: Float, max: Float, value: Float, handler: @escaping (Float) -> Void) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 12)
        
        valueLabel.text = String(format: "%.1f", value)
        valueLabel.font = .systemFont(ofSize: 12)
        valueLabel.textAlignment = .right
        valueLabel.textColor = .systemBlue
        
        let slider = UISlider()
        slider.minimumValue = min
        slider.maximumValue = max
        slider.value = value
        slider.addTarget(self, action: #selector(adjustSliderValueChanged(_:)), for: .valueChanged)
        slider.tag = title == "Brightness" ? 0 : (title == "Contrast" ? 1 : 2)
        
        // Store references
        objc_setAssociatedObject(slider, "valueLabel", valueLabel, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(slider, "handler", handler, .OBJC_ASSOCIATION_RETAIN)
        
        let horizontalStack = UIStackView(arrangedSubviews: [label, valueLabel])
        horizontalStack.axis = .horizontal
        horizontalStack.distribution = .equalSpacing
        horizontalStack.spacing = 8
        
        stack.addArrangedSubview(horizontalStack)
        stack.addArrangedSubview(slider)
        
        return stack
    }
    
    @objc private func adjustSliderValueChanged(_ sender: UISlider) {
        let value = sender.value
        
        // Update the value label
        if let valueLabel = objc_getAssociatedObject(sender, "valueLabel") as? UILabel {
            valueLabel.text = String(format: "%.1f", value)
        }
        
        // Update the corresponding property
        switch sender.tag {
        case 0: // Brightness
            brightness = value
        case 1: // Contrast
            contrast = value
        case 2: // Saturation
            saturation = value
        default:
            break
        }
    }
    
    func setupAdjustControls() {
        // Configure adjust stack view
        adjustStackView.axis = .vertical
        adjustStackView.spacing = 10
        adjustStackView.translatesAutoresizingMaskIntoConstraints = false
        adjustStackView.isHidden = true
        view.addSubview(adjustStackView)
        
        // Create controls for each property with initial values
        let brightnessControl = createAdjustControl(valueLabel: self.brighnessValue, title: "Brightness", min: -1.0, max: 1.0, value: brightness) { [weak self] value in
            self?.brightness = value
        }
        
        let contrastControl = createAdjustControl(valueLabel: self.contrastValue, title: "Contrast", min: 0.0, max: 2.0, value: contrast) { [weak self] value in
            self?.contrast = value
        }
        
        let saturationControl = createAdjustControl(valueLabel: self.saturationValue, title: "Saturation", min: 0.0, max: 2.0, value: saturation) { [weak self] value in
            self?.saturation = value
        }
        
        // Add subviews
        adjustStackView.addArrangedSubview(brightnessControl)
        adjustStackView.addArrangedSubview(contrastControl)
        adjustStackView.addArrangedSubview(saturationControl)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            adjustStackView.bottomAnchor.constraint(equalTo: bottomControls.topAnchor, constant: -20),
            adjustStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            adjustStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    private func updateVideoAdjustments() {
        guard let player = player, let asset = player.currentItem?.asset else { return }
        
        let composition = AVVideoComposition(asset: asset) { [weak self] request in
            guard let self = self else { return }
            var source = request.sourceImage.clampedToExtent()
            
            // Apply filter if any
            if let filterName = self.selectedCIFilterName, let ciFilter = CIFilter(name: filterName) {
                ciFilter.setValue(source, forKey: kCIInputImageKey)
                if let output = ciFilter.outputImage?.cropped(to: source.extent) {
                    source = output
                }
            }
            
            // Apply color adjustments
            if let colorControls = CIFilter(name: "CIColorControls") {
                colorControls.setValue(source, forKey: kCIInputImageKey)
                colorControls.setValue(self.brightness, forKey: kCIInputBrightnessKey)
                colorControls.setValue(self.contrast, forKey: kCIInputContrastKey)
                colorControls.setValue(self.saturation, forKey: kCIInputSaturationKey)
                
                if let output = colorControls.outputImage {
                    source = output.cropped(to: source.extent)
                }
            }
            
            request.finish(with: source, context: self.filterContext)
        }
        
        // Create a new player item with the composition
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.videoComposition = composition
        
        // Store current time
        let currentTime = player.currentTime()
        
        // Replace the current player item
        player.replaceCurrentItem(with: playerItem)
        
        // Restore playback position and state
        player.seek(to: currentTime)
        if player.timeControlStatus == .playing {
            player.play()
        }
    }
}

// MARK: - Blur Control Section
extension VideoEditorViewController {
    private func setupBlurControls() {
        // Configure blur stack view
        blurStackView.axis = .vertical
        blurStackView.spacing = 10
        blurStackView.translatesAutoresizingMaskIntoConstraints = false
        blurStackView.isHidden = true
        view.addSubview(blurStackView)
        
        // Configure blur label
        blurLabel.text = "Face Blur"
        blurLabel.font = .systemFont(ofSize: 16)
        
        // Configure blur switch
        blurSwitch.addTarget(self, action: #selector(blurSwitchChanged), for: .valueChanged)
        
        // Create horizontal stack for label and switch
        let controlStack = UIStackView(arrangedSubviews: [blurLabel, blurSwitch])
        controlStack.axis = .horizontal
        controlStack.distribution = .equalSpacing
        controlStack.alignment = .center
        
        blurStackView.addArrangedSubview(controlStack)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            blurStackView.bottomAnchor.constraint(equalTo: bottomControls.topAnchor, constant: -20),
            blurStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            blurStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        // Initialize face detector
        faceDetector = VNDetectFaceRectanglesRequest()
    }
    
    @objc private func blurSwitchChanged(_ sender: UISwitch) {
        isFaceBlurEnabled = sender.isOn
        if isFaceBlurEnabled {
            self.blurVideo(at: self.videoURL!)
        } else {
            blurredVideoURL = nil
            setupPlayer(with: videoURL!, filterName: selectedCIFilterName)
        }
    }
    
    func blurVideo(at url: URL) {
        let asset = AVAsset(url: url)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            print("❌ No video track found")
            return
        }
        
        let duration = Float(CMTimeGetSeconds(asset.duration))
        let nominalFrameRate = videoTrack.nominalFrameRate
        
        // Get the original video size and transform
        let naturalSize = videoTrack.naturalSize
        let preferredTransform = videoTrack.preferredTransform
        
        guard let reader = try? AVAssetReader(asset: asset) else {
            print("❌ Failed to create AVAssetReader")
            return
        }

        let readerSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerSettings)
        if !reader.canAdd(readerOutput) {
            print("❌ Cannot add reader output")
            return
        }
        reader.add(readerOutput)
        
        if !reader.startReading() {
            print("❌ Failed to start reading: \(reader.error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("blurred_\(Int(Date().timeIntervalSince1970)).mov")
        try? FileManager.default.removeItem(at: outputURL)
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
            print("❌ Failed to create AVAssetWriter")
            return
        }
        
        // Use the original video's natural size and transform
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: naturalSize.width,
            AVVideoHeightKey: naturalSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2000000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        writerInput.transform = preferredTransform // Apply the original transform
        
        if !writer.canAdd(writerInput) {
            print("❌ Cannot add writer input")
            return
        }
        writer.add(writerInput)
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: naturalSize.width,
            kCVPixelBufferHeightKey as String: naturalSize.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        if !writer.startWriting() {
            print("❌ Failed to start writing: \(writer.error?.localizedDescription ?? "Unknown error")")
            return
        }
        writer.startSession(atSourceTime: .zero)
        
        let ciContext = CIContext()
        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.setValue(50.0, forKey: kCIInputRadiusKey)
        
        print("🎬 Processing started...")
        self.showLoader()
        let processingQueue = DispatchQueue(label: "videoProcessingQueue")
        var frameCount: Float = 0
        var isProcessing = true
        
        processingQueue.async {
            while isProcessing {
                autoreleasepool {
                    if reader.status != .reading {
                        print("❌ Reader status changed to: \(reader.status.rawValue)")
                        if let error = reader.error {
                            print("Reader error: \(error.localizedDescription)")
                        }
                        isProcessing = false
                        writerInput.markAsFinished()
                        writer.finishWriting { [weak self] in
                            guard let self = self else { return }
                            if writer.status == .completed {
                                print("✅ Video processing completed!")
                                DispatchQueue.main.async {
                                    self.hideLoader()
                                    self.blurredVideoURL = outputURL
                                    self.setupPlayer(with: outputURL, filterName: self.selectedCIFilterName)
                                }
                            } else {
                                self.hideLoader()
                                print("❌ Writing failed: \(writer.error?.localizedDescription ?? "Unknown error")")
                            }
                        }
                        return
                    }
                    
                    guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
                        isProcessing = false
                        writerInput.markAsFinished()
                        writer.finishWriting { [weak self] in
                            guard let self = self else { return }
                            if writer.status == .completed {
                                print("✅ Video processing completed!")
                                DispatchQueue.main.async {
                                    self.hideLoader()
                                    self.blurredVideoURL = outputURL
                                    self.setupPlayer(with: outputURL, filterName: self.selectedCIFilterName)
                                }
                            } else {
                                self.hideLoader()
                                print("❌ Writing failed: \(writer.error?.localizedDescription ?? "Unknown error")")
                            }
                        }
                        return
                    }
                    
                    let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    frameCount += 1
                    
                    let progress = (Float(CMTimeGetSeconds(presentationTime)) / duration) * 100
                    if Int(frameCount) % Int(nominalFrameRate) == 0 {
                        print("📊 Progress: \(Int(progress))%")
                    }
                    
                    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                        print("⚠️ Could not get pixel buffer")
                        self.hideLoader()
                        return
                    }
                    
                    var finalImage = CIImage(cvPixelBuffer: pixelBuffer)
                    let request = VNDetectFaceRectanglesRequest()
                    let handler = VNImageRequestHandler(ciImage: finalImage, options: [:])
                    do {
                        try handler.perform([request])
                        if let faces = request.results as? [VNFaceObservation] {
                            for face in faces {
                                let faceRect = VNImageRectForNormalizedRect(face.boundingBox,
                                                                          Int(naturalSize.width),
                                                                          Int(naturalSize.height))
                                let padding: CGFloat = 100
                                let expandedRect = faceRect.insetBy(dx: -padding, dy: -padding)
                                let clampedRect = expandedRect.intersection(CGRect(origin: .zero, size: naturalSize))
                                
                                blurFilter.setValue(finalImage, forKey: kCIInputImageKey)
                                if let blurred = blurFilter.outputImage?.cropped(to: clampedRect) {
                                    let mask = CIFilter(name: "CIRadialGradient", parameters: [
                                        "inputRadius0": min(clampedRect.width, clampedRect.height) / 2,
                                        "inputRadius1": min(clampedRect.width, clampedRect.height) / 2 + 1,
                                        kCIInputCenterKey: CIVector(x: clampedRect.midX, y: clampedRect.midY),
                                        "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: 1),
                                        "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0)
                                    ])?.outputImage?.cropped(to: clampedRect)
                                    if let mask = mask {
                                        let masked = blurred.applyingFilter("CIBlendWithMask", parameters: [
                                            kCIInputBackgroundImageKey: finalImage,
                                            kCIInputMaskImageKey: mask
                                        ])
                                        finalImage = masked
                                    }
                                }
                            }
                        }
                    } catch {
                        self.hideLoader()
                        print("⚠️ Face detection failed: \(error.localizedDescription)")
                    }
                    
                    var outputBuffer: CVPixelBuffer?
                    CVPixelBufferCreate(kCFAllocatorDefault,
                                      Int(naturalSize.width),
                                      Int(naturalSize.height),
                                      kCVPixelFormatType_32BGRA,
                                      pixelBufferAttributes as CFDictionary,
                                      &outputBuffer)
                    if let buffer = outputBuffer {
                        ciContext.render(finalImage, to: buffer)
                        
                        if !adaptor.append(buffer, withPresentationTime: presentationTime) {
                            print("⚠️ Failed to append frame at \(CMTimeGetSeconds(presentationTime))")
                            self.hideLoader()
                            if let error = writer.error {
                                print("Error: \(error.localizedDescription)")
                            }
                            isProcessing = false
                            writerInput.markAsFinished()
                            return
                        }
                    }
                }
            }
        }
    }
}


// MARK: - Trim Section
extension VideoEditorViewController
{
    func setupTrimThumbnails() {
        
        let frame = CGRect(x: 20, y: 0, width: contextControlsContainer.frame.width - 40, height: contextControlsContainer.frame.height)
        trimTimelineView.translatesAutoresizingMaskIntoConstraints = false
        trimTimelineView.backgroundColor = .red
        trimTimelineView.frame = frame
        contextControlsContainer.addSubview(trimTimelineView)
        
        trimThumbnailsStackView.frame = CGRect(x: 0, y: 0, width: trimTimelineView.frame.width, height: trimTimelineView.frame.height)
        trimThumbnailsStackView.axis = .horizontal
        trimThumbnailsStackView.spacing = 0
        trimThumbnailsStackView.distribution = .fillEqually
        trimThumbnailsStackView.backgroundColor = .green
        trimTimelineView.addSubview(trimThumbnailsStackView)

        if let url = videoURL {
            generateTrimThumbnails(for: url)
        }
        
        self.view.bringSubviewToFront(contextControlsContainer)
        
        self.setupTrimHandles()
    }
    
    func generateTrimThumbnails(for url: URL) {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Calculate time intervals for thumbnails
        let duration = CMTimeGetSeconds(asset.duration)
        let interval = duration / Double(thumbnailCount)
        
        // Clear existing thumbnails
        trimThumbnails.forEach { $0.removeFromSuperview() }
        trimThumbnails.removeAll()
        
        // Generate thumbnails
        for i in 0..<thumbnailCount {
            let time = CMTime(seconds: Double(i) * interval, preferredTimescale: 600)
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = .black
            trimThumbnailsStackView.addArrangedSubview(imageView)
            trimThumbnails.append(imageView)
            
            // Generate thumbnail image
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                imageView.image = UIImage(cgImage: cgImage)
            } catch {
                print("Error generating thumbnail: \(error)")
            }
        }
    }
    
    private func setupTrimHandles() {
        // Left handle
        trimHandleLeft.translatesAutoresizingMaskIntoConstraints = false
        trimHandleLeft.backgroundColor = .systemBlue
        trimHandleLeft.layer.cornerRadius = 4
        trimHandleLeft.isUserInteractionEnabled = true
        trimTimelineView.addSubview(trimHandleLeft)
        
        // Right handle
        trimHandleRight.translatesAutoresizingMaskIntoConstraints = false
        trimHandleRight.backgroundColor = .systemBlue
        trimHandleRight.layer.cornerRadius = 4
        trimHandleRight.isUserInteractionEnabled = true
        trimTimelineView.addSubview(trimHandleRight)
        
        // Highlight view
        trimHighlightView.translatesAutoresizingMaskIntoConstraints = false
        trimHighlightView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        trimHighlightView.layer.borderColor = UIColor.systemBlue.cgColor
        trimHighlightView.layer.borderWidth = 2
        trimHighlightView.layer.cornerRadius = 4
        trimTimelineView.addSubview(trimHighlightView)
        
        // Add pan gesture recognizers
        let leftPan = UIPanGestureRecognizer(target: self, action: #selector(handleTrimPan(_:)))
        let rightPan = UIPanGestureRecognizer(target: self, action: #selector(handleTrimPan(_:)))
        trimHandleLeft.addGestureRecognizer(leftPan)
        trimHandleRight.addGestureRecognizer(rightPan)
        
        // Initial layout
        layoutTrimHandles()
    }
    
    @objc private func handleTrimPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: trimTimelineView)
        let totalWidth = trimThumbnailsStackView.bounds.width
        let handleWidth: CGFloat = 16
        let minHandleDistance: CGFloat = 20
        let handleSpacing: CGFloat = 8
        
        if gesture.view === trimHandleLeft {
            switch gesture.state {
            case .began:
                isDraggingLeft = true
                panStartX = trimHandleLeft.frame.origin.x
            case .changed:
                let newX = panStartX + translation.x
                let minX = trimThumbnailsStackView.frame.minX
                let maxX = trimHandleRight.frame.origin.x - minHandleDistance
                
                // Update handle position
                let clampedX = min(max(newX, minX), maxX)
                trimHandleLeft.frame = CGRect(x: clampedX,
                                            y: trimThumbnailsStackView.frame.minY,
                                            width: handleWidth,
                                            height: 60)
                
                // Update trim time
                let percent = (clampedX - trimThumbnailsStackView.frame.minX) / totalWidth
                trimStartTime = Float(percent) * videoDuration
                
                // Update highlight view
                updateTrimHighlight()
                updatePreviewTrim()
            case .ended, .cancelled:
                isDraggingLeft = false
                applyTrim()
            default:
                break
            }
        } else if gesture.view === trimHandleRight {
            switch gesture.state {
            case .began:
                isDraggingRight = true
                panStartX = trimHandleRight.frame.origin.x
            case .changed:
                let newX = panStartX + translation.x
                let minX = trimHandleLeft.frame.origin.x + minHandleDistance
                let maxX = trimThumbnailsStackView.frame.maxX - handleWidth
                
                // Update handle position
                let clampedX = min(max(newX, minX), maxX)
                trimHandleRight.frame = CGRect(x: clampedX,
                                             y: trimThumbnailsStackView.frame.minY,
                                             width: handleWidth,
                                             height: 60)
                
                // Update trim time
                let percent = (clampedX - trimThumbnailsStackView.frame.minX) / (totalWidth - handleSpacing)
                trimEndTime = Float(percent) * videoDuration
                
                // Update highlight view
                updateTrimHighlight()
                updatePreviewTrim()
            case .ended, .cancelled:
                isDraggingRight = false
                applyTrim()
            default:
                break
            }
        }
    }
    
    private func updatePreviewTrim() {
        guard let player = player, let url = videoURL else { return }
        let wasPlaying = player.timeControlStatus == .playing
        let currentTime = player.currentTime()
        
        // Calculate the relative position within the trim range
        let trimDuration = trimEndTime - trimStartTime
        let relativePosition = (currentTime.seconds - Double(trimStartTime)) / Double(trimDuration)
        
        // Update player with new trim range
        setupPlayer(with: url, filterName: selectedCIFilterName)
        
        // Restore playback position and state
        if wasPlaying {
            player.play()
        }
        
        // Seek to the relative position in the new trim range
        let newTime = CMTime(seconds: Double(trimStartTime) + (Double(trimDuration) * relativePosition), preferredTimescale: 600)
        player.seek(to: newTime)
    }
    
    private func layoutTrimHandles() {
        guard videoDuration > 0 else { return }
        
        let handleWidth: CGFloat = 16
        let handleHeight: CGFloat = 60
        let handleSpacing: CGFloat = 8
        
        // Calculate positions based on trim times
        let totalWidth = trimThumbnailsStackView.bounds.width
        let leftX = (CGFloat(trimStartTime / videoDuration) * totalWidth) + trimThumbnailsStackView.frame.minX
        let rightX = (CGFloat(trimEndTime / videoDuration) * totalWidth) + trimThumbnailsStackView.frame.minX
        
        // Ensure minimum distance between handles
        let minHandleDistance: CGFloat = 20
        let adjustedRightX = max(rightX, leftX + minHandleDistance)
        
        // Update handle frames
        trimHandleLeft.frame = CGRect(x: leftX,
                                    y: trimThumbnailsStackView.frame.minY,
                                    width: handleWidth,
                                    height: handleHeight)
        
        trimHandleRight.frame = CGRect(x: adjustedRightX - handleWidth,
                                     y: trimThumbnailsStackView.frame.minY,
                                     width: handleWidth,
                                     height: handleHeight)
        
        // Update highlight view
        updateTrimHighlight()
    }
    
    private func updateTrimHandlesForVideoDuration() {
        // Ensure we're on the main thread for UI updates
        DispatchQueue.main.async {
            // Reset trim times
            self.trimStartTime = 0
            self.trimEndTime = self.videoDuration
            
            // Update handle positions
            self.layoutTrimHandles()
            
            // Make sure handles are visible
            self.trimHandleLeft.isHidden = false
            self.trimHandleRight.isHidden = false
            self.trimHighlightView.isHidden = false
        }
    }
    
    private func applyTrim() {
        guard !isTrimming, let url = videoURL else { return }
        isTrimming = true
        
        let asset = AVAsset(url: url)
        let composition = AVMutableComposition()
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let audioTrack = asset.tracks(withMediaType: .audio).first,
              let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            isTrimming = false
            return
        }
        
        let startTime = CMTime(seconds: Double(trimStartTime), preferredTimescale: 600)
        let endTime = CMTime(seconds: Double(trimEndTime), preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startTime, end: endTime)
        
        try? compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
        try? compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        
        // Export trimmed video
        let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("trimmed_video.mp4")
        
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .mp4
        
        exportSession?.exportAsynchronously { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if exportSession?.status == .completed {
                    self.videoURL = outputURL
                    self.setupPlayer(with: outputURL, filterName: self.selectedCIFilterName)
                }
                self.isTrimming = false
            }
        }
    }
    
    private func updateTrimHighlight() {
        let leftX = trimHandleLeft.frame.origin.x + trimHandleLeft.frame.width // Start after red handle
        let rightX = trimHandleRight.frame.origin.x // End at yellow handle
        
        // Ensure highlight view stays within bounds
        let minX = trimThumbnailsStackView.frame.minX
        let maxX = trimThumbnailsStackView.frame.maxX
        let adjustedLeftX = max(minX, min(leftX, maxX))
        let adjustedRightX = max(minX, min(rightX, maxX))
        
        trimHighlightView.frame = CGRect(x: adjustedLeftX,
                                       y: trimThumbnailsStackView.frame.minY,
                                       width: adjustedRightX - adjustedLeftX,
                                       height: 60)
    }
}
