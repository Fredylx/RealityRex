//
//  RexData.swift
//  RealityRex
//
//  Created by Fredy Humberto Lopez on 4/4/23.
//

import Foundation
import RealityKit
import UIKit

/// Handles loading mesh and texture data for the animated T-Rex.
final class RexData {

    // MARK: - Properties

    private(set) var bodyMeshResources: [MeshResource] = []

    // MARK: - Initialization

    init() {
        loadBody()
    }

    // MARK: - Mesh Loading

    private func loadBody() {
        var meshDescriptor = MeshDescriptor()

        meshDescriptor.primitives = .triangles(
            loadFileAsUInt32(fileName: "rex_body_indices", fileExtension: "dat")
        )

        meshDescriptor.textureCoordinates = MeshBuffers.TextureCoordinates(
            loadFileAsFloat2(fileName: "rex_body_texturecoordinates", fileExtension: "dat")
        )

        for index in 0...40 {
            meshDescriptor.positions = MeshBuffers.Positions(
                loadFileAsFloat3(fileName: "rex_body_frame_\(index)_positions", fileExtension: "dat")
            )

            meshDescriptor.normals = MeshBuffers.Normals(
                loadFileAsFloat3(fileName: "rex_body_frame_\(index)_normals", fileExtension: "dat")
            )

            if let mesh = try? MeshResource.generate(from: [meshDescriptor]) {
                bodyMeshResources.append(mesh)
            }
        }
    }

    // MARK: - Textures

    lazy var bodyResourceColor: TextureResource? = {
        try? TextureResource.load(named: "rex_body_color", in: .main)
    }()

    lazy var bodyResourceNormal: TextureResource? = {
        try? TextureResource.load(named: "rex_body_normal", in: .main)
    }()

    lazy var bodyResourceSpecular: TextureResource? = {
        try? TextureResource.load(named: "rex_body_specular", in: .main)
    }()

    lazy var bodyMaterial: PhysicallyBasedMaterial = {
        var material = PhysicallyBasedMaterial()

        if let color = bodyResourceColor {
            material.baseColor = .init(texture: .init(color))
        }
        if let normal = bodyResourceNormal {
            material.normal = .init(texture: .init(normal))
        }
        if let specular = bodyResourceSpecular {
            material.specular = .init(texture: .init(specular))
        }

        return material
    }()

    // MARK: - Binary File Loaders

    private func loadFileAsUInt32(fileName: String, fileExtension: String) -> [UInt32] {
        guard let data = load(fileName: fileName, fileExtension: fileExtension) else { return [] }
        return data.withUnsafeBytes { buffer in
            let count = buffer.count / MemoryLayout<UInt32>.stride
            return (0..<count).map {
                buffer.load(fromByteOffset: $0 * MemoryLayout<UInt32>.stride, as: UInt32.self)
            }
        }
    }

    private func loadFileAsFloat2(fileName: String, fileExtension: String) -> [SIMD2<Float>] {
        guard let data = load(fileName: fileName, fileExtension: fileExtension) else { return [] }
        return data.withUnsafeBytes { buffer in
            let count = buffer.count / MemoryLayout<Float>.stride
            let floatArray = (0..<count).map {
                buffer.load(fromByteOffset: $0 * MemoryLayout<Float>.stride, as: Float.self)
            }
            return stride(from: 0, to: floatArray.count, by: 2).map {
                SIMD2<Float>(floatArray[$0], floatArray[$0 + 1])
            }
        }
    }

    private func loadFileAsFloat3(fileName: String, fileExtension: String) -> [SIMD3<Float>] {
        guard let data = load(fileName: fileName, fileExtension: fileExtension) else { return [] }
        return data.withUnsafeBytes { buffer in
            let count = buffer.count / MemoryLayout<Float>.stride
            let floatArray = (0..<count).map {
                buffer.load(fromByteOffset: $0 * MemoryLayout<Float>.stride, as: Float.self)
            }
            return stride(from: 0, to: floatArray.count, by: 3).map {
                SIMD3<Float>(floatArray[$0], floatArray[$0 + 1], floatArray[$0 + 2])
            }
        }
    }

    // MARK: - Generic Data Loader

    private func load(fileName: String, fileExtension: String) -> Data? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            print("❌ Failed to locate \(fileName).\(fileExtension)")
            return nil
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            print("❌ \(error.localizedDescription): could not load \(fileName).\(fileExtension)")
            return nil
        }
    }
}
