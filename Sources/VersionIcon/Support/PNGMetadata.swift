import Foundation

/// Reading and writing of a custom `tEXt` metadata chunk in PNG files.
/// VersionIcon stores a fingerprint of all generation inputs in the generated icon,
/// so an unchanged icon is not rewritten (and does not show up as modified in git).
enum PNGMetadata {
    private static let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]

    private struct Chunk {
        var type: String
        var data: [UInt8]
    }

    /// Returns the text stored in the first `tEXt` chunk with the given keyword, if any.
    static func textChunk(in pngData: Data, keyword: String) -> String? {
        guard let chunks = chunks(in: pngData) else { return nil }

        for chunk in chunks where isTextChunk(chunk, keyword: keyword) {
            return String(bytes: chunk.data.dropFirst(keyword.utf8.count + 1), encoding: .utf8)
        }

        return nil
    }

    /// Returns a copy of the PNG with a `tEXt` chunk containing the given text inserted before `IEND`.
    /// An existing `tEXt` chunk with the same keyword is replaced.
    static func insertingTextChunk(into pngData: Data, keyword: String, text: String) -> Data? {
        guard var chunks = chunks(in: pngData), chunks.last?.type == "IEND" else { return nil }

        chunks.removeAll { isTextChunk($0, keyword: keyword) }
        chunks.insert(
            Chunk(type: "tEXt", data: [UInt8](keyword.utf8) + [0] + [UInt8](text.utf8)),
            at: chunks.count - 1
        )

        var result = Data(signature)
        for chunk in chunks {
            result.append(contentsOf: serialized(chunk))
        }
        return result
    }

    private static func isTextChunk(_ chunk: Chunk, keyword: String) -> Bool {
        let keywordBytes = [UInt8](keyword.utf8)
        return chunk.type == "tEXt"
            && chunk.data.count > keywordBytes.count
            && Array(chunk.data.prefix(keywordBytes.count)) == keywordBytes
            && chunk.data[keywordBytes.count] == 0
    }

    private static func chunks(in pngData: Data) -> [Chunk]? {
        let bytes = [UInt8](pngData)
        guard bytes.count >= signature.count, Array(bytes.prefix(signature.count)) == signature else { return nil }

        var chunks: [Chunk] = []
        var offset = signature.count

        while offset + 12 <= bytes.count {
            let length = Int(bytes[offset]) << 24
                | Int(bytes[offset + 1]) << 16
                | Int(bytes[offset + 2]) << 8
                | Int(bytes[offset + 3])
            guard offset + 12 + length <= bytes.count,
                  let type = String(bytes: bytes[(offset + 4) ..< (offset + 8)], encoding: .ascii)
            else { return nil }

            chunks.append(Chunk(type: type, data: Array(bytes[(offset + 8) ..< (offset + 8 + length)])))
            offset += 12 + length

            if type == "IEND" {
                break
            }
        }

        return chunks
    }

    private static func serialized(_ chunk: Chunk) -> [UInt8] {
        let typeBytes = [UInt8](chunk.type.utf8)
        var bytes = bigEndianBytes(UInt32(chunk.data.count))
        bytes += typeBytes
        bytes += chunk.data
        bytes += bigEndianBytes(crc32(typeBytes + chunk.data))
        return bytes
    }

    private static func bigEndianBytes(_ value: UInt32) -> [UInt8] {
        [
            UInt8(truncatingIfNeeded: value >> 24),
            UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value),
        ]
    }

    /// Standard PNG CRC-32 (reflected, polynomial 0xEDB88320).
    private static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0 ..< 8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}
