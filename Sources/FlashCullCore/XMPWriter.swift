import Foundation

public struct XMPWriteSummary: Sendable, Equatable {
    public let written: Int
    public let skippedExisting: Int
}

public enum XMPWriter {
    public static func sidecarURL(for imageURL: URL) -> URL {
        imageURL.deletingPathExtension().appendingPathExtension("xmp")
    }

    @discardableResult
    public static func write(
        results: [CullResult],
        overwriteExisting: Bool = false
    ) throws -> XMPWriteSummary {
        var written = 0
        var skipped = 0
        for result in results {
            let imageURL = URL(fileURLWithPath: result.path)
            let sidecar = sidecarURL(for: imageURL)
            if FileManager.default.fileExists(atPath: sidecar.path), !overwriteExisting {
                skipped += 1
                continue
            }
            let rating = result.rejected ? -1 : rating(for: result.score)
            let label = result.rejected ? "Red" : "Green"
            let packet = xmpPacket(rating: rating, label: label, reasons: result.reasons)
            try packet.write(to: sidecar, atomically: true, encoding: .utf8)
            written += 1
        }
        return XMPWriteSummary(written: written, skippedExisting: skipped)
    }

    public static func rating(for score: Double) -> Int {
        switch score {
        case 0.86...: 5
        case 0.72...: 4
        default: 3
        }
    }

    public static func xmpPacket(rating: Int, label: String, reasons: [CullReason]) -> String {
        let reasonText = reasons.map(\.rawValue).joined(separator: ",")
        return """
        <?xpacket begin="\u{FEFF}" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description rdf:about=""
              xmlns:xmp="http://ns.adobe.com/xap/1.0/"
              xmlns:flashcull="https://flashcull.local/ns/1.0/"
              xmp:Rating="\(rating)"
              xmp:Label="\(escape(label))"
              flashcull:Reasons="\(escape(reasonText))"/>
          </rdf:RDF>
        </x:xmpmeta>
        <?xpacket end="w"?>
        """
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
