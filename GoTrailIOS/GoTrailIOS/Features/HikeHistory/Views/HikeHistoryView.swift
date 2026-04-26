import SwiftUI

struct HikeHistoryView: View {
    @StateObject private var viewModel = HikeHistoryViewModel()
    @State private var selectedTab: DashboardTab = .history
    @State private var showActiveHike = false
    @State private var activeHikeTitle = "Current Hike"

    private let green = Color(red: 30 / 255, green: 86 / 255, blue: 49 / 255)
    private let pageBackground = Color(red: 245 / 255, green: 248 / 255, blue: 245 / 255)
    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let width = geometry.size.width
                let topInset = geometry.safeAreaInsets.top
                let bottomInset = geometry.safeAreaInsets.bottom
                let horizontalPadding = max(16, width * 0.05)

                ZStack(alignment: .bottom) {
                    pageBackground.ignoresSafeArea()

                    if selectedTab == .add {
                        NewHikeView(
                            onClose: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedTab = .history
                                }
                            },
                            onStartHike: { hikeTitle in
                                activeHikeTitle = hikeTitle.isEmpty ? "Current Hike" : hikeTitle
                                selectedTab = .history
                                showActiveHike = true
                            }
                        )
                        .transition(AnyTransition.opacity.combined(with: .scale(scale: 0.96)))
                    } else {
                        VStack(spacing: 0) {
                            topHeader(topInset: topInset, horizontalPadding: horizontalPadding)
                            ZStack {
                                switch selectedTab {
                                case .history:
                                    historyContent(horizontalPadding: horizontalPadding, bottomInset: bottomInset)
                                        .transition(AnyTransition.opacity.combined(with: .move(edge: .leading)))
                                case .profile:
                                    ProfileTempView()
                                        .transition(AnyTransition.opacity.combined(with: .move(edge: .trailing)))
                                case .add:
                                    EmptyView()
                                }
                            }
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)
                        }
                        bottomNavigation(bottomInset: bottomInset, horizontalPadding: horizontalPadding)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: UUID.self) { hikeID in
                HikeDetailView(hikeId: hikeID)
            }
            .fullScreenCover(isPresented: $showActiveHike, onDismiss: {
                Task {
                    await viewModel.loadHikes()
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await viewModel.loadHikes()
                }
            }) {
                ActiveHikeView(hikeTitle: activeHikeTitle)
                    .interactiveDismissDisabled(true)
            }
        }
    }

    private func topHeader(topInset: CGFloat, horizontalPadding: CGFloat) -> some View {
        HStack {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image("leaf icon")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.white)
                            .frame(width: 13, height: 13)
                    }

                Text("GOTRAIL")
                    .font(.custom("Montserrat-Bold", size: 12))
                    .tracking(0.96)
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(height: 34)

            Spacer()

            Text("\(viewModel.totalTrailCount) trails")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(.white.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .frame(height: 52)
        .padding(.horizontal, horizontalPadding)
        .offset(y: -3)
        .background {
            green
                .frame(height: 52 + topInset)
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(.white.opacity(0.06))
                        .frame(width: 150, height: 150)
                        .offset(x: 58, y: -42)
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(.white.opacity(0.05))
                        .frame(width: 72, height: 72)
                        .offset(x: 36, y: 18)
                }
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(.white.opacity(0.05))
                        .frame(width: 100, height: 100)
                        .offset(x: -30, y: 20)
                }
        }
    }

    private func summaryHeader(horizontalPadding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MY HIKES")
                .font(.custom("Montserrat-Bold", size: 10))
                .tracking(1.6)
                .foregroundStyle(green)

            Text("Hike History")
                .font(.custom("Montserrat-Bold", size: 42))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))

            Text("\(viewModel.totalTrailCount) trails completed")
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))

            HStack(spacing: 10) {
                statCard(icon: "figure.walk", value: viewModel.totalDistanceText, label: "total distance")
                statCard(icon: "leaf", value: viewModel.totalPlantsText, label: "plants found")
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func historyContent(horizontalPadding: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            summaryHeader(horizontalPadding: horizontalPadding)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 50)
                    } else if viewModel.hikes.isEmpty {
                        emptyStateCard
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(viewModel.hikes) { hike in
                                NavigationLink(value: hike.id) {
                                    HikeCardView(hike: hike)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 14)
                .padding(.bottom, 54 + max(0, bottomInset - 8))
            }
            .refreshable {
                await viewModel.loadHikes()
            }
        }
        .task {
            await viewModel.loadHikes()
        }
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(green.opacity(0.08))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(green)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.custom("Montserrat-Bold", size: 15))
                    .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .frame(height: 54)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(green.opacity(0.12))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "figure.hiking")
                        .font(.system(size: 20))
                        .foregroundStyle(green)
                }

            Text("No hikes yet")
                .font(.custom("Montserrat-Bold", size: 20))
                .foregroundStyle(Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255))

            Text("Your hike cards will appear here after your first completed trail.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255))
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 232 / 255, green: 237 / 255, blue: 232 / 255), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func bottomNavigation(bottomInset: CGFloat, horizontalPadding: CGFloat) -> some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    selectedTab = .history
                }
            } label: {
                navPill(icon: "mountain.2", label: "History", isActive: selectedTab == .history)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    selectedTab = .add
                }
            } label: {
                Circle()
                    .fill(green)
                    .frame(width: selectedTab == .add ? 48 : 44, height: selectedTab == .add ? 48 : 44)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: selectedTab == .add ? 26 : 24, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: green.opacity(selectedTab == .add ? 0.42 : 0.3), radius: selectedTab == .add ? 9 : 6, x: 0, y: 4)
                    .scaleEffect(selectedTab == .add ? 1.03 : 1.0)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    selectedTab = .profile
                }
            } label: {
                navPill(icon: "person", label: "Profile", isActive: selectedTab == .profile)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 0)
        .frame(maxWidth: .infinity)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(red: 239 / 255, green: 239 / 255, blue: 239 / 255))
                .frame(height: 1)
        }
    }

    private func navPill(icon: String, label: String, isActive: Bool) -> some View {
        HStack {
            if isActive {
                VStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                    Text(label)
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.45)
                }
                .foregroundStyle(green)
                .frame(width: 72, height: 42)
                .background(green.opacity(0.1))
                .clipShape(Capsule())
            } else {
                Image(systemName: icon)
                    .foregroundStyle(Color(red: 176 / 255, green: 176 / 255, blue: 176 / 255))
                    .font(.system(size: 24))
                    .frame(width: 72, height: 42)
            }
        }
    }
}

private enum DashboardTab {
    case history
    case add
    case profile
}

#Preview {
    HikeHistoryView()
}
