import Combine
import Foundation

final class PhotoAnalysisViewModel: ObservableObject {
    @Published private(set) var classificationResult: ClassificationResult?
    @Published private(set) var isClassifying: Bool

    init(classificationResult: ClassificationResult?, isClassifying: Bool) {
        self.classificationResult = classificationResult
        self.isClassifying = isClassifying
    }

    var speciesName: String {
        classificationResult?.speciesName ?? "Analyzing..."
    }

    var confidenceLabel: String {
        classificationResult?.confidenceLabel ?? "Running plant identification..."
    }

    var confidencePercent: String {
        classificationResult?.confidencePercent ?? "--"
    }

    var speciesIdText: String? {
        guard let speciesId = classificationResult?.speciesId else { return nil }
        return "Species ID: \(speciesId)"
    }

    var topPredictions: [ClassificationResult.Prediction] {
        classificationResult?.topPredictions ?? []
    }
}
