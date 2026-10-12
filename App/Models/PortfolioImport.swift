import Foundation

/// One position found in an imported file.
struct ImportedPosition: Identifiable, Hashable {
  var id = UUID()
  /// The ticker as written in the file, or an ISIN when that's all the broker gives.
  var rawSymbol: String
  var name: String
  var shares: Double
  var averageCost: Double
  /// The Yahoo ticker after checking it exists. Nil until resolved, or when it couldn't be found.
  var symbol: String?
  var isIncluded = true
}

/// Reads holdings from CSV exports of common brokers, or any spreadsheet with a ticker and a quantity.
/// Handles positions files (one row per holding) and transaction histories (buys and sells, which are added up).
enum PortfolioImport {
  enum ImportError: LocalizedError {
    case empty
    case noColumns
    case noPositions

    var errorDescription: String? {
      switch self {
      case .empty: "The file is empty."
      case .noColumns: "Couldn't find a ticker and a quantity column. Make sure the file has headers like Symbol and Quantity."
      case .noPositions: "No open positions were found in this file."
      }
    }
  }

  /// Brokers with known export formats, shown as help in the import screen.
  struct Broker: Identifiable {
    var name: String
    var steps: String
    var id: String { name }

    static let all: [Broker] = [
      Broker(name: "Robinhood", steps: "Account → Reports and statements → Reports. Generate an account activity report and download the CSV."),
      Broker(name: "Fidelity", steps: "Open Positions, tap the download icon, and choose CSV."),
      Broker(name: "Charles Schwab", steps: "Open Positions and choose Export. Save the CSV file."),
      Broker(name: "Vanguard", steps: "Open Holdings and choose Download. Pick CSV."),
      Broker(name: "E*TRADE", steps: "Portfolios → Positions, then the download icon. Save as CSV."),
      Broker(name: "Interactive Brokers", steps: "Performance & Reports → Statements. Run an Activity statement as CSV, or a Flex Query with open positions."),
      Broker(name: "Trading 212", steps: "Menu → History → Export history. Pick the full date range and download the CSV."),
      Broker(name: "DEGIRO", steps: "Portfolio → Export. Choose CSV."),
      Broker(name: "Any spreadsheet", steps: "Use columns named Symbol, Shares, and Average cost, then export or copy as CSV."),
    ]
  }

  // MARK: Parsing

  static func parse(_ text: String) throws -> [ImportedPosition] {
    let cleaned = text.replacingOccurrences(of: "\u{FEFF}", with: "")
    let lines = cleaned.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    guard !lines.isEmpty else { throw ImportError.empty }

    // Some brokers put a title or account summary above the real header, so look for it.
    for (index, line) in lines.prefix(40).enumerated() {
      let delimiter = detectDelimiter(line)
      let headers = split(line, delimiter: delimiter).map(normalized)
      guard let columns = Columns(headers: headers) else { continue }
      let rows = lines.dropFirst(index + 1).map { split($0, delimiter: delimiter) }
      // A "Type" column can mean buy/sell history or just an account type, so try history first.
      let history = columns.action == nil ? [] : transactionRows(rows, columns: columns)
      let positions = history.isEmpty ? positionRows(rows, columns: columns) : history
      guard !positions.isEmpty else { throw ImportError.noPositions }
      return positions
    }
    throw ImportError.noColumns
  }

  /// Which column holds what, matched by common header names across brokers.
  private struct Columns {
    var symbol: Int
    var isin: Int?
    var name: Int?
    var shares: Int
    var averageCost: Int?
    var totalCost: Int?
    var price: Int?
    var action: Int?

    init?(headers: [String]) {
      func find(_ names: [String]) -> Int? {
        for name in names { if let index = headers.firstIndex(of: name) { return index } }
        return nil
      }
      let symbol = find(["symbol", "ticker", "ticker symbol", "instrument symbol", "symbol/isin", "security symbol", "code", "instrument"])
      let isin = find(["isin", "isin code"])
      guard let ticker = symbol ?? isin,
            let shares = find(["quantity", "qty", "shares", "no. of shares", "number of shares", "units", "position", "quantity (shares)", "share quantity"])
      else { return nil }
      self.symbol = ticker
      self.isin = isin
      self.shares = shares
      name = find(["description", "name", "security description", "security name", "product", "instrument name", "company", "security"])
      averageCost = find(["average cost", "avg cost", "average price", "avg price", "average cost basis", "avg. cost", "cost/share", "cost per share",
                          "cost basis per share", "average purchase price", "unit cost", "purchase price", "average cost per share", "avg cost/share", "cost price"])
      totalCost = find(["cost basis", "cost basis total", "total cost", "total cost basis", "book cost", "book value", "cost basis (total)", "invested"])
      price = find(["price", "price / share", "price per share", "trade price", "t. price", "execution price"])
      action = find(["action", "type", "trans code", "transaction type", "side", "activity", "buy/sell", "transaction"])
    }
  }

  private static func positionRows(_ rows: [[String]], columns: Columns) -> [ImportedPosition] {
    var positions: [ImportedPosition] = []
    for row in rows {
      guard let raw = cleanSymbol(value(row, columns.symbol), isin: columns.isin.map { value(row, $0) }),
            let shares = number(value(row, columns.shares)), shares > 0 else { continue }
      var cost = columns.averageCost.flatMap { number(value(row, $0)) } ?? 0
      if cost <= 0, let total = columns.totalCost.flatMap({ number(value(row, $0)) }), total > 0 { cost = total / shares }
      let name = columns.name.map { value(row, $0) } ?? ""
      positions.append(ImportedPosition(rawSymbol: raw, name: name, shares: shares, averageCost: max(0, cost)))
    }
    return merged(positions)
  }

  /// Adds up buys and sells per ticker. The average cost is the average buy price, so row order doesn't matter.
  private static func transactionRows(_ rows: [[String]], columns: Columns) -> [ImportedPosition] {
    var books: [String: (name: String, bought: Double, sold: Double, cost: Double)] = [:]
    var order: [String] = []
    for row in rows {
      guard let action = columns.action.map({ value(row, $0).lowercased() }),
            let raw = cleanSymbol(value(row, columns.symbol), isin: columns.isin.map { value(row, $0) }),
            let quantity = number(value(row, columns.shares)).map(abs), quantity > 0 else { continue }
      let isBuy = action.contains("buy") || action == "bot" || action.contains("bought")
      let isSell = action.contains("sell") || action == "sld" || action.contains("sold")
      guard isBuy || isSell else { continue }
      let price = columns.price.flatMap { number(value(row, $0)).map(abs) } ?? 0
      if books[raw] == nil { order.append(raw) }
      var book = books[raw] ?? (columns.name.map { value(row, $0) } ?? "", 0, 0, 0)
      if isBuy {
        book.bought += quantity
        book.cost += quantity * price
      } else {
        book.sold += quantity
      }
      books[raw] = book
    }
    return order.compactMap { symbol in
      guard let book = books[symbol], book.bought - book.sold > 0.000_001 else { return nil }
      let average = book.bought > 0 ? book.cost / book.bought : 0
      return ImportedPosition(rawSymbol: symbol, name: book.name, shares: book.bought - book.sold, averageCost: average)
    }
  }

  /// Combines the same ticker held in several accounts, with a weighted average cost.
  private static func merged(_ positions: [ImportedPosition]) -> [ImportedPosition] {
    var result: [ImportedPosition] = []
    for position in positions {
      if let index = result.firstIndex(where: { $0.rawSymbol == position.rawSymbol }) {
        let existing = result[index]
        let shares = existing.shares + position.shares
        result[index].averageCost = shares > 0 ? (existing.averageCost * existing.shares + position.averageCost * position.shares) / shares : 0
        result[index].shares = shares
      } else {
        result.append(position)
      }
    }
    return result
  }

  // MARK: Cleaning

  private static func cleanSymbol(_ text: String, isin: String?) -> String? {
    var symbol = text.trimmingCharacters(in: .whitespaces).uppercased()
    // Fidelity marks cash sweep funds with asterisks.
    if symbol.hasSuffix("**") { return nil }
    symbol = symbol.trimmingCharacters(in: CharacterSet(charactersIn: "*"))
    let lowered = symbol.lowercased()
    let skipped = ["cash", "pending", "total", "account", "usd", "eur", "gbp", "money market", "--"]
    if symbol.isEmpty || skipped.contains(where: { lowered.hasPrefix($0) }) || symbol.contains(" ") {
      if let isin, isISIN(isin.trimmingCharacters(in: .whitespaces).uppercased()) { return isin.trimmingCharacters(in: .whitespaces).uppercased() }
      return nil
    }
    return symbol
  }

  static func isISIN(_ text: String) -> Bool {
    text.count == 12 && text.prefix(2).allSatisfy(\.isLetter) && text.dropFirst(2).allSatisfy { $0.isLetter || $0.isNumber } && text.last?.isNumber == true
  }

  private static func normalized(_ header: String) -> String {
    header.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\"")))
      .lowercased()
      .replacingOccurrences(of: "  ", with: " ")
  }

  private static func value(_ row: [String], _ index: Int) -> String {
    row.indices.contains(index) ? row[index].trimmingCharacters(in: .whitespaces) : ""
  }

  /// Reads "1,234.56", "1.234,56", "$1,234", "(12.50)", and "12 shares".
  static func number(_ text: String) -> Double? {
    var string = text.trimmingCharacters(in: .whitespaces)
    let isNegative = string.hasPrefix("(") && string.hasSuffix(")") || string.hasPrefix("-")
    string = string.filter { $0.isNumber || $0 == "." || $0 == "," }
    guard !string.isEmpty else { return nil }
    let lastComma = string.lastIndex(of: ",")
    let lastDot = string.lastIndex(of: ".")
    if let lastComma, let lastDot {
      // The later separator is the decimal one.
      if lastComma > lastDot {
        string = string.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
      } else {
        string = string.replacingOccurrences(of: ",", with: "")
      }
    } else if let lastComma {
      // "1,234" is a thousands separator; "12,5" is a decimal comma.
      let decimals = string.distance(from: lastComma, to: string.endIndex) - 1
      string = decimals == 3 && string.filter({ $0 == "," }).count >= 1 && string.first != "0"
        ? string.replacingOccurrences(of: ",", with: "")
        : string.replacingOccurrences(of: ",", with: ".")
    }
    guard let value = Double(string) else { return nil }
    return isNegative ? -value : value
  }

  private static func detectDelimiter(_ line: String) -> Character {
    let candidates: [Character] = [",", ";", "\t", "|"]
    return candidates.max { lhs, rhs in line.filter { $0 == lhs }.count < line.filter { $0 == rhs }.count } ?? ","
  }

  /// Splits one CSV line, respecting quoted fields that contain the delimiter.
  private static func split(_ line: String, delimiter: Character) -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuotes = false
    var iterator = line.makeIterator()
    while let character = iterator.next() {
      if character == "\"" {
        inQuotes.toggle()
      } else if character == delimiter && !inQuotes {
        fields.append(current)
        current = ""
      } else {
        current.append(character)
      }
    }
    fields.append(current)
    return fields
  }

  /// Reads a file in the encodings brokers commonly use.
  static func text(from data: Data) -> String? {
    for encoding in [String.Encoding.utf8, .utf16, .windowsCP1252, .isoLatin1] {
      if let text = String(data: data, encoding: encoding), !text.isEmpty { return text }
    }
    return nil
  }

  // MARK: Resolving

  /// Checks each ticker exists, turning ISINs into tickers and fixing share classes like BRK.B.
  static func resolve(_ positions: [ImportedPosition]) async -> [ImportedPosition] {
    let service = QuoteService()
    return await withTaskGroup(of: (Int, String?, String?).self) { group in
      for (index, position) in positions.enumerated() {
        group.addTask {
          for candidate in await candidates(for: position.rawSymbol, service: service) {
            if let quote = try? await service.quote(for: candidate) {
              return (index, candidate, quote.name)
            }
          }
          return (index, nil, nil)
        }
      }
      var resolved = positions
      for await (index, symbol, name) in group {
        resolved[index].symbol = symbol
        resolved[index].isIncluded = symbol != nil
        if let name, !name.isEmpty, resolved[index].name.isEmpty { resolved[index].name = name }
      }
      return resolved
    }
  }

  private static func candidates(for raw: String, service: QuoteService) async -> [String] {
    if isISIN(raw) {
      let matches = (try? await service.search(raw)) ?? []
      return Array(matches.prefix(2).map(\.symbol))
    }
    var list = [raw]
    if raw.contains(".") || raw.contains("/") || raw.contains(" ") {
      list.append(raw.replacingOccurrences(of: ".", with: "-").replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: " ", with: "-"))
    }
    return list
  }
}
