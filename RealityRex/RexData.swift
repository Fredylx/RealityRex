//
//  RexData.swift
//  RealityRex
//
//  Created by Fredy Humberto Lopez on 4/4/23.
//

import Foundation
import RealityKit
import UIKit

class RexData {
    
    private(set) var bodyMeshResources = [MeshResource]()
    
    init() {
        
        loadBody()
    }
    
    func loadBody() {
        
        var meshDescriptor = MeshDescriptor()
        
        let indices = loadFileAsUInt32(fileName: "rex_body_indices", fileExtension: "dat")
        
        
        let textureCoordinates = loadFileAsFloat2(fileName: "rex_body_texturecoordinates", fileExtension: "dat")
        
        meshDescriptor.textureCoordinates = MeshBuffers.TextureCoordinates(textureCoordinates)
        meshDescriptor.primitives = .triangles(indices)
        
        
        for index in 0...40 {
            let positions = loadFileAsFloat3(fileName: "rex_body_frame_\(index)_positions", fileExtension: "dat")
            let normals = loadFileAsFloat3(fileName: "rex_body_frame_\(index)_normals", fileExtension: "dat")
            meshDescriptor.positions = MeshBuffers.Positions(positions)
            
            meshDescriptor.normals = MeshBuffers.Normals(normals)
            
            if let meshResource = try? MeshResource.generate(from: [meshDescriptor]) {
                bodyMeshResources.append(meshResource)
            }
        }
    }
    
    lazy var bodyResourceColor: TextureResource? = {
        try? TextureResource.load(named: "rex_body_color", in: Bundle.main)
    }()
    
    lazy var bodyResourceNormal: TextureResource? = {
        try? TextureResource.load(named: "rex_body_normal", in: Bundle.main)
    }()
    
    lazy var bodyResourceSpecular: TextureResource? = {
        try? TextureResource.load(named: "rex_body_specular", in: Bundle.main)
    }()
    
    lazy var bodyMaterial: PhysicallyBasedMaterial = {
        var material = PhysicallyBasedMaterial()
        
        guard let bodyResourceColor = bodyResourceColor else { return material }
        let baseColor = MaterialParameters.Texture(bodyResourceColor)
        material.baseColor = .init(tint: .gray) // ✅ fallback color
//        material.baseColor = .color(.gray)
//        material.baseColor = .color(UIColor.gray)
//        material.baseColor = .init(texture: baseColor)
//        var material = PhysicallyBasedMaterial()
//
//        if let bodyResourceColor = bodyResourceColor {
//            material.baseColor = .init(texture: .init(bodyResourceColor))
//        } else {
//            material.baseColor = .init(tint: .gray) // ✅ fallback color
//        }

        
        guard let bodyResourceNormal = bodyResourceNormal else { return material }
        let normalColor = MaterialParameters.Texture(bodyResourceNormal)
        material.normal = .init(texture: normalColor)
        
        guard let bodyResourceSpecular = bodyResourceSpecular else { return material }
        let specularColor = MaterialParameters.Texture(bodyResourceSpecular)
        material.specular = .init(texture: specularColor)
        
        return material
    }()
    
    func loadFileAsUInt32(fileName: String, fileExtension: String) -> [UInt32] {
        guard let data = load(fileName: fileName, fileExtension: fileExtension) else {
            return [UInt32]()
        }
        
        let resultCount = data.count / MemoryLayout<UInt32>.size
        var result = [UInt32](repeating: 0, count: resultCount)
        
        data.withUnsafeBytes {
            for index in 0..<resultCount {
                let byteOffset = index * MemoryLayout<UInt32>.size
                result[index] = $0.load(fromByteOffset: byteOffset, as: UInt32.self)
            }
        }
        
        return result
    }
    
    func loadFileAsFloat2(fileName: String, fileExtension: String) -> [SIMD2<Float>] {
        guard let data = load(fileName: fileName, fileExtension: fileExtension) else {
            return [SIMD2<Float>]()
        }
        
        let floatCount = data.count / MemoryLayout<Float>.size
        var floats = [Float](repeating: 0.0,
                             count: floatCount)
        data.withUnsafeBytes {
            for index in 0..<floatCount {
                let byteOffset = index * MemoryLayout<Float>.size
                floats[index] = $0.load(fromByteOffset: byteOffset, as: Float.self)
            }
        }
        
        let resultCount = floatCount / 2
        var result = [SIMD2<Float>](repeating: [0.0, 0.0], count: resultCount)
        
        for index in 0..<resultCount {
            let floatIndex = index * 2
            let x = floats[floatIndex + 0]
            let y = floats[floatIndex + 1]
            result[index] = SIMD2<Float>(x: x, y: y)
        }
        
        return result
    }
    
    func loadFileAsFloat3(fileName: String, fileExtension: String) -> [SIMD3<Float>] {
        guard let data = load(fileName: fileName, fileExtension: fileExtension) else {
            return [SIMD3<Float>]()
        }
        
        let floatCount = data.count / MemoryLayout<Float>.size
        var floats = [Float](repeating: 0.0,
                             count: floatCount)
        data.withUnsafeBytes {
            for index in 0..<floatCount {
                let byteOffset = index * MemoryLayout<Float>.size
                floats[index] = $0.load(fromByteOffset: byteOffset, as: Float.self)
            }
        }
        
        let resultCount = floatCount / 3
        var result = [SIMD3<Float>](repeating: [0.0, 0.0, 0.0], count: resultCount)
        
        for index in 0..<resultCount {
            let floatIndex = index * 3
            let x = floats[floatIndex + 0]
            let y = floats[floatIndex + 1]
            let z = floats[floatIndex + 2]
            result[index] = SIMD3<Float>(x: x, y: y, z: z)
        }
        
        return result
    }
    
    func load(fileName: String, fileExtension: String) -> Data? {
        guard let url = Bundle.main.url(forResource: fileName,
                                        withExtension: fileExtension) else {
            print("Could not form URL for \(fileName) with extension \(fileExtension)")
            return nil
        }
        
        do {
            let result = try Data(contentsOf: url)
            return result
        } catch let error {
            print("Failed to load \(fileName).\(fileExtension)")
            return nil
        }
    }
}
