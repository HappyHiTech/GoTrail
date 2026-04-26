//
//  MLangeManager.swift
//  GoTrailIOS
//
//  Created by Harvey Tan on 4/26/26.
//

import Foundation
import ZeticMLange

/// Manages the ZETIC MLange model lifecycle using the Tensor-based API.
/// Singleton pattern matching SupabaseManager and LocationManager.
@Observable
class MLangeManager {

    static let shared = MLangeManager()

    private let personalKey: String
    private let modelName   = "rlongacre/plantid_2"
    private let modelVersion = 2

    private var model: ZeticMLangeModel?

    var isModelReady = false
    var isClassifying = false
    var downloadProgress: Float = 0.0
    var errorMessage: String?

    private init() {
        let rawKey = (Bundle.main.object(forInfoDictionaryKey: "ZETIC_MLANGE_PERSONAL_KEY") as? String) ?? ""
        let trimmedKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedKey.isEmpty == false else {
            fatalError("Missing ZETIC_MLANGE_PERSONAL_KEY in Info.plist/xcconfig.")
        }
        self.personalKey = trimmedKey
    }

    // MARK: - Load Model

    func loadModel() async {
        guard model == nil else { return }

        do {
            let loadedModel = try ZeticMLangeModel(
                personalKey: personalKey,
                name: modelName,
                version: modelVersion,
                modelMode: ModelMode.RUN_AUTO,
                onDownload: { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadProgress = progress
                    }
                }
            )

            self.model = loadedModel

            await MainActor.run {
                self.isModelReady = true
                self.errorMessage = nil
            }

            print("✅ ZETIC MLange model loaded successfully")

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load ML model: \(error.localizedDescription)"
                self.isModelReady = false
            }
            print("❌ MLange model failed to load: \(error)")
        }
    }

    // MARK: - Run Inference (Tensor API)

    func runInference(preprocessedData: [Float]) async -> [Float]? {
        guard let model = model else {
            print("❌ Model not loaded — call loadModel() first")
            return nil
        }

        await MainActor.run { self.isClassifying = true }
        defer { Task { @MainActor in self.isClassifying = false } }

        do {
            let rawData = preprocessedData.withUnsafeBufferPointer { Data(buffer: $0) }
            let inputTensor = Tensor(data: rawData, dataType: BuiltinDataType.float32, shape: [1, 3, 224, 224])

            let outputs = try model.run(inputs: [inputTensor])

            guard let outputTensor = outputs.first else {
                print("❌ No output tensor from model")
                return nil
            }

            let outputFloats = DataUtils.dataToFloatArray(outputTensor.data)

            print("✅ Inference complete — \(outputFloats.count) output values")
            return outputFloats

        } catch {
            print("❌ Inference failed: \(error)")
            return nil
        }
    }
}
