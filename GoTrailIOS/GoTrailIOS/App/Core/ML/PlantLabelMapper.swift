//
//  PlantLabelMapper.swift
//  GoTrailIOS
//
//  Created by Harvey Tan on 4/26/26.
//

import Foundation

/// Maps model output indices (0–1080) to human-readable plant species names.
///
/// Uses two JSON files from the PlantNet-300K dataset:
/// 1. class_idx_to_species_id.json: class index → species ID
/// 2. plantnet300K_species_id_2_name.json: species ID → scientific name
///
/// Loaded once as a singleton — the JSON files are small (<100KB total)
/// and never change at runtime.
class PlantLabelMapper {
    
    static let shared = PlantLabelMapper()
    
    /// class index (String, e.g. "437") → species ID (String, e.g. "1210833")
    private let classIdxToSpeciesId: [String: String]
    
    /// species ID (String, e.g. "1210833") → scientific name (String, e.g. "Lavandula angustifolia")
    private let speciesIdToName: [String: String]
    
    /// Total number of classes the model can predict
    var classCount: Int { classIdxToSpeciesId.count }
    
    private init() {
        // Load class_idx_to_species_id.json
        guard let idxURL = Bundle.main.url(
            forResource: "class_idx_to_species_id",
            withExtension: "json"
        ) else {
            fatalError("""
                ❌ Missing class_idx_to_species_id.json in app bundle.
                Download it from: https://github.com/plantnet/plantnet-300k
                Then drag it into your Xcode project.
            """)
        }
        
        guard let idxData = try? Data(contentsOf: idxURL),
              let idxMap = try? JSONDecoder().decode([String: String].self, from: idxData)
        else {
            fatalError("❌ Failed to parse class_idx_to_species_id.json")
        }
        
        self.classIdxToSpeciesId = idxMap
        
        // Load plantnet300K_species_id_2_name.json
        guard let nameURL = Bundle.main.url(
            forResource: "plantnet300K_species_id_2_name",
            withExtension: "json"
        ) else {
            fatalError("""
                ❌ Missing plantnet300K_species_id_2_name.json in app bundle.
                Download it from: https://github.com/plantnet/plantnet-300k
                Then drag it into your Xcode project.
            """)
        }
        
        guard let nameData = try? Data(contentsOf: nameURL),
              let nameMap = try? JSONDecoder().decode([String: String].self, from: nameData)
        else {
            fatalError("❌ Failed to parse plantnet300K_species_id_2_name.json")
        }
        
        self.speciesIdToName = nameMap
        
        print("✅ PlantLabelMapper loaded: \(classIdxToSpeciesId.count) classes, \(speciesIdToName.count) species names")
    }
    
    /// Converts a class index (from model output) to a species name.
    /// Returns "Unknown Species" if the mapping fails.
    func getSpeciesName(for classIndex: Int) -> String {
        guard let speciesId = classIdxToSpeciesId[String(classIndex)] else {
            return "Unknown Species"
        }
        return speciesIdToName[speciesId] ?? "Unknown Species (ID: \(speciesId))"
    }
    
    /// Converts a class index to its PlantNet species ID.
    /// Useful if you want to store the ID in Supabase for later lookup.
    func getSpeciesId(for classIndex: Int) -> String? {
        return classIdxToSpeciesId[String(classIndex)]
    }
}
