import SwiftUI

struct ControllerPadView: View {
    let onMove: (String) -> Void
    let onRotate: (String) -> Void
    let onScale: (String) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                Button(action: { onMove("up") }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 36)
                }
                HStack(spacing: 8) {
                    Button(action: { onMove("left") }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 36)
                    }
                    Button(action: { onMove("right") }) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 36)
                    }
                }
                Button(action: { onMove("down") }) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 36)
                }
            }

            VStack(spacing: 8) {
                Button(action: { onRotate("left") }) {
                    Image(systemName: "rotate.left")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 36)
                }
                HStack(spacing: 8) {
                    Button(action: { onScale("down") }) {
                        Image(systemName: "minus")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 36)
                    }
                    Button(action: { onScale("up") }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 36)
                    }
                }
                Button(action: { onRotate("right") }) {
                    Image(systemName: "rotate.right")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 36)
                }
            }

            Button(action: { onDelete() }) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 36)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.7))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
    }
}
