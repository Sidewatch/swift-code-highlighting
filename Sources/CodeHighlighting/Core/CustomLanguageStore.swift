import Foundation

/// A folder of user-authored ``CustomLanguageDefinition`` JSON files, loaded once and
/// re-fingerprinted on demand, answering "does a custom language claim this file?" by exact
/// filename first, then extension.
///
/// - Files load in filename order; the first definition to claim an extension or filename
///   wins, deterministically.
/// - A file that fails to decode is skipped and reported through `onSkip` with the author-
///   facing message from ``CustomLanguageDefinition/decode(from:)``.
/// - ``reloadIfChanged()`` re-fingerprints the folder (name + size + mtime of every `*.json`
///   — a folder-mtime check alone misses in-place saves) and reloads only when something moved.
public final class CustomLanguageStore {
    public let folder: URL
    private let onSkip: (String) -> Void

    /// Every successfully decoded definition, in load (filename) order.
    public private(set) var definitions: [CustomLanguageDefinition] = []
    private var byExtension: [String: CustomLanguageDefinition] = [:]
    private var byFilename: [String: CustomLanguageDefinition] = [:]
    private var lastFingerprint = ""

    /// Loads `folder` immediately. `onSkip` receives one line per file that could not be read
    /// or decoded (the host logs it however it likes).
    public init(folder: URL, onSkip: @escaping (String) -> Void = { _ in }) {
        self.folder = folder
        self.onSkip = onSkip
        load()
    }

    /// The definition claiming `url`, or nil. Exact filename claims (for extension-less files
    /// like `Jenkinsfile`) win over extension claims; both match case-insensitively.
    public func definition(for url: URL) -> CustomLanguageDefinition? {
        if let byName = byFilename[url.lastPathComponent.lowercased()] { return byName }
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        return byExtension[ext]
    }

    /// The custom display name for `url`, or nil when no definition claims it.
    public func displayName(for url: URL) -> String? { definition(for: url)?.name }

    /// Reloads when the folder's contents changed since the last load; returns whether it did.
    /// Cheap when nothing changed: one directory enumeration, no file reads.
    @discardableResult
    public func reloadIfChanged() -> Bool {
        guard Self.fingerprint(of: folder) != lastFingerprint else { return false }
        load()
        return true
    }

    /// Decodes every `*.json` in the folder (filename order).
    public func load() {
        lastFingerprint = Self.fingerprint(of: folder)
        definitions = []; byExtension = [:]; byFilename = [:]
        let files = ((try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? [])
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for file in files {
            guard let data = try? Data(contentsOf: file) else {
                onSkip("skipping custom language \"\(file.lastPathComponent)\" — the file could not be read."); continue
            }
            switch CustomLanguageDefinition.decode(from: data) {
            case .success(let definition):
                definitions.append(definition)
                for ext in definition.extensions {
                    let key = ext.lowercased()
                    if !key.isEmpty, byExtension[key] == nil { byExtension[key] = definition }
                }
                for name in definition.filenames ?? [] {
                    let key = name.lowercased()
                    if !key.isEmpty, byFilename[key] == nil { byFilename[key] = definition }
                }
            case .failure(let error):
                onSkip("skipping custom language \"\(file.lastPathComponent)\" — \(error.localizedDescription)")
            }
        }
    }

    /// Name + size + mtime of every `*.json` in `folder`, joined into one comparable string.
    /// Per file, not the folder's own mtime: an in-place save changes the file's mtime only.
    public static func fingerprint(of folder: URL) -> String {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])) ?? []
        return files
            .filter { $0.pathExtension.lowercased() == "json" }
            .map { url -> String in
                let values = try? url.resourceValues(forKeys: keys)
                let mtime = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
                return "\(url.lastPathComponent)|\(values?.fileSize ?? 0)|\(mtime)"
            }
            .sorted()
            .joined(separator: "\n")
    }

    /// Creates `folder` and copies `example` into it as `name` — only when the folder does not
    /// exist yet, so a user who deleted the example but kept the folder is left alone. Returns
    /// whether it seeded.
    @discardableResult
    public static func seedIfMissing(folder: URL, example: URL, as name: String) -> Bool {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard !fm.fileExists(atPath: folder.path, isDirectory: &isDirectory) else { return false }
        guard (try? fm.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else { return false }
        return (try? fm.copyItem(at: example, to: folder.appendingPathComponent(name))) != nil
    }
}
