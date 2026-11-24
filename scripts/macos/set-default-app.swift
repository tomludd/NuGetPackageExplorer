// Makes the given app the default for the given file extensions.
// Usage: swift set-default-app.swift <path-to-app> <ext> [<ext> ...]
import AppKit
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("Usage: set-default-app.swift <app> <ext>...\n".data(using: .utf8)!)
    exit(2)
}

let appURL = URL(fileURLWithPath: args[1])
var failed = false

for ext in args.dropFirst(2) {
    guard let type = UTType(filenameExtension: ext) else {
        print("No type for .\(ext)")
        failed = true
        continue
    }

    let done = DispatchSemaphore(value: 0)
    NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: type) { error in
        if let error {
            print("Failed for .\(ext) (\(type.identifier)): \(error.localizedDescription)")
            failed = true
        } else {
            print("Default app for .\(ext) (\(type.identifier)) set")
        }
        done.signal()
    }
    done.wait()
}

exit(failed ? 1 : 0)
