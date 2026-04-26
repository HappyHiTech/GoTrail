//
//  PlantClassifier.swift
//  GoTrailIOS
//
//  Created by Harvey Tan on 4/26/26.
//

import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

@Observable
class PlantClassifier {

    static let shared = PlantClassifier()

    var isModelReady: Bool { MLangeManager.shared.isModelReady }
    var isClassifying: Bool { MLangeManager.shared.isClassifying }
    var downloadProgress: Float { MLangeManager.shared.downloadProgress }
    var errorMessage: String? { MLangeManager.shared.errorMessage }

    private let topK = 5
    private let minReliableConfidence: Float = 0.45
    private let minTop1Top2Margin: Float = 0.12
    private let inferenceQueue = DispatchQueue(label: "com.gotrail.plantclassifier.inference", qos: .userInitiated)

    private init() {}

    // MARK: - Load

    func loadModel() async {
        await MLangeManager.shared.loadModel()
    }

    // MARK: - Classify

    func classify(image: CGImage) async -> ClassificationResult? {
        await classifyOnInferenceQueue {
            ImagePreprocessor.preprocessMultiCrop(image)
        }
    }

#if canImport(UIKit)
    func classify(image: UIImage) async -> ClassificationResult? {
        await classifyOnInferenceQueue {
            ImagePreprocessor.preprocessMultiCrop(image)
        }
    }
#endif

    private func classifyOnInferenceQueue(_ cropsBuilder: @escaping () -> [[Float]]) async -> ClassificationResult? {
        await withCheckedContinuation { continuation in
            inferenceQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                let crops = cropsBuilder()
                Task {
                    let result = await self.classifyPreprocessedCrops(crops)
                    continuation.resume(returning: result)
                }
            }
        }
    }

    private func classifyPreprocessedCrops(_ crops: [[Float]]) async -> ClassificationResult? {
        // Step 1: Build multi-crop inputs for stronger inference robustness.
        guard crops.isEmpty == false else {
            print("Image preprocessing failed")
            return nil
        }

        // Step 2: Run inference per crop and average logits.
        var cropLogits: [[Float]] = []
        for crop in crops {
            guard let logits = await MLangeManager.shared.runInference(preprocessedData: crop) else {
                continue
            }
            cropLogits.append(logits)
        }

        guard cropLogits.isEmpty == false else {
            print("Model inference failed for all crops")
            return nil
        }

        let averagedLogits = averageLogits(cropLogits)

        // Step 3: Convert averaged logits -> probabilities via softmax
        let probabilities = softmax(averagedLogits)

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
        let secondBestConfidence = topPredictions.dropFirst().first?.confidence ?? 0
        let top1Top2Margin = best.confidence - secondBestConfidence
        let isReliable = best.confidence >= minReliableConfidence && top1Top2Margin >= minTop1Top2Margin

        let result = ClassificationResult(
            speciesName: isReliable ? best.speciesName : "Uncertain plant match",
            confidence: best.confidence,
            speciesId: best.speciesId,
            topPredictions: topPredictions
        )

        print("Classification: \(result.speciesName) (\(result.confidencePercent), margin: \(top1Top2Margin))")

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

    private func averageLogits(_ logitsList: [[Float]]) -> [Float] {
        guard let first = logitsList.first else { return [] }
        var sum = [Float](repeating: 0, count: first.count)
        var count: Float = 0

        for logits in logitsList where logits.count == first.count {
            for i in 0..<logits.count {
                sum[i] += logits[i]
            }
            count += 1
        }

        guard count > 0 else { return [] }
        return sum.map { $0 / count }
    }
}
