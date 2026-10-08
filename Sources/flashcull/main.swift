import FlashCullCore
import Foundation

@main
enum FlashCullCommand {
    static func main() async {
        do {
            try await run()
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first, ["cull", "benchmark"].contains(command), arguments.count >= 2 else {
            printUsage()
            exit(64)
        }
        let directory = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let workers = intOption("--workers", in: arguments)
            ?? max(1, ProcessInfo.processInfo.activeProcessorCount - 2)
        let limit = intOption("--limit", in: arguments)
        let configuration = CullingConfiguration(
            workerCount: workers,
            thumbnailSize: intOption("--thumbnail-size", in: arguments) ?? 512,
            analyzeFaces: !arguments.contains("--no-faces"),
            duplicateDistance: intOption("--duplicate-distance", in: arguments) ?? 6
        )
        let summary = try await CullingEngine(configuration: configuration).run(directory: directory, limit: limit)

        if command == "cull", arguments.contains("--write-xmp") {
            let xmp = try XMPWriter.write(
                results: summary.results,
                overwriteExisting: arguments.contains("--overwrite-existing-xmp")
            )
            print("XMP: \(xmp.written) written, \(xmp.skippedExisting) existing sidecars protected")
        }
        if let output = stringOption("--json", in: arguments) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(summary).write(to: URL(fileURLWithPath: output), options: .atomic)
        }
        printSummary(summary, command: command, workers: workers, faceAnalysis: configuration.analyzeFaces)
    }

    private static func printSummary(_ summary: RunSummary, command: String, workers: Int, faceAnalysis: Bool) {
        print("Mode: \(command)")
        print("Discovered: \(summary.discovered)")
        print("Analyzed: \(summary.analyzed)")
        print("Rejected: \(summary.rejected)")
        print("Duplicates: \(summary.duplicates)")
        print("Failures: \(summary.failures.count)")
        print(String(format: "Elapsed: %.3f s", summary.elapsedSeconds))
        print(String(format: "Throughput: %.2f photos/s", summary.photosPerSecond))
        print("Workers: \(workers)")
        print("Face analysis: \(faceAnalysis ? "on" : "off")")
        if !summary.failures.isEmpty {
            summary.failures.prefix(10).forEach { print("Failure: \($0)") }
        }
    }

    private static func intOption(_ name: String, in arguments: [String]) -> Int? {
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
        return Int(arguments[index + 1])
    }

    private static func stringOption(_ name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func printUsage() {
        print("""
        Usage:
          flashcull cull DIRECTORY [--write-xmp] [--overwrite-existing-xmp] [--json REPORT]
                                [--workers N] [--limit N] [--no-faces]
          flashcull benchmark DIRECTORY [--workers N] [--limit N] [--no-faces]

        Existing XMP files are never changed unless --overwrite-existing-xmp is supplied.
        Benchmark the same local folder and hardware when comparing another product.
        """)
    }
}
