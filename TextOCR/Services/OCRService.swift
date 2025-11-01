//
//  OCRService.swift
//  TextOCR
//
//  Service for performing OCR text recognition using Apple Vision Framework
//

import AppKit
import Vision

class OCRService {

    /// Extracts text from an image using Vision Framework
    /// - Parameter image: The NSImage to perform OCR on
    /// - Returns: Recognized text as a String, or empty string if no text found
    func extractText(from image: NSImage) -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("[OCRService] Failed to convert NSImage to CGImage")
            return ""
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        var recognizedText = ""

        // Create Vision text recognition request
        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                print("[OCRService] Error recognizing text: \(error.localizedDescription)")
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("[OCRService] No text observations found")
                return
            }

            // Extract text from all observations
            let textLines = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            recognizedText = textLines.joined(separator: "\n")
        }

        // Configure request for fast recognition
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // Perform the request
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try requestHandler.perform([request])
        } catch {
            print("[OCRService] Failed to perform text recognition: \(error.localizedDescription)")
            return ""
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("[OCRService] OCR completed in \(String(format: "%.3f", timeElapsed))s")
        print("[OCRService] Recognized text length: \(recognizedText.count) characters")

        return recognizedText
    }
}
