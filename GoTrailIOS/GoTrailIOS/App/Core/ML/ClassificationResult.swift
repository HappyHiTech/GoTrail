//
//  lassificationResult.swift
//  GoTrailIOS
//
//  Created by Harvey Tan on 4/26/26.
//

import Foundation

/// The result of a plant classification, ready for UI display and database storage.
///
/// Maps to the Supabase `pictures` table:
///   - speciesName → `species` column
///   - JSON-encoded self → `species_info` column
struct ClassificationResult: Codable, Identifiable {
    let id: UUID
    
    /// The top predicted species name (e.g., "Lavandula angustifolia")
    let speciesName: String
    
    /// Confidence score for the top prediction (0.0 to 1.0)
    let confidence: Float
    
    /// PlantNet species ID (useful for lookups, stored in Supabase)
    let speciesId: String?
    
    /// Top-K predictions for showing alternatives to the user
    /// (e.g., "Did you mean one of these?")
    let topPredictions: [Prediction]
    
    /// When the classification was performed
    let classifiedAt: Date
    
    /// A single prediction entry (species + confidence)
    struct Prediction: Codable, Identifiable {
        let id: UUID
        let classIndex: Int
        let speciesName: String
        let speciesId: String?
        let confidence: Float
        
        init(classIndex: Int, speciesName: String, speciesId: String?, confidence: Float) {
            self.id = UUID()
            self.classIndex = classIndex
            self.speciesName = speciesName
            self.speciesId = speciesId
            self.confidence = confidence
        }
    }
    
    init(speciesName: String, confidence: Float, speciesId: String?, topPredictions: [Prediction]) {
        self.id = UUID()
        self.speciesName = speciesName
        self.confidence = confidence
        self.speciesId = speciesId
        self.topPredictions = topPredictions
        self.classifiedAt = Date()
    }
    
    // MARK: - Convenience
    
    /// Human-readable confidence label for UI
    var confidenceLabel: String {
        switch confidence {
        case 0.7...:   return "High confidence"
        case 0.4..<0.7: return "Moderate confidence"
        default:        return "Low confidence — best guess"
        }
    }
    
    /// Confidence as a percentage string (e.g., "87%")
    var confidencePercent: String {
        "\(Int(confidence * 100))%"
    }
    
    /// Encodes the full result as JSON for the `species_info` column in Supabase
    var speciesInfoJSON: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
