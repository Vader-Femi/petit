import Cocoa
import FlutterMacOS
import ImageIO
import UniformTypeIdentifiers

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // The layout adapts down to phone widths, but not below this.
    self.contentMinSize = NSSize(width: 480, height: 480)

    RegisterGeneratedPlugins(registry: flutterViewController)
    ImageConverter.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// Converts an image to JPEG with the system's own decoders (ImageIO), which
/// read HEIC/HEIF. The Dart side is `MacosImageConverter`
/// (lib/features/images/data/services/macos_image_converter.dart).
private enum ImageConverter {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "petit/image_converter", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "convertToJpeg",
            let arguments = call.arguments as? [String: Any],
            let input = arguments["input"] as? String,
            let output = arguments["output"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      let quality = (arguments["quality"] as? Double) ?? 0.95

      // Decoding a large photo takes a moment: keep it off the main thread.
      DispatchQueue.global(qos: .userInitiated).async {
        let failure = convertToJpeg(input: input, output: output, quality: quality)
        DispatchQueue.main.async {
          if let failure = failure {
            result(FlutterError(code: "convert_failed", message: failure, details: nil))
          } else {
            result(output)
          }
        }
      }
    }
  }

  /// Returns an error message, or nil when the JPEG was written.
  private static func convertToJpeg(input: String, output: String, quality: Double) -> String? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: input) as CFURL, nil) else {
      return "Could not open the image."
    }
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int
    else {
      return "Could not read the image size."
    }

    // A thumbnail at the full size applies the image's orientation, so the
    // JPEG comes out upright.
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: max(width, height),
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      return "Could not decode the image."
    }

    guard let destination = CGImageDestinationCreateWithURL(
      URL(fileURLWithPath: output) as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else {
      return "Could not create the output file."
    }
    CGImageDestinationAddImage(
      destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      return "Could not write the JPEG."
    }
    return nil
  }
}
