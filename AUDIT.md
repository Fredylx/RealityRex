# RealityRex Codebase Audit

## Overview
RealityRex is a SwiftUI + RealityKit AR experience that anchors animated T-Rex models on detected horizontal planes. Core flows include a splash screen (`RealityRexApp` → `SplashScreenView` → `MainARView`), an AR container with overlays (`RealityKitView` + `MainARView`), and the scene controller (`RexView`) that manages placement, gestures, and animation. Data loading for meshes and materials lives in `RexData`/`RexObject`.

## Strengths
- Clear app entry and handoff from splash to AR container via SwiftUI scene composition, keeping launch logic simple.【F:RealityRex/RealityRexApp.swift†L10-L16】【F:RealityRex/SplashScreenView.swift†L10-L47】
- ARView setup is encapsulated in `RealityKitView`, with horizontal plane detection, environment texturing, coaching overlay, and a global "Clear All" control wired through a coordinator/notification, keeping UIKit bridging localized.【F:RealityRex/RealityKitView.swift†L16-L118】
- Animation and model loading concerns are separated (`RexData` builds meshes/materials, `RexObject` animates frames), resulting in readable responsibilities for mesh preparation and per-frame updates.【F:RealityRex/RexData.swift†L12-L81】【F:RealityRex/RexObject.swift†L11-L58】

## Key Issues & Risks (prioritized)
1) **Conflicting instruction overlays and outdated guidance** – `InstructionOverlayView` is defined twice (once inside `MainARView` and once in its own file). The inlined version still tells users to "Tap and hold to delete" even though deletion is now a double-tap, which leads to mismatched UI copy and duplicated code paths to maintain.【F:RealityRex/MainARView.swift†L63-L119】【F:RealityRex/InstructionOverlayView.swift†L10-L75】【F:RealityRex/RexView.swift†L155-L165】
2) **Deletion UX lacks safety net and retains dead code** – Double-tap deletes dinos instantly with no confirmation or haptic feedback, while a legacy `showDeleteConfirmation` helper remains unused. This creates an abrupt destructive action and unused code to maintain.【F:RealityRex/RexView.swift†L155-L165】【F:RealityRex/RexView.swift†L262-L276】
3) **Hard-coded placement constraints without user feedback** – Dino placement silently stops after 14 instances and rejects taps within a 0.25 m threshold, but there is no UI feedback explaining why placement fails. These magic numbers are embedded in gesture handling, reducing configurability and debuggability.【F:RealityRex/RexView.swift†L74-L110】
4) **Ground material path is misleading** – `makeGrassPlane` comments describe loading a grass texture, but the implementation now always uses a solid dark green PBR material with an optional hand icon overlay. The mismatch between comments and behavior can cause confusion when updating art direction.【F:RealityRex/RexView.swift†L114-L149】
5) **Minimal asset load error handling** – Binary/texture loading logs to console only; failures are not surfaced to users or recovered (e.g., substituting default assets), which can leave blank models without notice in production.【F:RealityRex/RexData.swift†L123-L134】
6) **UI guidance inconsistency** – The main overlay steps in `MainARView` still describe tap-and-hold deletion, conflicting with the newer onboarding in `InstructionOverlayView.swift` and the implemented double-tap gesture, risking user confusion.【F:RealityRex/MainARView.swift†L83-L108】【F:RealityRex/InstructionOverlayView.swift†L20-L70】【F:RealityRex/RexView.swift†L155-L165】

## Recommendations
- Consolidate to a single `InstructionOverlayView` source and update all copy to match the double-tap delete gesture; consider injecting the steps so AR gesture changes stay in sync with the UI.【F:RealityRex/MainARView.swift†L63-L119】【F:RealityRex/InstructionOverlayView.swift†L10-L75】
- Add a user-friendly delete affordance (e.g., haptic feedback, optional confirmation, or undo) and remove the unused `showDeleteConfirmation` helper to reduce dead code.【F:RealityRex/RexView.swift†L155-L165】【F:RealityRex/RexView.swift†L262-L276】
- Replace magic numbers (max dino count, overlap threshold) with configurable constants and surface unobtrusive feedback when placement is blocked so users understand limits.【F:RealityRex/RexView.swift†L74-L110】
- Align ground-plane implementation with intent: either load a real grass texture and tone-map it appropriately, or update comments to state it is intentionally a solid dark green with an optional icon overlay.【F:RealityRex/RexView.swift†L114-L149】
- Strengthen asset-loading resilience by surfacing missing-resource errors to the UI and providing fallback materials/meshes when RealityKit resources fail to load.【F:RealityRex/RexData.swift†L123-L134】
- Review AR onboarding text and gesture hints holistically (including the info button flow) to ensure consistent messaging across overlays and in-app help.【F:RealityRex/MainARView.swift†L32-L58】【F:RealityRex/InstructionOverlayView.swift†L20-L70】
