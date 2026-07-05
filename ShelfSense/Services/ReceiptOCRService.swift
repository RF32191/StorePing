//
//  ReceiptOCRService.swift
//  ShelfSense
//

import Foundation
import Vision
import UIKit
import CoreImage

enum ReceiptOCRService {
    static func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { observation -> String? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return candidate.string
                }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.012
            request.recognitionLanguages = ["en-US"]
            request.customWords = [
                "SUBTOTAL", "TOTAL", "TAX", "SAVINGS", "DISCOUNT", "COSTCO", "WALMART",
                "TARGET", "CVS", "KROGER", "WHOLE", "FOODS", "RECEIPT", "MC DONALD"
            ]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    static func preprocess(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: nil)

        var output = ciImage
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(1.1, forKey: kCIInputContrastKey)
            filter.setValue(0.02, forKey: kCIInputBrightnessKey)
            output = filter.outputImage ?? output
        }

        if let filter = CIFilter(name: "CIUnsharpMask") {
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(1.5, forKey: kCIInputRadiusKey)
            filter.setValue(0.6, forKey: kCIInputIntensityKey)
            output = filter.outputImage ?? output
        }

        guard let processed = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: processed, scale: image.scale, orientation: image.imageOrientation)
    }

    enum OCRError: LocalizedError {
        case invalidImage

        var errorDescription: String? {
            switch self {
            case .invalidImage: "Could not read the selected image."
            }
        }
    }
}
