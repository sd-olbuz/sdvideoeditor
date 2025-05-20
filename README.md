# SDVideoEditor

A powerful video editing library for iOS that provides a comprehensive set of features for video manipulation.

## Features

- Video trimming with visual timeline
- Speed control (0.25x to 2.0x)
- Multiple video filters
- Brightness, contrast, and saturation adjustments
- Face blur functionality
- Real-time preview
- Customizable UI

## Requirements

- iOS 13.0+
- Swift 5.0+
- Xcode 11.0+

## Installation

### CocoaPods

Add the following line to your Podfile:

```ruby
pod 'SDVideoEditor'
```

Then run:

```bash
pod install
```

## Usage

### Basic Setup

```swift
import SDVideoEditor

class YourViewController: UIViewController {
    private var videoEditor: VideoEditorViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize video editor
        videoEditor = VideoEditorViewController()
        
        // Set video URL
        if let videoURL = Bundle.main.url(forResource: "your_video", withExtension: "mp4") {
            videoEditor?.videoURL = videoURL
        }
        
        // Present video editor
        if let editor = videoEditor {
            present(editor, animated: true)
        }
    }
}
```

### Customization

```swift
// Customize tint color
videoEditor?.tintColor = .systemBlue

// Set initial video speed
videoEditor?.videoSpeed = 1.0
```

## Features in Detail

### Video Trimming
- Visual timeline with thumbnails
- Drag handles for precise trimming
- Real-time preview of trimmed section

### Speed Control
- Adjustable playback speed from 0.25x to 2.0x
- Real-time speed changes
- Smooth playback transitions

### Filters
- Multiple built-in filters
- Real-time filter preview
- Easy filter switching

### Adjustments
- Brightness control
- Contrast adjustment
- Saturation modification
- Real-time preview of adjustments

### Face Blur
- Automatic face detection
- Adjustable blur intensity
- Real-time blur preview

## License

SDVideoEditor is available under the MIT license. See the LICENSE file for more info. # sdvideoeditor
# sdvideoeditor
# sdvideoeditor
# sdvideoeditor
# sdvideoeditor
