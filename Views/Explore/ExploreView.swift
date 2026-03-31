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
                    VStack(spacing: CardChrome.sectionSpacing) {
                        if viewModel.isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("載入中…")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                            .padding(.top, 40)
                        } else if let err = viewModel.errorMessage {
                            VStack(spacing: 12) {
                                Text(err)
                                    .font(.footnote)
                                    .foregroundStyle(AppColor.error)
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
                                DeskCardView(desk: desk, founder: viewModel.currentFounder) {
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
                                            .foregroundStyle(AppColor.textSecondary)
                                    }
                                    .padding(.horizontal, CardChrome.padding)
                                    .padding(.vertical, CardChrome.padding)
                                    .deskerElevatedCard()
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                        } else {
                            ContentUnavailableView(
                                "暫時沒有內容",
                                systemImage: "line.3.horizontal.decrease.circle",
                                description: Text("試試調整篩選條件")
                            )
                            .padding(.top, 40)
                        }
                    }
                    .padding(.bottom, CardChrome.sectionSpacing)
                }
                .refreshable { await viewModel.load() }
            }
            .background(AppColor.background.ignoresSafeArea())
            .task { await viewModel.load() }
            .deskerHiddenNavigationBar()
        }
    }
}
