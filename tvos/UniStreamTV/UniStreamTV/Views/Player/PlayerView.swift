import SwiftUI
import AVKit

/// Full-screen AVPlayer with native tvOS transport controls.
struct PlayerView: View {
    let channel: Channel
    let channels: [Channel]
    @Bindable var viewModel: PlayerViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var showOverlay = false

    private var isFav: Bool {
        appState.syncService.isFavorite(channel.streamId)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VideoPlayer(player: viewModel.player)
                .ignoresSafeArea()

            // Channel info overlay (shown briefly or on swipe)
            if showOverlay, let current = viewModel.currentChannel {
                VStack {
                    HStack {
                        Text(current.name)
                            .font(.headline)
                            .foregroundColor(.white)

                        Spacer()

                        Button {
                            appState.syncService.toggleFavorite(.from(channel: current))
                        } label: {
                            Image(systemName: appState.syncService.isFavorite(current.streamId) ? "heart.fill" : "heart")
                                .foregroundColor(appState.syncService.isFavorite(current.streamId) ? .red : .white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)

                    Spacer()
                }
                .transition(.move(edge: .top))
            }

            // Error overlay
            if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)

                    Text(error)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Button("Fermer") { dismiss() }
                }
                .padding(40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .onAppear {
            viewModel.play(channel: channel)
            flashOverlay()
        }
        .onDisappear {
            viewModel.stop()
        }
        .onMoveCommand { direction in
            switch direction {
            case .up:
                viewModel.playPrevious(in: channels)
                flashOverlay()
            case .down:
                viewModel.playNext(in: channels)
                flashOverlay()
            case .left, .right:
                flashOverlay()
            @unknown default:
                break
            }
        }
        .onPlayPauseCommand {
            if viewModel.player.timeControlStatus == .playing {
                viewModel.player.pause()
            } else {
                viewModel.player.play()
            }
        }
    }

    private func flashOverlay() {
        withAnimation { showOverlay = true }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { showOverlay = false }
        }
    }
}
