//
//  PlantClassifier.swift
//  GoTrailIOS
//
//  Created by Harvey Tan on 4/26/26.
//

import Foundation
import CoreGraphics

@Observable
class PlantClassifier {

    static let shared = PlantClassifier()

    var isModelReady: Bool { MLangeManager.shared.isModelReady }
    var isClassifying: Bool { MLangeManager.shared.isClassifying }
    var downloadProgress: Float { MLangeManager.shared.downloadProgress }
    var errorMessage: String? { MLangeManager.shared.errorMessage }

    private let topK = 5

    private init() {}

    // MARK: - Load

    func loadModel() async {
        await MLangeManager.shared.loadModel()
    }

    // MARK: - Classify

    func classify(image: CGImage) async -> ClassificationResult? {

        // Step 1: Preprocess the image -> normalized float array
        guard let preprocessedData = ImagePreprocessor.preprocess(image) else {
            print("Image preprocessing failed")
            return nil
        }

        // Step 2: Run inference through ZETIC MLange
        guard let logits = await MLangeManager.shared.runInference(preprocessedData: preprocessedData) else {
            print("Model inference failed")
            return nil
        }

        // Step 3: Convert logits -> probabilities via softmax
        let probabilities = softmax(logits)

        // Step 4: Get the top-K predictions
        let topIndices = topKIndices(probabilities, k: topK)

        let mapper = PlantLabelMapper.shared

        let topPredictions: [ClassificationResult.Prediction] = topIndices.map { index in
            ClassificationResult.Prediction(
                classIndex: index,
                speciesName: mapper.getSpeciesName(for: index),
                speciesId: mapper.getSpeciesId(for: index),
                confidence: probabilities[index]
            )
        }

        // Step 5: Package the result
        guard let best = topPredictions.first else { return nil }

        let result = ClassificationResult(
            speciesName: best.speciesName,
            confidence: best.confidence,
            speciesId: best.speciesId,
            topPredictions: topPredictions
        )

        print("Classification: \(result.speciesName) (\(result.confidencePercent))")

        return result
    }

    // MARK: - Math Helpers

    // Softmax with numerical stability (subtract max to prevent overflow)
    private func softmax(_ logits: [Float]) -> [Float] {
        let maxLogit = logits.max() ?? 0
        let exps = logits.map { exp($0 - maxLogit) }
        let sumExps = exps.reduce(0, +)
        return exps.map { $0 / sumExps }
    }

    private func topKIndices(_ values: [Float], k: Int) -> [Int] {
        let indexed = values.enumerated().map { ($0.offset, $0.element) }
        let sorted = indexed.sorted { $0.1 > $1.1 }
        return Array(sorted.prefix(k).map { $0.0 })
    }
}
