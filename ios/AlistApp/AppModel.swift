import Foundation
import Network
import SwiftUI
import Darwin

#if canImport(AlistCore)
import AlistCore
#endif

@MainActor
final class AppModel: ObservableObject {
    enum State: Equatable {
        case stopped
        case starting
        case running
        case failed(String)

        var label: String {
            switch self {
            case .stopped: return "已停止"
            case .starting: return "启动中…"
            case .running: return "运行中"
            case .failed(let message): return "错误：\(message)"
            }
        }
    }

    @Published private(set) var state: State = .stopped
    @Published private(set) var localURL = "http://127.0.0.1:5244"
    @Published private(set) var lanAddress = ""
    @Published var lanEnabled = false
    // WebDAV is part of the normal Alist HTTP surface; the heavier protocol
    // listeners stay opt-in to keep idle memory and socket usage low.
    @Published var webDAVEnabled = true
    @Published var s3Enabled = false
    @Published var ftpEnabled = false
    @Published var sftpEnabled = false
    @Published var keepAliveEnabled = false {
        didSet { keepAlive.setEnabled(keepAliveEnabled) }
    }
    @Published private(set) var memoryText = ""

#if canImport(AlistCore)
    private var runtime: IosbridgeRuntime?
#endif
    private let keepAlive = BackgroundKeepAliveController()
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "alist.network-monitor", qos: .utility)
    private var started = false

    init() {
        pathMonitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshLANAddress()
            }
        }
        pathMonitor.start(queue: monitorQueue)
        refreshLANAddress()
    }

    deinit {
        pathMonitor.cancel()
    }

    func start() {
        guard !started else { return }
        state = .starting
        do {
            let directories = try makeDirectories()
            let options: [String: Any] = [
                "dataDir": directories.data.path,
                "tempDir": directories.cache.path,
                "bindAddress": lanEnabled ? "0.0.0.0" : "127.0.0.1",
                "lanEnabled": lanEnabled,
                "port": 5244,
                "webdav": webDAVEnabled,
                "s3": s3Enabled,
                "ftp": ftpEnabled,
                "sftp": sftpEnabled,
                "memoryLimitBytes": 96 * 1024 * 1024
            ]
            let data = try JSONSerialization.data(withJSONObject: options)
            let json = String(decoding: data, as: UTF8.self)
#if canImport(AlistCore)
            var startError: NSError?
            guard let startedRuntime = IosbridgeStart(json, &startError) else {
                throw startError ?? NSError(domain: "AlistCore", code: 1,
                                             userInfo: [NSLocalizedDescriptionKey: "无法启动 Alist Runtime"])
            }
            runtime = startedRuntime
            localURL = runtime?.localURL() ?? "http://127.0.0.1:5244"
            started = true
            state = .running
#else
            state = .failed("AlistCore.xcframework 未生成")
#endif
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func stop() {
#if canImport(AlistCore)
        if let runtime { try? runtime.stop() }
        runtime = nil
#endif
        started = false
        state = .stopped
    }

    func toggleLAN(_ enabled: Bool) {
        lanEnabled = enabled
#if canImport(AlistCore)
        guard let runtime else { return }
        do {
            try runtime.setLANEnabled(enabled)
            refreshLANAddress()
        } catch {
            state = .failed(error.localizedDescription)
        }
#endif
    }

    func setWebDAVEnabled(_ enabled: Bool) {
        webDAVEnabled = enabled
        restartIfRunning()
    }

    func setS3Enabled(_ enabled: Bool) {
        s3Enabled = enabled
        restartIfRunning()
    }

    func setFTPEnabled(_ enabled: Bool) {
        ftpEnabled = enabled
        restartIfRunning()
    }

    func setSFTPEnabled(_ enabled: Bool) {
        sftpEnabled = enabled
        restartIfRunning()
    }

    private func restartIfRunning() {
        guard started else { return }
        stop()
        start()
    }

    func refreshMemory() {
#if canImport(AlistCore)
        guard let runtime else { return }
        memoryText = runtime.memoryStats()
#endif
    }

    private func makeDirectories() throws -> (data: URL, cache: URL) {
        let fm = FileManager.default
        let data = try fm.url(for: .applicationSupportDirectory,
                              in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Alist", isDirectory: true)
        let cache = try fm.url(for: .cachesDirectory,
                               in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Alist", isDirectory: true)
        try fm.createDirectory(at: data, withIntermediateDirectories: true)
        try fm.createDirectory(at: cache, withIntermediateDirectories: true)
        return (data, cache)
    }

    private func refreshLANAddress() {
        guard lanEnabled else {
            lanAddress = ""
            return
        }
        var address: String?
        var interfaceAddress: String?
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else {
            lanAddress = ""
            return
        }
        defer { freeifaddrs(interfaces) }
        for cursor in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(cursor.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0,
                  let addr = cursor.pointee.ifa_addr else { continue }
            if addr.pointee.sa_family == UInt8(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                var copy = addr.pointee
                getnameinfo(&copy, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                interfaceAddress = String(cString: host)
                break
            }
        }
        address = interfaceAddress
        lanAddress = address.map { "http://\($0):5244" } ?? ""
    }
}
