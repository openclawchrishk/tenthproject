import SwiftUI

enum ToastKind {
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

    func show(_ kind: ToastKind, _ message: String) {
        dismissTask?.cancel()
        let id = UUID()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            current = ToastPayload(id: id, kind: kind, message: message)
        }
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if current?.id == id {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        current = nil
                    }
                }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            current = nil
        }
    }
}

struct ToastBanner: View {
    let toast: ToastPayload

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: toast.kind.iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(toast.kind.tint)
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
                                removal: .opacity.combined(with: .move(edge: .top))
                            )
                        )
                        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: center.current?.id)
                }
            }
    }
}

extension View {
    func deskerToastOverlay(_ center: ToastCenter) -> some View {
        modifier(ToastOverlayModifier(center: center))
    }
}
