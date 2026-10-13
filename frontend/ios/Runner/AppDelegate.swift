import Flutter
import UIKit
import AVFoundation
import CoreVideo

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let exportCancelLock = NSLock()
  private static var exportCancellations: [String: ExportCancellation] = [:]
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "com.formypet/pet_log_video_export", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      if call.method == "cancel" {
        let args = call.arguments as? [String: Any]
        let requestId = args?["requestId"] as? String
        Self.exportCancelLock.lock()
        let cancellation: ExportCancellation? = requestId.map { id in
          if let existing = Self.exportCancellations[id] { return existing }
          let pending = ExportCancellation()
          Self.exportCancellations[id] = pending
          return pending
        }
        Self.exportCancelLock.unlock()
        cancellation?.cancel()
        result(nil)
        return
      }
      guard call.method == "create",
            let args = call.arguments as? [String: Any],
            let paths = args["imagePaths"] as? [String],
            !paths.isEmpty,
            let requestId = args["requestId"] as? String,
            let output = args["outputPath"] as? String else {
        result(FlutterError(code: "invalid_args", message: "Photos and output path are required", details: nil))
        return
      }
      let cancellation = ExportCancellation()
      Self.exportCancelLock.lock()
      let actualCancellation = Self.exportCancellations[requestId] ?? cancellation
      Self.exportCancellations[requestId] = actualCancellation
      Self.exportCancelLock.unlock()
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          try Self.encodePetLogVideo(paths: paths, output: output, cancellation: actualCancellation)
          DispatchQueue.main.async {
            result(output)
            Self.exportCancelLock.lock(); Self.exportCancellations.removeValue(forKey: requestId); Self.exportCancelLock.unlock()
          }
        } catch {
          try? FileManager.default.removeItem(atPath: output)
          DispatchQueue.main.async {
            result(FlutterError(code: "encode_failed", message: error.localizedDescription, details: nil))
            Self.exportCancelLock.lock(); Self.exportCancellations.removeValue(forKey: requestId); Self.exportCancelLock.unlock()
          }
        }
      }
    }
  }

  private static func encodePetLogVideo(paths: [String], output: String, cancellation: ExportCancellation) throws {
    guard let first = UIImage(contentsOfFile: paths[0]), let firstCG = first.cgImage else { throw NSError(domain: "PetLogVideo", code: 1) }
    let sourceWidth = Double(firstCG.width)
    let sourceHeight = Double(firstCG.height)
    let maxPixels = 2_073_600.0
    let scale = min(1.0, min(1080.0 / sourceWidth, min(1920.0 / sourceHeight, sqrt(maxPixels / (sourceWidth * sourceHeight)))) )
    let width = max(2, Int(sourceWidth * scale) & ~1)
    let height = max(2, Int(sourceHeight * scale) & ~1)
    let outputURL = URL(fileURLWithPath: output)
    try? FileManager.default.removeItem(at: outputURL)
    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    defer { if writer.status == .writing { writer.cancelWriting() } }
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height, kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
    guard writer.canAdd(input) else { throw NSError(domain: "PetLogVideo", code: 2) }
    writer.add(input)
    guard writer.startWriting() else { throw writer.error ?? NSError(domain: "PetLogVideo", code: 3) }
    writer.startSession(atSourceTime: .zero)
    let frameDuration = CMTime(value: 1, timescale: 10)
    var frame = 0
    for path in paths {
      if cancellation.isCancelled { throw NSError(domain: "PetLogVideo", code: 10, userInfo: [NSLocalizedDescriptionKey: "Video export cancelled"]) }
      guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else { throw NSError(domain: "PetLogVideo", code: 4) }
      for _ in 0..<30 {
        if cancellation.isCancelled { throw NSError(domain: "PetLogVideo", code: 10, userInfo: [NSLocalizedDescriptionKey: "Video export cancelled"]) }
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005); if cancellation.isCancelled { throw NSError(domain: "PetLogVideo", code: 10, userInfo: [NSLocalizedDescriptionKey: "Video export cancelled"]) }; if writer.status == .failed { throw writer.error ?? NSError(domain: "PetLogVideo", code: 5) } }
        var pixel: CVPixelBuffer?
        guard let pool = adaptor.pixelBufferPool, CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixel) == kCVReturnSuccess, let buffer = pixel else { throw NSError(domain: "PetLogVideo", code: 6) }
        CVPixelBufferLockBaseAddress(buffer, [])
        guard let base = CVPixelBufferGetBaseAddress(buffer), let context = CGContext(data: base, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { CVPixelBufferUnlockBaseAddress(buffer, []); throw NSError(domain: "PetLogVideo", code: 7) }
        context.setFillColor(UIColor.black.cgColor); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
        let scale = min(CGFloat(width) / CGFloat(cgImage.width), CGFloat(height) / CGFloat(cgImage.height))
        let w = CGFloat(cgImage.width) * scale, h = CGFloat(cgImage.height) * scale
        context.interpolationQuality = .high; context.draw(cgImage, in: CGRect(x: (CGFloat(width)-w)/2, y: (CGFloat(height)-h)/2, width: w, height: h))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard adaptor.append(buffer, withPresentationTime: CMTimeMultiply(frameDuration, multiplier: Int32(frame))) else { throw writer.error ?? NSError(domain: "PetLogVideo", code: 8) }
        frame += 1
      }
    }
    input.markAsFinished()
    let semaphore = DispatchSemaphore(value: 0); writer.finishWriting { semaphore.signal() }; semaphore.wait()
    guard writer.status == .completed else { throw writer.error ?? NSError(domain: "PetLogVideo", code: 9) }
  }

}

private final class ExportCancellation {
  private let lock = NSLock()
  private var cancelled = false
  var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
  func cancel() { lock.lock(); cancelled = true; lock.unlock() }
}
