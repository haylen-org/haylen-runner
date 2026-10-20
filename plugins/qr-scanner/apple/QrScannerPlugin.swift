import AVFoundation
import Foundation
import UIKit

// Native part of the QR Scanner plugin on iPhones, iPads and Macs, which shows the camera over the app until it reads a QR code. The runtime creates it by the class name that `plugin.json` gives, and loads it while the app launches. It owns the permission `camera`, which AVFoundation reads and asks for once the `Info.plist` gives the text of its prompt.
@objc(QrScannerPlugin)
final class QrScannerPlugin: NSObject, HaylenPlugin {
    struct Empty: Codable {}

    struct Scanned: Encodable {
        let text: String
    }

    func load(with context: HaylenPluginContext) {
        context.register(QrScannerPlugin.cameraPermission())
        context.register("scan") { (_: Empty) async throws -> Scanned in
            guard AVCaptureDevice.default(for: .video) != nil else {
                throw HaylenFailure("This device has no camera.", code: "unsupported")
            }
            try await context.requirePermission("camera")
            guard let presenter = context.viewController else {
                throw HaylenFailure("The app has no window yet.", code: "noWindow")
            }
            context.coverApp()
            defer { context.uncoverApp() }
            return Scanned(text: try await QrScannerController.scan(from: presenter))
        }
    }

    private static func cameraPermission() -> HaylenPermission {
        HaylenPermission(name: "camera", capability: "the camera", requirements: [.usageDescription("NSCameraUsageDescription")], state: { answer in
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .notDetermined:
                answer(.prompt, nil)
            case .authorized:
                answer(.granted, nil)
            case .denied, .restricted:
                answer(.denied, nil)
            @unknown default:
                answer(.unknown, nil)
            }
        }, request: { answer in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                answer(granted ? .granted : .denied, nil)
            }
        })
    }
}

// The camera over the whole screen with a Cancel button, which ends with the text of the first QR code it reads.
@MainActor
final class QrScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private var finish: ((Result<String, Error>) -> Void)?

    static func scan(from presenter: UIViewController) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let controller = QrScannerController()
            controller.modalPresentationStyle = .fullScreen
            controller.finish = { result in
                controller.dismiss(animated: true)
                continuation.resume(with: result)
            }
            presenter.present(controller, animated: true)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            end(.failure(HaylenFailure("The camera cannot start.", code: "unsupported")))
            return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            end(.failure(HaylenFailure("The camera cannot read codes.", code: "unsupported")))
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)

        var configuration = UIButton.Configuration.filled()
        configuration.title = "Cancel"
        configuration.cornerStyle = .capsule
        let cancel = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            self?.end(.failure(HaylenFailure("The scan was cancelled.", code: "cancelled")))
        })
        cancel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancel)
        NSLayoutConstraint.activate([cancel.centerXAnchor.constraint(equalTo: view.centerXAnchor), cancel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)])
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.first { $0 is AVCaptureVideoPreviewLayer }?.frame = view.bounds
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let code = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first?.stringValue else {
            return
        }
        MainActor.assumeIsolated {
            self.end(.success(code))
        }
    }

    private func end(_ result: Result<String, Error>) {
        guard let finish else {
            return
        }
        self.finish = nil
        session.stopRunning()
        finish(result)
    }
}
