import SwiftUI
import UIKit
import StoreKit

/// The core control screen. Every control below is rendered only if the connected device's probed
/// capabilities include it — no dead buttons. Taps register optimistically; a failure briefly
/// tints the control and updates the status pill rather than failing silently. See
/// docs/06-ux-screen-spec.md §6.
struct RemoteView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.requestReview) private var requestReview
    let deviceID: UUID

    @State private var controlMode: ControlMode = .dpad
    @State private var isKeyboardPresented = false
    @State private var isInputPromptPresented = false
    @State private var inputName = ""
    @State private var lastErrorMessage: String?
    @State private var isAddFavoritePresented = false

    private enum ControlMode { case dpad, touchpad }

    private var device: Device? {
        appState.devices.first { $0.id == deviceID }
    }

    var body: some View {
        Group {
            if let device {
                content(for: device)
            } else {
                ContentUnavailableView("Device Not Found", systemImage: "questionmark.circle")
            }
        }
        .background(Color.remoteBackground.ignoresSafeArea())
        .task {
            await appState.refreshStatus(for: deviceID)
            // Once per visit (not per command — see `AppState.markRemoteScreenVisited`), and never
            // during setup or an error state, per docs/06-ux-screen-spec.md's review-prompt rule.
            if appState.markRemoteScreenVisited() {
                requestReview()
            }
        }
    }

    /// Reduced remote for Settings ▸ Accessibility ▸ Simplified/Guest Mode: power, volume,
    /// navigation, and home/back only. Hides the keyboard, menu, color keys, channel controls,
    /// favorites, and input selection — not because the device lacks them, but because guest mode
    /// asks for a deliberately smaller surface. See `AppSettings.simplifiedGuestMode`.
    private var isSimplified: Bool {
        appState.settings.simplifiedGuestMode
    }

    /// Mirrors the linear control rows for left-handed use. Applied only to those rows (not the
    /// D-pad/touchpad navigation area — see `AppSettings.leftHandedLayout`).
    private var leftHandedDirection: LayoutDirection {
        appState.settings.leftHandedLayout ? .rightToLeft : .leftToRight
    }

    @ViewBuilder
    private func content(for device: Device) -> some View {
        ScrollView {
            VStack(spacing: RelaySpacing.xl) {
                header(for: device)

                if device.supports(.powerOn) || (!isSimplified && device.supports(.inputSelect)) {
                    topRow(for: device)
                        .environment(\.layoutDirection, leftHandedDirection)
                }

                if device.supports(.dpad) || device.supports(.touchpad) {
                    navigationArea(for: device)
                }

                if device.supports(.playback) {
                    playbackRow(for: device)
                        .environment(\.layoutDirection, leftHandedDirection)
                }

                if device.supports(.volume) {
                    volumeRow(for: device)
                        .environment(\.layoutDirection, leftHandedDirection)
                }

                if device.supports(.homeButton) || device.supports(.backButton) || (!isSimplified && device.supports(.menuButton)) {
                    homeBackRow(for: device)
                        .environment(\.layoutDirection, leftHandedDirection)
                }

                if !isSimplified && device.supports(.colorKeys) {
                    colorKeyRow(for: device)
                        .environment(\.layoutDirection, leftHandedDirection)
                }

                if !isSimplified && device.supports(.channelControl) {
                    channelPad(for: device)
                }

                if !isSimplified && device.supports(.channelFavorites) {
                    favoritesSection(for: device)
                }

                if !isSimplified && device.supports(.keyboardInput) {
                    Button {
                        isKeyboardPresented = true
                    } label: {
                        Label("Keyboard", systemImage: "keyboard")
                    }
                    .buttonStyle(RelaySecondaryButtonStyle())
                }

                if let lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(.relayCaption)
                        .foregroundStyle(Color.relayStatusUnavailable)
                }
            }
            .padding(RelaySpacing.lg)
        }
        .environment(\.relayLargeButtonMode, appState.settings.largeButtonMode)
        .sheet(isPresented: $isKeyboardPresented) {
            KeyboardInputSheet(deviceID: device.id)
        }
        .alert("Select Input", isPresented: $isInputPromptPresented) {
            TextField("Input name", text: $inputName)
            Button("Cancel", role: .cancel) {}
            Button("Select") {
                Task { await sendCommand(.selectInput(inputName), on: device) }
            }
        }
        .sheet(isPresented: $isAddFavoritePresented) {
            AddChannelFavoriteSheet(deviceID: device.id)
        }
    }

    private func header(for device: Device) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.relayHeadline)
                    .foregroundStyle(Color.remoteTextPrimary)
                StatusPill(status: device.status)
            }
            Spacer()
            // Unconditional — AirPlay casting works with any receiver regardless of this
            // device's adapter/capabilities. See docs/02-capability-matrix.md.
            AirPlayCastButton(tintColor: UIColor(Color.remoteTextSecondary))
                .frame(width: 28, height: 28)
                .accessibilityLabel("Cast with AirPlay")
            NavigationLink {
                ReliabilityCenterView(deviceID: device.id)
            } label: {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(Color.remoteTextSecondary)
            }
            .accessibilityLabel("Reliability Center")
        }
    }

    private func topRow(for device: Device) -> some View {
        HStack(spacing: RelaySpacing.lg) {
            if device.supports(.powerOn) {
                RemoteButton(systemImage: "power", isPrimary: true) {
                    await sendCommand(.powerToggle, on: device)
                }
                .accessibilityLabel("Power")
            }
            if !isSimplified && device.supports(.inputSelect) {
                Button {
                    isInputPromptPresented = true
                } label: {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.title2)
                }
                .buttonStyle(RelayRemoteControlButtonStyle())
                .accessibilityLabel("Select input")
            }
        }
    }

    private func navigationArea(for device: Device) -> some View {
        VStack(spacing: RelaySpacing.md) {
            if device.supports(.dpad) && device.supports(.touchpad) {
                Picker("Control mode", selection: $controlMode) {
                    Text("D-Pad").tag(ControlMode.dpad)
                    Text("Touchpad").tag(ControlMode.touchpad)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            if controlMode == .dpad && device.supports(.dpad) {
                DPadView { direction in
                    await sendCommand(.dpad(direction), on: device)
                }
            } else if device.supports(.touchpad) {
                TouchpadView(
                    onMove: { dx, dy in await sendCommand(.touchpadMove(dx: dx, dy: dy), on: device) },
                    onTap: { await sendCommand(.touchpadTap, on: device) }
                )
            }
        }
    }

    private func playbackRow(for device: Device) -> some View {
        HStack(spacing: RelaySpacing.lg) {
            RemoteButton(systemImage: "backward.fill") { await sendCommand(.rewind, on: device) }
                .accessibilityLabel("Rewind")
            RemoteButton(systemImage: "playpause.fill", isPrimary: true) { await sendCommand(.play, on: device) }
                .accessibilityLabel("Play or pause")
            RemoteButton(systemImage: "forward.fill") { await sendCommand(.fastForward, on: device) }
                .accessibilityLabel("Fast forward")
        }
    }

    private func volumeRow(for device: Device) -> some View {
        HStack(spacing: RelaySpacing.lg) {
            RemoteButton(systemImage: "speaker.minus.fill") { await sendCommand(.volumeDown, on: device) }
                .accessibilityLabel("Volume down")
            if device.supports(.mute) {
                RemoteButton(systemImage: "speaker.slash.fill") { await sendCommand(.mute, on: device) }
                    .accessibilityLabel("Mute")
            }
            RemoteButton(systemImage: "speaker.plus.fill") { await sendCommand(.volumeUp, on: device) }
                .accessibilityLabel("Volume up")
        }
    }

    private func homeBackRow(for device: Device) -> some View {
        HStack(spacing: RelaySpacing.lg) {
            if device.supports(.backButton) {
                RemoteButton(systemImage: "chevron.left") { await sendCommand(.back, on: device) }
                    .accessibilityLabel("Back")
            }
            if device.supports(.homeButton) {
                RemoteButton(systemImage: "house.fill") { await sendCommand(.home, on: device) }
                    .accessibilityLabel("Home")
            }
            if !isSimplified && device.supports(.menuButton) {
                RemoteButton(systemImage: "line.3.horizontal") { await sendCommand(.menu, on: device) }
                    .accessibilityLabel("Menu")
            }
        }
    }

    /// Cable-box-style red/green/yellow/blue keys — never offered for Roku, whose ECP has no
    /// keypress equivalent (see docs/02-capability-matrix.md).
    private func colorKeyRow(for device: Device) -> some View {
        HStack(spacing: RelaySpacing.md) {
            ForEach(ColorKey.allCases, id: \.self) { colorKey in
                Button {
                    Task { await sendCommand(.colorKey(colorKey), on: device) }
                } label: {
                    Circle()
                        .fill(swiftUIColor(for: colorKey))
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("\(colorKey.rawValue.capitalized) key")
            }
        }
    }

    private func swiftUIColor(for colorKey: ColorKey) -> Color {
        switch colorKey {
        case .red: .relayStatusUnavailable
        case .green: .relayStatusConnected
        case .yellow: .relayStatusSleeping
        case .blue: .relayAccent
        }
    }

    private func channelPad(for device: Device) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: RelaySpacing.sm) {
            ForEach(0...9, id: \.self) { digit in
                RemoteButton(text: "\(digit)") { await sendCommand(.channelDigit(digit), on: device) }
            }
        }
        .frame(maxWidth: 220)
    }

    private func favoritesSection(for device: Device) -> some View {
        VStack(alignment: .leading, spacing: RelaySpacing.sm) {
            HStack {
                Text("Favorites")
                    .font(.relayCaption)
                    .foregroundStyle(Color.remoteTextSecondary)
                Spacer()
                Button {
                    isAddFavoritePresented = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.relayAccent)
                }
                .accessibilityLabel("Add favorite")
            }

            if device.channelFavorites.isEmpty {
                Text("No favorites yet.")
                    .font(.relayCaption)
                    .foregroundStyle(Color.remoteTextSecondary)
            } else {
                FlowLayout(spacing: RelaySpacing.sm) {
                    ForEach(device.channelFavorites) { favorite in
                        Button {
                            Task { await tuneToFavorite(favorite, on: device) }
                        } label: {
                            Text(favorite.label)
                                .font(.relaySubheadline)
                                .foregroundStyle(Color.remoteTextPrimary)
                                .padding(.horizontal, RelaySpacing.md)
                                .padding(.vertical, RelaySpacing.sm)
                                .background(Capsule().fill(Color.remoteSurface))
                        }
                        .contextMenu {
                            Button("Remove", role: .destructive) {
                                Task { await appState.removeChannelFavorite(favorite.id, fromDeviceID: device.id) }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 260, alignment: .leading)
    }

    private func tuneToFavorite(_ favorite: ChannelFavorite, on device: Device) async {
        HapticsHelper.shared.controlTap()
        do {
            try await appState.tuneToFavorite(favorite, onDeviceID: device.id)
            lastErrorMessage = nil
        } catch {
            HapticsHelper.shared.commandFailed()
            lastErrorMessage = "That command didn't go through. Check the device's connection."
            await appState.refreshStatus(for: device.id)
        }
    }

    private func sendCommand(_ command: RemoteCommand, on device: Device) async {
        HapticsHelper.shared.controlTap()
        do {
            try await appState.send(command, toDeviceID: device.id)
            lastErrorMessage = nil
        } catch {
            HapticsHelper.shared.commandFailed()
            lastErrorMessage = "That command didn't go through. Check the device's connection."
            await appState.refreshStatus(for: device.id)
        }
    }
}

/// A single remote control button — wraps `RelayRemoteControlButtonStyle` so every control call
/// site doesn't repeat the async-action/haptic boilerplate.
private struct RemoteButton: View {
    var systemImage: String?
    var text: String?
    var isPrimary: Bool = false
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                } else if let text {
                    Text(text).font(.relayMonospacedDigits)
                }
            }
        }
        .buttonStyle(RelayRemoteControlButtonStyle(isPrimary: isPrimary))
    }
}
