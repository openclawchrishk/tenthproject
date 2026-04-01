import SwiftUI

enum ToastKind: Equatable {
    case success
    case error
    case info

    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: return AppColor.success
        case .error: return AppColor.error
        case .info: return AppColor.secondary
        }
    }

    var background: Color {
        switch self {
        case .success: return AppColor.success.opacity(0.12)
        case .error: return AppColor.error.opacity(0.12)
        case .info: return AppColor.secondary.opacity(0.12)
        }
    }
}

struct ToastPayload: Equatable {
    let id: UUID
    let kind: ToastKind
    let message: String
}

@MainActor
final class ToastCenter: ObservableObject {
    @Published private(set) var current: ToastPayload?
    private var dismissTask: Task<Void, Never>?

    /// Toast visible duration before slide-up + fade out.
    private static let displayDurationSeconds: Double = 2

    func show(_ kind: ToastKind, _ message: String) {
        dismissTask?.cancel()
        let id = UUID()
        withAnimation(.easeOut(duration: 0.28)) {
            current = ToastPayload(id: id, kind: kind, message: message)
        }
        dismissTask = Task { [weak self] in
            let ns = UInt64(Self.displayDurationSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if self.current?.id == id {
                    withAnimation(.easeIn(duration: 0.32)) {
                        self.current = nil
                    }
                }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeIn(duration: 0.28)) {
            current = nil
        }
    }
}

struct ToastBanner: View {
    let toast: ToastPayload
    @State private var successIconScale: CGFloat = 0.2

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: toast.kind.iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(toast.kind.tint)
                .scaleEffect(toast.kind == .success ? successIconScale : 1)
                .onAppear {
                    guard toast.kind == .success else { return }
                    successIconScale = 0.2
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                        successIconScale = 1
                    }
                }
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .fill(AppColor.cardBackground)
                .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .stroke(toast.kind.tint.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, CardChrome.padding)
        .accessibilityElement(children: .combine)
    }
}

struct ToastOverlayModifier: ViewModifier {
    @ObservedObject var center: ToastCenter

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let t = center.current {
                    ToastBanner(toast: t)
                        .padding(.top, 12)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            )
                        )
                        .animation(.easeOut(duration: 0.28), value: center.current?.id)
                }
            }
    }
}

extension View {
    func deskerToastOverlay(_ center: ToastCenter) -> some View {
        modifier(ToastOverlayModifier(center: center))
    }
}
