//import UIKit
//import AVFoundation
//
//protocol TrimTimelineViewDelegate: AnyObject {
//    func trimTimelineView(_ view: TrimTimelineView, didChangeTrimRange start: Float, end: Float)
//}
//
//class TrimTimelineView: UIView {
//    weak var delegate: TrimTimelineViewDelegate?
//    var videoURL: URL? {
//        didSet { generateThumbnails() }
//    }
//    private(set) var trimStart: Float = 0
//    private(set) var trimEnd: Float = 0
//    private var videoDuration: Float = 0
//    private let scrollView = UIScrollView()
//    private let thumbnailsStack = UIStackView()
//    private let leftHandle = UIView()
//    private let rightHandle = UIView()
//    private let highlightView = UIView()
//    private var thumbnailCount = 10
//    private var thumbnailWidth: CGFloat = 40
//    private var handleWidth: CGFloat = 16
//    private var panStartX: CGFloat = 0
//    private var isDraggingLeft = false
//    private var isDraggingRight = false
//
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        setupUI()
//    }
//    required init?(coder: NSCoder) {
//        super.init(coder: coder)
//        setupUI()
//    }
//
//    private func setupUI() {
//        scrollView.showsHorizontalScrollIndicator = false
//        scrollView.translatesAutoresizingMaskIntoConstraints = false
//        addSubview(scrollView)
//        thumbnailsStack.axis = .horizontal
//        thumbnailsStack.spacing = 0
//        thumbnailsStack.translatesAutoresizingMaskIntoConstraints = false
//        scrollView.addSubview(thumbnailsStack)
//        highlightView.backgroundColor = UIColor.green.withAlphaComponent(0.2)
//        highlightView.layer.borderColor = UIColor.green.cgColor
//        highlightView.layer.borderWidth = 2
//        highlightView.layer.cornerRadius = 8
//        highlightView.isUserInteractionEnabled = false
//        scrollView.addSubview(highlightView)
//        leftHandle.backgroundColor = .green
//        leftHandle.layer.cornerRadius = 4
//        leftHandle.translatesAutoresizingMaskIntoConstraints = false
//        leftHandle.frame = CGRect(x: 0, y: 0, width: handleWidth, height: 60)
//        leftHandle.isUserInteractionEnabled = true
//        scrollView.addSubview(leftHandle)
//        rightHandle.backgroundColor = .green
//        rightHandle.layer.cornerRadius = 4
//        rightHandle.translatesAutoresizingMaskIntoConstraints = false
//        rightHandle.frame = CGRect(x: 0, y: 0, width: handleWidth, height: 60)
//        rightHandle.isUserInteractionEnabled = true
//        scrollView.addSubview(rightHandle)
//        let leftPan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
//        leftHandle.addGestureRecognizer(leftPan)
//        let rightPan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
//        rightHandle.addGestureRecognizer(rightPan)
//        NSLayoutConstraint.activate([
//            scrollView.topAnchor.constraint(equalTo: topAnchor),
//            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
//            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
//            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
//            thumbnailsStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
//            thumbnailsStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
//            thumbnailsStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 0),
//            thumbnailsStack.heightAnchor.constraint(equalToConstant: 60)
//        ])
//    }
//
//    private func generateThumbnails() {
//        thumbnailsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
//        guard let url = videoURL else { return }
//        let asset = AVAsset(url: url)
//        videoDuration = Float(CMTimeGetSeconds(asset.duration))
//        trimStart = 0
//        trimEnd = videoDuration
//        let generator = AVAssetImageGenerator(asset: asset)
//        generator.appliesPreferredTrackTransform = true
//        let times: [NSValue] = (0..<thumbnailCount).map {
//            let seconds = Double($0) * Double(videoDuration) / Double(thumbnailCount)
//            return NSValue(time: CMTime(seconds: seconds, preferredTimescale: 600))
//        }
//        DispatchQueue.global(qos: .userInitiated).async {
//            var images: [UIImage] = []
//            for time in times {
//                do {
//                    let cgImage = try generator.copyCGImage(at: time.timeValue, actualTime: nil)
//                    images.append(UIImage(cgImage: cgImage))
//                } catch {
//                    images.append(UIImage())
//                }
//            }
//            DispatchQueue.main.async {
//                for img in images {
//                    let iv = UIImageView(image: img)
//                    iv.contentMode = .scaleAspectFill
//                    iv.clipsToBounds = true
//                    iv.widthAnchor.constraint(equalToConstant: self.thumbnailWidth).isActive = true
//                    iv.heightAnchor.constraint(equalToConstant: 60).isActive = true
//                    self.thumbnailsStack.addArrangedSubview(iv)
//                }
//                self.layoutHandlesAndHighlight()
//            }
//        }
//    }
//
//    private func layoutHandlesAndHighlight() {
//        let totalWidth = CGFloat(thumbnailCount) * thumbnailWidth
//        let leftX = positionForTime(trimStart)
//        let rightX = positionForTime(trimEnd)
//        leftHandle.frame = CGRect(x: leftX - handleWidth/2, y: 10, width: handleWidth, height: 80)
//        rightHandle.frame = CGRect(x: rightX - handleWidth/2, y: 10, width: handleWidth, height: 80)
//        highlightView.frame = CGRect(x: leftX, y: 20, width: rightX - leftX, height: 60)
//    }
//
//    private func positionForTime(_ time: Float) -> CGFloat {
//        guard videoDuration > 0 else { return 0 }
//        let percent = CGFloat(time / videoDuration)
//        let totalWidth = CGFloat(thumbnailCount) * thumbnailWidth
//        return percent * totalWidth
//    }
//
//    private func timeForPosition(_ x: CGFloat) -> Float {
//        let totalWidth = CGFloat(thumbnailCount) * thumbnailWidth
//        let percent = min(max(x / totalWidth, 0), 1)
//        return Float(percent) * videoDuration
//    }
//
//    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
//        guard videoDuration > 0 else { return }
//        let translation = gesture.translation(in: scrollView)
//        if gesture.view === leftHandle {
//            switch gesture.state {
//            case .began:
//                isDraggingLeft = true
//                panStartX = leftHandle.center.x
//            case .changed:
//                var newX = panStartX + translation.x
//                let minX: CGFloat = 0
//                let maxX: CGFloat = rightHandle.center.x - handleWidth
//                newX = min(max(newX, minX), maxX)
//                leftHandle.center.x = newX
//                trimStart = timeForPosition(leftHandle.center.x - handleWidth/2)
//                layoutHandlesAndHighlight()
//                delegate?.trimTimelineView(self, didChangeTrimRange: trimStart, end: trimEnd)
//            case .ended, .cancelled:
//                isDraggingLeft = false
//            default: break
//            }
//        } else if gesture.view === rightHandle {
//            switch gesture.state {
//            case .began:
//                isDraggingRight = true
//                panStartX = rightHandle.center.x
//            case .changed:
//                let totalWidth = CGFloat(thumbnailCount) * thumbnailWidth
//                var newX = panStartX + translation.x
//                let minX: CGFloat = leftHandle.center.x + handleWidth
//                let maxX: CGFloat = totalWidth
//                newX = min(max(newX, minX), maxX)
//                rightHandle.center.x = newX
//                trimEnd = timeForPosition(rightHandle.center.x - handleWidth/2)
//                layoutHandlesAndHighlight()
//                delegate?.trimTimelineView(self, didChangeTrimRange: trimStart, end: trimEnd)
//            case .ended, .cancelled:
//                isDraggingRight = false
//            default: break
//            }
//        }
//    }
//
//    // Public API
//    func setTrimRange(start: Float, end: Float) {
//        trimStart = max(0, min(start, videoDuration))
//        trimEnd = max(trimStart, min(end, videoDuration))
//        layoutHandlesAndHighlight()
//    }
//} 
