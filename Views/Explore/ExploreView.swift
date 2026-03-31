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
                    VStack(spacing: 24) {
                        if viewModel.isLoading {
                            ProgressView()
                                .padding(.top, 40)
                        } else if let err = viewModel.errorMessage {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
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
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                                            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
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
            .navigationBarHidden(true)
        }
    }
}
