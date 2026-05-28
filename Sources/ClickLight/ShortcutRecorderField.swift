import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutRecorderField: View {
    let label: String
    let subtitle: String
    let currentBinding: HotKeyBinding
    let defaultBinding: HotKeyBinding
    let errorMessage: String?
    let onRecord: (HotKeyBinding) -> Bool
    let onReset: () -> Void

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    private var isCustom: Bool {
        currentBinding != defaultBinding
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.callout.weight(.medium))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                if isRecording {
                    Text("Press shortcut...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityLabel("Waiting for shortcut input")

                    Button("Cancel") {
                        stopRecording()
                    }
                    .buttonStyle(.bordered)
                    .help("Cancel shortcut recording.")
                } else {
                    Text(currentBinding.displayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityLabel("Current shortcut: \(currentBinding.displayString)")

                    Button("Record") {
                        startRecording()
                    }
                    .buttonStyle(.bordered)
                    .help("Record a new shortcut.")

                    if isCustom {
                        Button("Reset") {
                            onReset()
                        }
                        .buttonStyle(.bordered)
                        .help("Reset this shortcut to default.")
                    }
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityLabel(errorMessage)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            let code = Int(event.keyCode)

            if code == kVK_Escape {
                stopRecording()
                return nil
            }

            let modifierOnlyCodes: Set<Int> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            guard !modifierOnlyCodes.contains(code) else {
                return event
            }

            let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard !flags.isEmpty else {
                NSSound.beep()
                stopRecording()
                return nil
            }

            let accepted = onRecord(HotKeyBinding(
                keyCode: code,
                carbonModifiers: HotKeyBinding.carbonModifiers(from: flags)
            ))
            if !accepted {
                NSSound.beep()
            }
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
