import SwiftUI
#if os(iOS)
import PhotosUI
import UIKit
#endif

struct BasicInfoView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var auth: AuthRepository
    @FocusState private var focusedField: BasicInfoFocusField?

    @State private var nameError: String?
    @State private var langError: String?
    @State private var validationShakeTrigger = 0
#if os(iOS)
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showCameraPicker = false
    @State private var cameraUIImage: UIImage?
#endif

    private enum BasicInfoFocusField: Hashable {
        case displayName
    }

    private let regionOptions = ["HK", "深圳", "廣州", "澳門", "珠海", "東莞", "海外港人", "其他"]
    private let commitmentOptions = [
        ("全職", "全情投入創業", "flame.fill"),
        ("兼職", "兼顧現有工作", "clock.fill"),
        ("只看看", "先了解一下", "eye.fill")
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppColor.primary)

                    Text("基本資料")
                        .font(.title.bold())
                        .foregroundStyle(AppColor.textPrimary)

                    Text("呢啲資訊會顯示喺你嘅個人檔案")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .padding(.top, 24)

                avatarSection
                    .padding(.horizontal, 24)

                // Display name
                VStack(alignment: .leading, spacing: 8) {
                    Text("顯示名稱")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.textPrimary)

                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(width: 24)

                        TextField("你嘅稱呼", text: $viewModel.displayName)
                            .focused($focusedField, equals: .displayName)
                            .deskerTextFieldNoAutocaps()
                            .submitLabel(.next)
                            .onChange(of: viewModel.displayName) { _, _ in
                                nameError = nil
                            }
                    }
                    .padding(14)
                    .background(AppColor.cardBackground)
                    .cornerRadius(CardChrome.cornerRadiusMedium)
                    .shadow(color: CardChrome.buttonShadowColor, radius: CardChrome.shadowRadiusButton, x: 0, y: CardChrome.shadowYButton)
                    .overlay(
                        RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium)
                            .stroke(nameError != nil ? AppColor.error.opacity(0.85) : Color.clear, lineWidth: 1.5)
                    )
                    .deskerShake(trigger: validationShakeTrigger)

                    if let nameError {
                        inlineError(nameError)
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    }
                }
                .id("displayNameField")
                .padding(.horizontal, 24)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: nameError)

                // Region
                VStack(alignment: .leading, spacing: 8) {
                    Text("地區")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.textPrimary)

                    Menu {
                        ForEach(regionOptions, id: \.self) { region in
                            Button(region) {
                                viewModel.region = region
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(AppColor.textSecondary)
                                .frame(width: 24)

                            Text(viewModel.region.isEmpty ? "選擇地區" : viewModel.region)
                                .foregroundStyle(viewModel.region.isEmpty ? AppColor.textSecondary : AppColor.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        .padding(14)
                        .background(AppColor.cardBackground)
                        .cornerRadius(CardChrome.cornerRadiusMedium)
                        .shadow(color: CardChrome.buttonShadowColor, radius: CardChrome.shadowRadiusButton, x: 0, y: CardChrome.shadowYButton)
                    }
                }
                .padding(.horizontal, 24)

                // Languages
                VStack(alignment: .leading, spacing: 8) {
                    Text("語言")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.textPrimary)

                    FlowLayout(spacing: 8) {
                        ForEach(OnboardingViewModel.languageOptions, id: \.self) { lang in
                            let isSelected = viewModel.selectedLanguages.contains(lang)
                            Button {
                                HapticFeedback.light()
                                langError = nil
                                if isSelected {
                                    viewModel.selectedLanguages.remove(lang)
                                } else {
                                    viewModel.selectedLanguages.insert(lang)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: langIcon(lang))
                                        .font(.caption)
                                    Text(lang)
                                        .font(.subheadline)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isSelected ? AppColor.primary : AppColor.primary.opacity(0.1))
                                .foregroundStyle(isSelected ? .white : AppColor.primary)
                                .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous)
                                        .stroke(isSelected ? AppColor.primary : AppColor.textSecondary.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(DeskerChipPressStyle())
                        }
                    }
                    if let langError {
                        inlineError(langError)
                            .padding(.top, 4)
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    }
                }
                .padding(.horizontal, 24)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: langError)

                // Commitment level
                VStack(alignment: .leading, spacing: 8) {
                    Text("投入程度")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.textPrimary)

                    VStack(spacing: 8) {
                        ForEach(commitmentOptions, id: \.0) { option in
                            let isSelected = viewModel.commitmentLevel == option.0
                            Button {
                                HapticFeedback.light()
                                viewModel.commitmentLevel = option.0
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: option.2)
                                        .font(.title3)
                                        .foregroundStyle(isSelected ? AppColor.primary : AppColor.textSecondary)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.0)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(AppColor.textPrimary)
                                        Text(option.1)
                                            .font(.caption)
                                            .foregroundStyle(AppColor.textSecondary)
                                    }

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppColor.primary)
                                    }
                                }
                                .padding(12)
                                .background(AppColor.cardBackground)
                                .cornerRadius(CardChrome.cornerRadiusMedium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium)
                                        .stroke(isSelected ? AppColor.primary : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(DeskerChipPressStyle())
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 24)

                // Continue button
                Button {
                    attemptContinue()
                } label: {
                    HStack {
                        Text("繼續")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [AppColor.primary, AppColor.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(CardChrome.cornerRadiusMedium)
                }
                .buttonStyle(DeskerButtonPressStyle())
                .disabled(viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.selectedLanguages.isEmpty)
                .opacity(viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.selectedLanguages.isEmpty ? 0.5 : 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            }
            .onChange(of: focusedField) { _, new in
                guard new == .displayName else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo("displayNameField", anchor: .center)
                }
            }
        }
        .background(AppColor.background.ignoresSafeArea())
#if os(iOS)
        .onChange(of: photoPickerItem) { _, new in
            Task {
                guard let new else { return }
                if let data = try? await new.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        viewModel.avatarImageData = data
                    }
                }
            }
        }
        .onChange(of: cameraUIImage) { _, new in
            if let new {
                viewModel.avatarImageData = new.jpegData(compressionQuality: 0.88)
            }
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            ImagePicker(image: $cameraUIImage, source: .camera)
                .ignoresSafeArea()
        }
#endif
    }

#if os(iOS)
    private var avatarSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Group {
                    if let data = viewModel.avatarImageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle()
                            .fill(AppColor.primary.opacity(0.1))
                        Image(systemName: "camera.fill")
                            .font(.title)
                            .foregroundStyle(AppColor.primary)
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColor.gold.opacity(0.35), lineWidth: 2))

                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Color.clear
                        .frame(width: 96, height: 96)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 16) {
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("相簿", systemImage: "photo.on.rectangle.angled")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.primary)
                }
                .buttonStyle(.bordered)
                .tint(AppColor.primary)

                Button {
                    showCameraPicker = true
                    HapticFeedback.light()
                } label: {
                    Label("拍照", systemImage: "camera.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(AppColor.primary)
            }

            Text("選擇頭像（可選）")
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
#else
    private var avatarSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(AppColor.primary.opacity(0.1))
                    .frame(width: 88, height: 88)
                Image(systemName: "camera.fill")
                    .font(.title)
                    .foregroundStyle(AppColor.primary)
            }
            Text("點擊上傳頭像")
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
#endif

    private func inlineError(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(AppColor.error)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppColor.error)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attemptContinue() {
        var ok = true
        let name = viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                nameError = "請輸入顯示名稱"
            }
            validationShakeTrigger += 1
            HapticFeedback.error()
            ok = false
        } else if name.count > ProfileFieldValidation.displayNameMaxLength {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                nameError = "顯示名稱最多 \(ProfileFieldValidation.displayNameMaxLength) 字"
            }
            validationShakeTrigger += 1
            HapticFeedback.error()
            ok = false
        }
        if viewModel.selectedLanguages.isEmpty {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                langError = "請至少選擇一種語言"
            }
            validationShakeTrigger += 1
            HapticFeedback.error()
            ok = false
        }
        guard ok else { return }
        viewModel.proceedToNextStep()
    }

    private func langIcon(_ lang: String) -> String {
        switch lang {
        case "廣東話": return "character.bubble.fill"
        case "普通話": return "character.bubble"
        case "英文": return "a.circle.fill"
        default: return "globe"
        }
    }
}

#if os(iOS)
/// Presents `UIImagePickerController` for camera capture during onboarding.
private struct ImagePicker: UIViewControllerRepresentable {
    enum Source {
        case camera
        case photoLibrary
    }

    @Binding var image: UIImage?
    var source: Source
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = source == .camera ? .camera : .photoLibrary
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif

// Simple flow layout for chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

struct BasicInfoView_Previews: PreviewProvider {
    static var previews: some View {
        BasicInfoView(viewModel: OnboardingViewModel())
            .environmentObject(AuthRepository())
    }
}
