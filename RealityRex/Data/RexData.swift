//
//  RexData.swift
//  RealityRex
//
//  Created by Fredy Humberto Lopez on 4/4/23.
//

import Foundation
import RealityKit
import UIKit

final class RexData {

    let debug = true
    private(set) var bodyMeshResources: [MeshResource] = []
    private(set) var bodyFramePrototypes: [ModelEntity] = []
    private(set) var isReady = false
    private var isLoading = false
    private var totalFrames = 0
    static let shared = RexData()

    static func prewarm() {
        Task { await Self.shared.prewarm() }
    }

    init() {}

    func prewarm() async {
        guard !isReady, !isLoading else { return }
        isLoading = true
        let start = CFAbsoluteTimeGetCurrent()
        DebugLog.log("RexData prewarm: start (mainThread=\(Thread.isMainThread))", category: "RexData")

        let data = await Task.detached { [debug] () -> (indices: [UInt32], texcoords: [SIMD2<Float>], frames: [(positions: [SIMD3<Float>], normals: [SIMD3<Float>])]) in
            let indices = Self.shared.loadFileAsUInt32(fileName: "rex_body_indices", fileExtension: "dat")
            let texcoords = Self.shared.loadFileAsFloat2(fileName: "rex_body_texturecoordinates", fileExtension: "dat")
            var frames: [(positions: [SIMD3<Float>], normals: [SIMD3<Float>])] = []
            frames.reserveCapacity(41)
            for index in 0...40 {
                let positions = Self.shared.loadFileAsFloat3(fileName: "rex_body_frame_\(index)_positions", fileExtension: "dat")
                let normals = Self.shared.loadFileAsFloat3(fileName: "rex_body_frame_\(index)_normals", fileExtension: "dat")
                if debug {
                    DebugLog.log("RexData frame \(index): positions=\(positions.count) normals=\(normals.count)", category: "RexData")
                }
                frames.append((positions: positions, normals: normals))
            }
            return (indices, texcoords, frames)
        }.value

        totalFrames = data.frames.count
        let meshes = await Task.detached {
            await Self.shared.generateMeshes(indices: data.indices, texcoords: data.texcoords, frames: data.frames)
        }.value
        await MainActor.run { self.bodyMeshResources = meshes }
        await self.buildFramePrototypes()
        await Task.yield()
        await MainActor.run {
            self.isReady = true
            self.isLoading = false
            let duration = CFAbsoluteTimeGetCurrent() - start
            DebugLog.log("RexData prewarm duration: \(String(format: "%.3f", duration))s", category: "RexData")
            NotificationCenter.default.post(name: .rexDataReady, object: nil)
        }
    }

    private func generateMeshes(indices: [UInt32], texcoords: [SIMD2<Float>], frames: [(positions: [SIMD3<Float>], normals: [SIMD3<Float>])]) async -> [MeshResource] {
        guard !indices.isEmpty, !texcoords.isEmpty else {
            DebugLog.log("RexData loadBody: missing indices/texcoords, aborting", category: "RexData")
            return []
        }

        var meshDescriptor = MeshDescriptor()
        meshDescriptor.primitives = .triangles(indices)
        meshDescriptor.textureCoordinates = MeshBuffers.TextureCoordinates(texcoords)

        var meshes: [MeshResource] = []
        meshes.reserveCapacity(frames.count)

        var skippedCountPositionsNormals = 0
        var skippedCountTexcoordsPositions = 0

        for index in 0..<frames.count {
            let positions = frames[index].positions
            let normals = frames[index].normals
            guard !positions.isEmpty, !normals.isEmpty else {
                DebugLog.log("RexData frame \(index): missing positions/normals, skipping", category: "RexData")
                continue
            }
            guard positions.count == normals.count else {
                DebugLog.log("RexData frame \(index): positions/normals count mismatch (\(positions.count) vs \(normals.count)), skipping", category: "RexData")
                skippedCountPositionsNormals += 1
                continue
            }
            guard texcoords.count == positions.count else {
                DebugLog.log("RexData frame \(index): texcoords/positions count mismatch (\(texcoords.count) vs \(positions.count)), skipping", category: "RexData")
                skippedCountTexcoordsPositions += 1
                continue
            }

            meshDescriptor.positions = MeshBuffers.Positions(positions)
            meshDescriptor.normals = MeshBuffers.Normals(normals)

            do {
                let mesh = try MeshResource.generate(from: [meshDescriptor])
                meshes.append(mesh)
            } catch {
                DebugLog.log("RexData frame \(index): MeshResource.generate failed: \(error)", category: "RexData")
            }

            // Debounce progress notifications to reduce main-thread pressure (~10 Hz)
            struct ProgressDebounce { static var lastPost: CFAbsoluteTime = 0 }
            let now = CFAbsoluteTimeGetCurrent()
            if now - ProgressDebounce.lastPost > 0.1 || index + 1 == frames.count {
                ProgressDebounce.lastPost = now
                NotificationCenter.default.post(
                    name: .rexDataProgress,
                    object: nil,
                    userInfo: ["current": index + 1, "total": frames.count]
                )
            }
            try? await Task.sleep(nanoseconds: 8_000_000)
        }

        if debug {
            DebugLog.log("RexData loadBody: generated meshes=\(meshes.count)", category: "RexData")
        }

        DebugLog.log("RexData loadBody: skipped \(skippedCountPositionsNormals) frames due to positions/normals count mismatch", category: "RexData")
        DebugLog.log("RexData loadBody: skipped \(skippedCountTexcoordsPositions) frames due to texcoords/positions count mismatch", category: "RexData")
        return meshes
    }

    @MainActor
    private func buildFramePrototypes() async {
        bodyFramePrototypes.removeAll(keepingCapacity: true)
        bodyFramePrototypes.reserveCapacity(bodyMeshResources.count)
        let chunkSize = 2
        var current = 0
        while current < bodyMeshResources.count {
            let end = min(current + chunkSize, bodyMeshResources.count)
            for i in current..<end {
                let mesh = bodyMeshResources[i]
                let entity = ModelEntity(mesh: mesh, materials: [simpleBodyMaterial])
                // Removed collision shape generation to keep prototypes light
                // entity.generateCollisionShapes(recursive: false)
                entity.isEnabled = (i == 0)
                bodyFramePrototypes.append(entity)
            }
            current = end
            // Yield to keep the UI responsive between chunks
            await Task.yield()
        }
        if debug {
            DebugLog.log("RexData buildFramePrototypes: \(bodyFramePrototypes.count) prototypes", category: "RexData")
        }
        // Apply textures in small batches to avoid blocking the main thread
        Task { @MainActor [weak self] in
            guard let self else { return }
            let batchSize = 2
            var idx = 0
            while idx < self.bodyFramePrototypes.count {
                let end = min(idx + batchSize, self.bodyFramePrototypes.count)
                for i in idx..<end {
                    self.bodyFramePrototypes[i].model?.materials = [self.bodyMaterial]
                }
                idx = end
                await Task.yield()
                try? await Task.sleep(nanoseconds: 8_000_000)
            }
        }
    }

    @MainActor
    func generateCollisionShapesIfNeeded() async {
        // Generate collision shapes lazily in small batches to avoid blocking the main thread
        let batchSize = 2
        var idx = 0
        while idx < bodyFramePrototypes.count {
            let end = min(idx + batchSize, bodyFramePrototypes.count)
            for i in idx..<end {
                let entity = bodyFramePrototypes[i]
                // Only generate if not already present
                if entity.components[CollisionComponent.self] == nil {
                    entity.generateCollisionShapes(recursive: false)
                }
            }
            idx = end
            await Task.yield()
            try? await Task.sleep(nanoseconds: 8_000_000)
        }
    }

    lazy var bodyResourceColor: TextureResource? = try? TextureResource.load(named: "rex_body_color", in: .main)
    lazy var bodyResourceNormal: TextureResource? = try? TextureResource.load(named: "rex_body_normal", in: .main)
    lazy var bodyResourceSpecular: TextureResource? = try? TextureResource.load(named: "rex_body_specular", in: .main)

    @MainActor
    lazy var simpleBodyMaterial: PhysicallyBasedMaterial = {
        var material = PhysicallyBasedMaterial()
        return material
    }()

    @MainActor
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

    private func loadFileAsUInt32(fileName: String, fileExtension: String) -> [UInt32] {
        guard let data = load(fileName: fileName, fileExtension: fileExtension),
              data.count % MemoryLayout<UInt32>.stride == 0 else {
            DebugLog.log("UInt32 data size not aligned for \(fileName).\(fileExtension)", category: "RexData")
            return []
        }
        return data.withUnsafeBytes { buffer in
            let count = buffer.count / MemoryLayout<UInt32>.stride
            let result: [UInt32] = (0..<count).map { i in
                buffer.load(fromByteOffset: i * MemoryLayout<UInt32>.stride, as: UInt32.self)
            }
            return result
        }
    }

    private func loadFileAsFloat2(fileName: String, fileExtension: String) -> [SIMD2<Float>] {
        guard let data = load(fileName: fileName, fileExtension: fileExtension),
              data.count % MemoryLayout<Float>.stride == 0 else {
            DebugLog.log("Float data size not aligned for \(fileName).\(fileExtension)", category: "RexData")
            return []
        }
        return data.withUnsafeBytes { buffer in
            let count = buffer.count / MemoryLayout<Float>.stride
            let floatArray: [Float] = (0..<count).map { i in
                buffer.load(fromByteOffset: i * MemoryLayout<Float>.stride, as: Float.self)
            }
            guard floatArray.count % 2 == 0 else {
                DebugLog.log("Float2 data count not divisible by 2 for \(fileName).\(fileExtension): count=\(floatArray.count)", category: "RexData")
                return []
            }
            let result: [SIMD2<Float>] = stride(from: 0, to: floatArray.count, by: 2).map { i in
                SIMD2<Float>(floatArray[i], floatArray[i + 1])
            }
            return result
        }
    }

    private func loadFileAsFloat3(fileName: String, fileExtension: String) -> [SIMD3<Float>] {
        guard let data = load(fileName: fileName, fileExtension: fileExtension),
              data.count % MemoryLayout<Float>.stride == 0 else {
            DebugLog.log("Float data size not aligned for \(fileName).\(fileExtension)", category: "RexData")
            return []
        }
        return data.withUnsafeBytes { buffer in
            let count = buffer.count / MemoryLayout<Float>.stride
            let floatArray: [Float] = (0..<count).map { i in
                buffer.load(fromByteOffset: i * MemoryLayout<Float>.stride, as: Float.self)
            }
            guard floatArray.count % 3 == 0 else {
                DebugLog.log("Float3 data count not divisible by 3 for \(fileName).\(fileExtension): count=\(floatArray.count)", category: "RexData")
                return []
            }
            let result: [SIMD3<Float>] = stride(from: 0, to: floatArray.count, by: 3).map { i in
                SIMD3<Float>(floatArray[i], floatArray[i + 1], floatArray[i + 2])
            }
            return result
        }
    }

    private func load(fileName: String, fileExtension: String) -> Data? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            DebugLog.log("Failed to locate \(fileName).\(fileExtension)", category: "RexData")
            return nil
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            DebugLog.log("\(error.localizedDescription): could not load \(fileName).\(fileExtension)", category: "RexData")
            return nil
        }
    }
}

