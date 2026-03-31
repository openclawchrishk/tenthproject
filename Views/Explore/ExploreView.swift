import SwiftUI

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @EnvironmentObject private var auth: AuthRepository

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppHeaderView(
                    title: "探索",
                    subtitle: "發現新的創業 Desk 與機會"
                )

                ScrollView {
                    VStack(spacing: 24) {
                        if viewModel.isLoading {
                            ProgressView()
                                .padding(.top, 40)
                        } else if let err = viewModel.errorMessage {
                            VStack(spacing: 12) {
                                Text(err)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                Button("重試") {
                                    Task { await viewModel.load() }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppColor.primary)
                            }
                            .padding()
                        } else if let desk = viewModel.currentDesk {
                            VStack(spacing: 18) {
                                DeskCardView(desk: desk) {
                                    Task { await viewModel.viewAgain() }
                                }
                                .id("\(viewModel.refreshGeneration.uuidString)-\(desk.id.uuidString)")

                                NavigationLink {
                                    DeskDetailView(deskId: desk.id)
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text.magnifyingglass")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(AppColor.primary, AppColor.secondary)
                                        Text("查看完整專案詳情")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(AppColor.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: CardChrome.cornerRadius, style: .continuous)
                                            .fill(AppColor.secondaryGroupedSurface)
                                            .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadius, x: 0, y: CardChrome.shadowY)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                        } else {
                            ContentUnavailableView(
                                "暫無 Desk",
                                systemImage: "briefcase",
                                description: Text("稍後再試或下拉重新整理")
                            )
                            .padding(.top, 40)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .refreshable { await viewModel.load() }
            }
            .background(AppColor.background.ignoresSafeArea())
            .task { await viewModel.load() }
            .deskerHiddenNavigationBar()
        }
    }
}
