//
//  ImagePreprocessor.swift
//  GoTrailIOS
//
//  Created by Harvey Tan on 4/26/26.
//

import CoreGraphics
import Accelerate
#if canImport(UIKit)
import UIKit
#endif

/// Converts a CGImage into a normalized float array matching EfficientNet-B0 / ImageNet preprocessing.
/// Output shape: [1, 3, 224, 224] flattened to [Float] with 150,528 elements.
struct ImagePreprocessor {
    
    // ImageNet normalization constants (same values used during PlantNet-300K training)
    private static let mean: [Float] = [0.485, 0.456, 0.406]  // R, G, B
    private static let std: [Float]  = [0.229, 0.224, 0.225]   // R, G, B
    private static let inputSize = 224
    
    /// Main entry point: CGImage in → normalized [Float] out, ready for ZETIC tensor.
    /// Returns nil if the image can't be processed.
    static func preprocess(_ image: CGImage) -> [Float]? {
        guard let centerCrop = crop(image, mode: .center),
              let pixelData = extractPixelData(from: centerCrop)
        else { return nil }
        return pixelsToNormalizedCHW(pixelData, width: inputSize, height: inputSize)
    }

#if canImport(UIKit)
    /// Main UIKit entry point: safely normalizes orientation before preprocessing.
    static func preprocess(_ image: UIImage) -> [Float]? {
        guard let upright = normalizedCGImage(from: image) else { return nil }
        return preprocess(upright)
    }
#endif

    /// Test-time augmentation for higher accuracy: 5-crop inference inputs.
    /// Returns center + four corner crops.
    static func preprocessMultiCrop(_ image: CGImage) -> [[Float]] {
        let modes: [CropMode] = [.center, .topLeft, .topRight, .bottomLeft, .bottomRight]
        return modes.compactMap { mode in
            guard let cropped = crop(image, mode: mode),
                  let pixelData = extractPixelData(from: cropped)
            else { return nil }
            return pixelsToNormalizedCHW(pixelData, width: inputSize, height: inputSize)
        }
    }

#if canImport(UIKit)
    /// UIKit equivalent of multi-crop preprocessing.
    static func preprocessMultiCrop(_ image: UIImage) -> [[Float]] {
        guard let upright = normalizedCGImage(from: image) else { return [] }
        return preprocessMultiCrop(upright)
    }
#endif

    private enum CropMode {
        case center
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    private static func crop(_ image: CGImage, mode: CropMode) -> CGImage? {
        let resized = resizeToShortEdge(image, targetShortEdge: 256)
        return cropFromResizedImage(resized, size: inputSize, mode: mode)
    }
    
    // MARK: - Step 1: Resize
    
    /// Resizes image so the shorter edge = targetShortEdge, preserving aspect ratio.
    /// This matches torchvision.transforms.Resize(256).
    private static func resizeToShortEdge(_ image: CGImage, targetShortEdge: Int) -> CGImage {
        let w = image.width
        let h = image.height
        let shortEdge = min(w, h)
        let scale = Float(targetShortEdge) / Float(shortEdge)
        let newW = Int(Float(w) * scale)
        let newH = Int(Float(h) * scale)
        
        let context = CGContext(
            data: nil,
            width: newW,
            height: newH,
            bitsPerComponent: 8,
            bytesPerRow: newW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        
        return context.makeImage()!
    }
    
    // MARK: - Step 2: Center Crop
    
    /// Crops a 224×224 region according to the selected crop mode.
    private static func cropFromResizedImage(_ image: CGImage, size: Int, mode: CropMode) -> CGImage? {
        guard image.width >= size, image.height >= size else { return nil }

        let maxX = image.width - size
        let maxY = image.height - size
        let x: Int
        let y: Int

        switch mode {
        case .center:
            x = maxX / 2
            y = maxY / 2
        case .topLeft:
            x = 0
            y = 0
        case .topRight:
            x = maxX
            y = 0
        case .bottomLeft:
            x = 0
            y = maxY
        case .bottomRight:
            x = maxX
            y = maxY
        }

        let cropRect = CGRect(x: x, y: y, width: size, height: size)
        return image.cropping(to: cropRect)
    }
    
    // MARK: - Step 3: Extract Pixel Data
    
    /// Renders the image into a known RGBA pixel buffer.
    private static func extractPixelData(from image: CGImage) -> [UInt8]? {
        let w = image.width
        let h = image.height
        let bytesPerRow = w * 4
        var pixelData = [UInt8](repeating: 0, count: h * bytesPerRow)
        
        guard let context = CGContext(
            data: &pixelData,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return nil }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return pixelData
    }
    
    // MARK: - Step 4: Normalize & Rearrange to CHW
    
    /// Converts RGBA [UInt8] pixels → CHW [Float] with ImageNet normalization.
    ///
    /// PyTorch models expect Channel-first layout: [R_all_pixels, G_all_pixels, B_all_pixels]
    /// NOT the interleaved RGBARGBA... that CGContext gives us.
    ///
    /// Formula per pixel channel: (pixel / 255.0 - mean) / std
    private static func pixelsToNormalizedCHW(_ pixels: [UInt8], width: Int, height: Int) -> [Float] {
        let pixelCount = width * height
        // Output: 3 channels × 224 × 224 = 150,528 floats
        var result = [Float](repeating: 0, count: 3 * pixelCount)
        
        for i in 0..<pixelCount {
            let baseIndex = i * 4  // RGBA stride
            
            // Red channel → first 224×224 block
            let r = Float(pixels[baseIndex]) / 255.0
            result[i] = (r - mean[0]) / std[0]
            
            // Green channel → second 224×224 block
            let g = Float(pixels[baseIndex + 1]) / 255.0
            result[pixelCount + i] = (g - mean[1]) / std[1]
            
            // Blue channel → third 224×224 block
            let b = Float(pixels[baseIndex + 2]) / 255.0
            result[2 * pixelCount + i] = (b - mean[2]) / std[2]
        }
        
        return result
    }

#if canImport(UIKit)
    private static func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }

        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: rendererFormat)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return rendered.cgImage
    }
#endif
}
