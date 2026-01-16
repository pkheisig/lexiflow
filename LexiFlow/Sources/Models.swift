import Foundation

struct Card: Identifiable, Equatable {
    let id = UUID()
    let term: String
    let definition: String
    var isStarred: Bool = false
}

struct CSVData {
    var headers: [String]
    var rows: [[String]]
}

class CSVParser {
    static func parse(url: URL) -> CSVData {
        guard let content = try? String(contentsOf: url) else { return CSVData(headers: [], rows: []) }
        return parse(content: content)
    }
    
    static func parse(content: String) -> CSVData {
        let lines = content.components(separatedBy: .newlines)
        var rows: [[String]] = []
        
        for line in lines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            
            // Split by comma and trim whitespace
            var parts = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            // Remove empty trailing columns (from trailing commas)
            while let last = parts.last, last.isEmpty, parts.count > 1 {
                parts.removeLast()
            }
            
            if !parts.isEmpty && !(parts.count == 1 && parts[0].isEmpty) {
                rows.append(parts)
            }
        }
        
        guard !rows.isEmpty else { return CSVData(headers: [], rows: []) }
        
        // Determine expected column count from header
        let headers = rows[0]
        let expectedCols = headers.count
        
        // Normalize data rows to match header column count
        var dataRows = Array(rows.dropFirst())
        for i in 0..<dataRows.count {
            // Trim excess columns
            if dataRows[i].count > expectedCols {
                dataRows[i] = Array(dataRows[i].prefix(expectedCols))
            }
            // Pad missing columns
            while dataRows[i].count < expectedCols {
                dataRows[i].append("")
            }
        }
        
        return CSVData(headers: headers, rows: dataRows)
    }
}
