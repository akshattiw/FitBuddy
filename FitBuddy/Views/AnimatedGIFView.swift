import SwiftUI
import ImageIO
#if canImport(UIKit)
import UIKit

/// A high-performance, lightweight native GIF rendering component for SwiftUI.
/// Decodes multi-frame GIF assets using `ImageIO` and drives smooth, transparent,
/// looping animation via `UIImageView` without third-party dependencies.
public struct AnimatedGIFView: UIViewRepresentable {
    public let name: String
    public let bundle: Bundle
    public let contentMode: UIView.ContentMode
    
    public init(
        name: String,
        bundle: Bundle = .main,
        contentMode: UIView.ContentMode = .scaleAspectFit
    ) {
        self.name = name
        self.bundle = bundle
        self.contentMode = contentMode
    }
    
    public func makeUIView(context: Context) -> GIFPlayerView {
        let view = GIFPlayerView()
        view.contentMode = contentMode
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.loadGIF(name: name, bundle: bundle)
        return view
    }
    
    public func updateUIView(_ uiView: GIFPlayerView, context: Context) {
        uiView.contentMode = contentMode
        if uiView.currentName != name {
            uiView.loadGIF(name: name, bundle: bundle)
        } else if !uiView.isAnimating, let count = uiView.animationImages?.count, count > 1 {
            uiView.startAnimating()
        }
    }
}

// MARK: - Native GIF Player UIView

public final class GIFPlayerView: UIImageView {
    public private(set) var currentName: String?
    
    public init() {
        super.init(frame: .zero)
        setupDefaults()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupDefaults()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDefaults()
    }
    
    private func setupDefaults() {
        backgroundColor = .clear
        clipsToBounds = true
        contentMode = .scaleAspectFit
    }
    
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            if !isAnimating, let count = animationImages?.count, count > 1 {
                startAnimating()
            }
        }
    }
    
    /// Loads GIF data from bundle resources, data assets, or fallback locations.
    public func loadGIF(name: String, bundle: Bundle = .main) {
        self.currentName = name
        
        // Check in-memory decoded cache first
        if let cached = GIFImageDecoder.shared.cachedDecodedGIF(forName: name) {
            applyDecodedGIF(cached)
            return
        }
        
        // 1. Try finding resource URL in bundle
        let cleanName = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension.isEmpty ? "gif" : (name as NSString).pathExtension
        
        var targetData: Data? = nil
        
        if let url = bundle.url(forResource: cleanName, withExtension: ext) ??
                     bundle.url(forResource: name, withExtension: nil) ??
                     bundle.url(forResource: cleanName, withExtension: ext, subdirectory: "Resources") ??
                     bundle.url(forResource: cleanName, withExtension: ext, subdirectory: "DesignReferences") {
            targetData = try? Data(contentsOf: url)
        }
        
        // 2. Try NSDataAsset if packaged in xcassets
        if targetData == nil {
            if let dataAsset = NSDataAsset(name: cleanName, bundle: bundle) {
                targetData = dataAsset.data
            }
        }
        
        guard let data = targetData else {
            #if DEBUG
            print("[AnimatedGIFView] Unable to locate GIF resource '\(name)' in bundle: \(bundle.bundlePath)")
            #endif
            return
        }
        
        if let decoded = GIFImageDecoder.shared.decodeGIF(data: data, cacheKey: name) {
            applyDecodedGIF(decoded)
        }
    }
    
    private func applyDecodedGIF(_ decoded: DecodedGIF) {
        self.animationImages = decoded.frames
        self.animationDuration = decoded.duration
        self.animationRepeatCount = 0 // loop indefinitely
        self.image = decoded.frames.first
        self.startAnimating()
    }
}

// MARK: - Decoded GIF & Thread-Safe Cache

public struct DecodedGIF {
    public let frames: [UIImage]
    public let duration: TimeInterval
}

public final class GIFImageDecoder {
    public static let shared = GIFImageDecoder()
    private let cache = NSCache<NSString, DecodedGIFWrapper>()
    
    private final class DecodedGIFWrapper {
        let value: DecodedGIF
        init(value: DecodedGIF) { self.value = value }
    }
    
    private init() {
        cache.countLimit = 10
    }
    
    public func cachedDecodedGIF(forName name: String) -> DecodedGIF? {
        cache.object(forKey: name as NSString)?.value
    }
    
    public func decodeGIF(data: Data, cacheKey: String? = nil) -> DecodedGIF? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        
        var frames: [UIImage] = []
        var totalDuration: TimeInterval = 0
        
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                frames.append(UIImage(cgImage: cgImage))
            }
            
            var frameDuration: TimeInterval = 0.1
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
               let gifInfo = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                if let unclamped = parseDuration(from: gifInfo[kCGImagePropertyGIFUnclampedDelayTime]), unclamped > 0 {
                    frameDuration = unclamped
                } else if let delay = parseDuration(from: gifInfo[kCGImagePropertyGIFDelayTime]), delay > 0 {
                    frameDuration = delay
                }
            }
            
            // Standard WebKit / Apple GIF frame minimum duration safeguard
            if frameDuration <= 0.02 {
                frameDuration = 0.1
            }
            totalDuration += frameDuration
        }
        
        if totalDuration <= 0 {
            totalDuration = Double(count) * 0.1
        }
        
        let decoded = DecodedGIF(frames: frames, duration: totalDuration)
        if let key = cacheKey {
            cache.setObject(DecodedGIFWrapper(value: decoded), forKey: key as NSString)
        }
        return decoded
    }
    
    private func parseDuration(from value: Any?) -> TimeInterval? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String, let doubleVal = Double(string) {
            return doubleVal
        }
        return nil
    }
}
#elseif canImport(AppKit)
import AppKit

public struct AnimatedGIFView: View {
    public let name: String
    public let bundle: Bundle
    
    public init(name: String, bundle: Bundle = .main) {
        self.name = name
        self.bundle = bundle
    }
    
    public var body: some View {
        Image(systemName: "figure.run")
            .resizable()
            .scaledToFit()
    }
}
#endif
