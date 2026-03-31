import SwiftUI
import UIKit

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
                    VStack(spacing: 20) {
                        if viewModel.isLoading {
                            ProgressView()
                                .padding(.top, 40)
                        } else if let err = viewModel.errorMessage {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding()
                        } else if let desk = viewModel.currentDesk {
                            VStack(spacing: 16) {
                                DeskCardView(desk: desk) {
                                    Task { await viewModel.viewAgain() }
                                }
                                .id(viewModel.refreshGeneration)

                                NavigationLink {
                                    DeskDetailView(deskId: desk.id)
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text.magnifyingglass")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(AppColor.primary, AppColor.secondary)
                                        Text("查看完整專案詳情")
                                            .fontWeight(.semibold)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
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
            .navigationBarHidden(true)
        }
        .tint(AppColor.primary)
    }
}
