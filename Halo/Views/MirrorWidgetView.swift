import SwiftUI
import AVFoundation

@MainActor
final class MirrorCameraService: ObservableObject {
    enum State: Equatable { case idle, requesting, ready, denied, unavailable, failed }

    static let shared = MirrorCameraService()
    @Published private(set) var state: State = .idle
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "Halo.MirrorCamera", qos: .userInitiated)
    private var configured = false
    private var requested = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            guard !requested else { return }
            requested = true
            state = .requesting
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted { self.configureAndStart() }
                    else { self.state = .denied }
                }
            }
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .failed
        }
    }

    private func configureAndStart() {
        state = .requesting
        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .medium
                defer { self.session.commitConfiguration() }

                guard let device = AVCaptureDevice.default(for: .video),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    Task { @MainActor in self.state = .unavailable }
                    return
                }
                self.session.addInput(input)
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            Task { @MainActor in self.state = self.session.isRunning ? .ready : .failed }
        }
    }
}

private final class MirrorPreviewNSView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}

private struct MirrorPreviewRepresentable: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> MirrorPreviewNSView {
        let view = MirrorPreviewNSView(frame: .zero)
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ nsView: MirrorPreviewNSView, context: Context) {
        if nsView.previewLayer.session !== session { nsView.previewLayer.session = session }
    }
}

struct MirrorWidgetView: View {
    @ObservedObject private var camera = MirrorCameraService.shared

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.055))

            switch camera.state {
            case .ready:
                MirrorPreviewRepresentable(session: camera.session)
            case .idle, .requesting:
                ProgressView().controlSize(.mini)
            case .denied:
                Image(systemName: "video.slash.fill").foregroundStyle(.secondary)
            case .unavailable:
                Image(systemName: "camera.metering.unknown").foregroundStyle(.secondary)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task { camera.start() }
        .accessibilityLabel("Mirror")
    }
}
