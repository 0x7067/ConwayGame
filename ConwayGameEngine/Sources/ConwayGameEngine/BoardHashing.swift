import Foundation

public enum BoardHashing: Sendable {
    /// Convert grid to compact string hash (bit-packed then base64)
    public static func hash(for cells: CellsGrid) -> String {
        let height = cells.count
        let width = height > 0 ? cells[0].count : 0
        if width == 0 || height == 0 { return "" }
        let bitCount = width * height
        var bytes = [UInt8](repeating: 0, count: (bitCount + 7) / 8)
        var bitIndex = 0
        for row in 0..<height {
            for col in 0..<width {
                if cells[row][col] {
                    let byteIndex = bitIndex / 8
                    let bitInByte = UInt8(7 - (bitIndex % 8))
                    bytes[byteIndex] |= (1 << bitInByte)
                }
                bitIndex += 1
            }
        }
        return Data(bytes).base64EncodedString()
    }
}
