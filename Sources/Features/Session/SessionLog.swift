import Foundation
import os

@MainActor
enum SessionLog {
    static let fileName = "session.log"
    private static let logger = Logger(subsystem: "com.tango.spacewalker", category: "filelog")
    private static let limit = 128 * 1024

    static var fileURL: URL {
        URL.documentsDirectory.appending(path: fileName)
    }

    static func reset(context: String) {
        try? FileManager.default.removeItem(at: fileURL)
        append("# \(context)")
    }

    static func deviceContext() -> String {
        var info = utsname()
        uname(&info)
        let machine = withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        let system = ProcessInfo.processInfo.operatingSystemVersionString
        return "\(machine) | \(system) | app \(version)(\(build)) | bundle \(bundle.bundleIdentifier ?? "-")"
    }

    static func append(_ message: String) {
        let line = "[\(AppClock.elapsedMilliseconds())ms] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        do {
            if !FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) {
                try data.write(to: fileURL)
                return
            }
            if let size = try FileManager.default.attributesOfItem(atPath: fileURL.path(percentEncoded: false))[.size] as? Int,
               size > limit {
                try data.write(to: fileURL)
                return
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            logger.error("session log write failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
