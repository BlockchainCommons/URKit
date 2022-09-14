// Originally based on: https://github.com/myfreeweb/SwiftCBOR

import Foundation
import WolfBase

enum DiagItem {
    case item(String)
    case group(begin: String, end: String, items: [DiagItem], comment: String?)
    
    func format(level: Int = 0, separator: String = "", annotate: Bool = false) -> String {
        switch self {
        case .item(let string):
            return formatLine(level: level, string: string, separator: separator)
        case .group:
            if containsGroup || totalStringsLength > 20 || greatestStringsLength > 20 {
                return multilineComposition(level: level, separator: separator, annotate: annotate)
            } else {
                return singleLineComposition(level: level, separator: separator, annotate: annotate)
            }
        }
    }
    
    private func formatLine(level: Int, string: String, separator: String = "") -> String {
        String(repeating: " ", count: level * 3) + string + separator
    }
    
    func singleLineComposition(level: Int, separator: String, annotate: Bool) -> String {
        let string: String
        switch self {
        case .item(let s):
            string = s
        case .group(let begin, let end, let items, let comment):
            let components = items.map { item -> String in
                switch item {
                case .item(let string):
                    return string
                case .group:
                    return "<group>"
                }
            }
            let s = components.joined(separator: ", ").flanked(begin, end)
            if annotate, let comment = comment {
                string = "\(s)   ; \(comment)"
            } else {
                string = s
            }
        }
        return formatLine(level: level, string: string, separator: separator)
    }
    
    func multilineComposition(level: Int, separator: String, annotate: Bool) -> String {
        switch self {
        case .item(let string):
            return string
        case .group(let begin, let end, let items, let comment):
            var lines: [String] = []
            var b: String
            if annotate, let comment = comment {
                b = "\(begin)   ; \(comment)"
            } else {
                b = begin
            }
            lines.append(formatLine(level: level, string: b))
            for (index, item) in items.enumerated() {
                let separator = index == items.count - 1 ? "" : ","
                lines.append(item.format(level: level + 1, separator: separator, annotate: annotate))
            }
            lines.append(formatLine(level: level, string: end, separator: separator))
            return lines.joined(separator: "\n")
        }
    }
    
    var totalStringsLength: Int {
        switch self {
        case .item(let string):
            return string.count
        case .group(_, _, let items, _):
            return items.reduce(into: 0) { result, item in
                result += item.totalStringsLength
            }
        }
    }
    
    var greatestStringsLength: Int {
        switch self {
        case .item(let string):
            return string.count
        case .group(_, _, let items, _):
            return items.reduce(into: 0) { result, item in
                result = max(result, item.totalStringsLength)
            }
        }
    }
    
    var isGroup: Bool {
        if case .group = self {
            return true
        } else {
            return false
        }
    }
    
    var containsGroup: Bool {
        switch self {
        case .item:
            return false
        case .group(_, _, let items, _):
            return items.first { $0.isGroup } != nil
        }
    }
}

extension CBOR {
    public var diag: String {
        diagItem().format()
    }
    
    public var diagAnnotated: String {
        diagItem(annotate: true).format(annotate: true)
    }
    
    func diagItem(annotate: Bool = false) -> DiagItem {
        switch self {
        case .unsignedInt(let n):
            return .item(String(n))
        case .negativeInt(let n):
            let ni = ~Int64(bitPattern: n)
            return .item(String(ni))
        case .data(let d):
            return .item(d.hex.flanked("h'", "'"))
        case .utf8String(let s):
            return .item(s.flanked("\""))
        case .simple(let v):
            return .item(String(v))
        case .boolean(let b):
            return .item(String(b))
        case .null:
            return .item("null")
        case .undefined:
            return .item("undefined")
        case .half(let f):
            return .item(String(f))
        case .float(let f):
            return .item(String(f))
        case .double(let f):
            return .item(String(f))
        case .tagged(let tag, let cbor):
            return .group(
                begin: String(tag.rawValue) + "(",
                end: ")",
                items: [cbor.diagItem(annotate: annotate)],
                comment: tag.name
            )
        case .array(let a):
            return .group(
                begin: "[",
                end: "]",
                items: a.map { $0.diagItem(annotate: annotate) },
                comment: nil
            )
        case .map(let m):
            return .group(
                begin: "{",
                end: "}",
                items: m.map { (key, value) in
                    [key.diagItem(annotate: annotate), value.diagItem(annotate: annotate)]
                }.flatMap { $0 },
                comment: nil
            )
        case .orderedMap(let m):
            return .group(
                begin: "{",
                end: "}",
                items: m.map { (k, v) in
                    [k.diagItem(annotate: annotate), v.diagItem(annotate: annotate)]
                }.flatMap { $0 },
                comment: nil
            )
        case .date(let date):
            return .item(date.ISO8601Format().flanked("1(", ")"))
        default:
            fatalError()
        }
    }
}

struct DumpItem {
    let level: Int
    let data: [Data]
    let note: String?
    
    init(level: Int, data: [Data], note: String? = nil) {
        self.level = level
        self.data = data
        self.note = note
    }

    init(level: Int, data: Data, note: String? = nil) {
        self.init(level: level, data: [data], note: note)
    }
    
    func format(noteColumn: Int) -> String {
        let column1 = formatFirstColumn()
        let column2: String
        let padding: String
        if let note = note {
            let paddingCount = max(1, min(40, noteColumn) - column1.count + 1)
            padding = String(repeating: " ", count: paddingCount)
            column2 = "# " + note
        } else {
            padding = ""
            column2 = ""
        }
        return column1 + padding + column2
    }
    
    func formatFirstColumn() -> String {
        let indent = String(repeating: " ", count: level * 3)
        let hex = data.map { $0.hex }.filter { !$0.isEmpty }.joined(separator: " ")
        return indent + hex
    }
}

extension CBOR {
    public var dump: String {
        let items = dumpItems(level: 0)
        let noteColumn = items.reduce(into: 0) { largest, item in
            largest = max(largest, item.formatFirstColumn().count)
        }
        let lines = items.map { $0.format(noteColumn: noteColumn) }
        return lines.joined(separator: "\n")
    }
    
    func dumpItems(level: Int) -> [DumpItem] {
        switch self {
        case .unsignedInt(let n):
            return [DumpItem(level: level, data: self.cborEncode, note: "unsigned(\(n))")]
        case .negativeInt(let n):
            let ni = ~Int64(bitPattern: n)
            return [DumpItem(level: level, data: self.cborEncode, note: "negative(\(ni))")]
        case .data(let d):
            let note = d.utf8?.sanitized?.flanked("\"")
            var items = [
                DumpItem(level: level, data: CBOR.byteStringHeader(count: d.count), note: "bytes(\(d.count))")
            ]
            if !d.isEmpty {
                items.append(DumpItem(level: level + 1, data: d, note: note))
            }
            return items
        case .utf8String(let s):
            let stringHeader = CBOR.stringHeader(str: s)
            return [
                DumpItem(level: level, data: [Data(of: stringHeader.first!), stringHeader.dropFirst()], note: "text(\(s.utf8Data.count))"),
                DumpItem(level: level + 1, data: s.utf8Data, note: s.flanked("\""))
            ]
        case .simple(let v):
            let data = CBOR.encodeSimpleValue(v)
            let note = String(v).flanked("simple(", ")")
            return [
                DumpItem(level: level, data: data, note: note)
            ]
        case .boolean(let b):
            return [
                DumpItem(level: level, data: cborEncode, note: String(b))
            ]
        case .null:
            return [
                DumpItem(level: level, data: cborEncode, note: "null")
            ]
        case .undefined:
            return [
                DumpItem(level: level, data: cborEncode, note: "undefined")
            ]
        case .half(let f):
            return [
                DumpItem(level: level, data: [Data(of: cborEncode.first!), cborEncode.dropFirst()], note: String(f))
            ]
        case .float(let f):
            return [
                DumpItem(level: level, data: [Data(of: cborEncode.first!), cborEncode.dropFirst()], note: String(f))
            ]
        case .double(let f):
            return [
                DumpItem(level: level, data: [Data(of: cborEncode.first!), cborEncode.dropFirst()], note: String(f))
            ]
        case .tagged(let tag, let cbor):
            let tagHeader = CBOR.tagHeader(tag: tag)
            var noteComponents: [String] = [
                String(tag.rawValue).flanked("tag(", ")")
            ]
            if let name = tag.name {
                noteComponents.append("  ; \(name)")
            }
            let tagNote = noteComponents.joined(separator: " ")
            return [
                [
                    DumpItem(level: level, data: [Data(of: tagHeader.first!), tagHeader.dropFirst()], note: tagNote)
                ],
                cbor.dumpItems(level: level + 1)
            ].flatMap { $0 }
        case .array(let array):
            let arrayHeader = CBOR.arrayHeader(count: array.count)
            let arrayHeaderData = [Data(of: arrayHeader.first!), arrayHeader.dropFirst()]
            return [
                [
                    DumpItem(level: level, data: arrayHeaderData, note: String(array.count).flanked("array(", ")"))
                ],
                array.flatMap { $0.dumpItems(level: level + 1) }
            ].flatMap { $0 }
        case .map(let m):
            let mapHeader = CBOR.mapHeader(count: m.count)
            let mapHeaderData = [Data(of: mapHeader.first!), mapHeader.dropFirst()]
            return [
                [
                    DumpItem(level: level, data: mapHeaderData, note: String(m.count).flanked("map(", ")"))
                ],
                m.flatMap {
                    [
                        $0.key.dumpItems(level: level + 1),
                        $0.value.dumpItems(level: level + 1)
                    ].flatMap { $0 }
                }
            ].flatMap { $0 }
        case .orderedMap(let m):
            let mapHeader = CBOR.mapHeader(count: m.count)
            let mapHeaderData = [Data(of: mapHeader.first!), mapHeader.dropFirst()]
            return [
                [
                    DumpItem(level: level, data: mapHeaderData, note: String(m.count).flanked("map(", ")"))
                ],
                m.flatMap { (k, v) in
                    [
                        k.dumpItems(level: level + 1),
                        v.dumpItems(level: level + 1)
                    ].flatMap { $0 }
                }
            ].flatMap { $0 }
        case .date(let date):
            let dateHeader = CBOR.dateHeader()
            let dateHeaderData = [Data(of: dateHeader.first!), dateHeader.dropFirst()]
            let encodedDate = CBOR.encodeDate(date)
            let rawEncodedDate = encodedDate.dropFirst(dateHeader.count)
            let components = [dateHeaderData, [rawEncodedDate]].flatMap { $0 }
            return [
                DumpItem(level: level, data: components, note: date.description.flanked("date(", ")"))
            ]
        default:
            fatalError()
        }
    }
}

extension Character {
    var isPrintable: Bool {
        !isASCII || (32...126).contains(asciiValue!)
    }
}

extension String {
    var sanitized: String? {
        var hasPrintable = false
        let s = self.map { c -> Character in
            if c.isPrintable {
                hasPrintable = true
                return c
            } else {
                return "."
            }
        }
        return !hasPrintable ? nil : String(s)
    }
}

public indirect enum CBOR : Equatable, Hashable,
        ExpressibleByNilLiteral, ExpressibleByIntegerLiteral, ExpressibleByStringLiteral,
        ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByBooleanLiteral,
        ExpressibleByFloatLiteral {

    case unsignedInt(UInt64)
    case negativeInt(UInt64)
    case data(Data)
    case utf8String(String)
    case array([CBOR])
    case map([CBOR : CBOR])
    case orderedMap(OrderedMap)
    case tagged(Tag, CBOR)
    case simple(UInt8)
    case boolean(Bool)
    case null
    case undefined
    case half(Float32)
    case float(Float32)
    case double(Float64)
    case `break`
    case date(Date)

    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .unsignedInt(l): l.hash(into: &hasher)
        case let .negativeInt(l): l.hash(into: &hasher)
        case let .data(l):  CBORUtil.djb2Hash(l.map { Int($0) }).hash(into: &hasher)
        case let .utf8String(l):  l.hash(into: &hasher)
        case let .array(l):       CBORUtil.djb2Hash(l.map { $0.hashValue }).hash(into: &hasher)
        case let .map(l):         CBORUtil.djb2Hash(l.map { $0.hashValue &+ $1.hashValue }).hash(into: &hasher)
        case let .orderedMap(l):  CBORUtil.djb2Hash(l.map { $0.0.hashValue &+ $0.1.hashValue }).hash(into: &hasher)
        case let .tagged(t, l):   t.hash(into: &hasher)
                                  l.hash(into: &hasher)
        case let .simple(l):      l.hash(into: &hasher)
        case let .boolean(l):     l.hash(into: &hasher)
        case .null:               (-1).hash(into: &hasher)
        case .undefined:          (-2).hash(into: &hasher)
        case let .half(l):        l.hash(into: &hasher)
        case let .float(l):       l.hash(into: &hasher)
        case let .double(l):      l.hash(into: &hasher)
        case let .date(l):        l.hash(into: &hasher)
        case .break:              Int.min.hash(into: &hasher)
        }
    }

    public subscript(position: CBOR) -> CBOR? {
        get {
            switch (self, position) {
            case (let .array(l), let .unsignedInt(i)): return l[Int(i)]
            case (let .map(l), let i): return l[i]
            default: return nil
            }
        }
        set(x) {
            switch (self, position) {
            case (var .array(l), let .unsignedInt(i)):
                l[Int(i)] = x!
                self = .array(l)
            case (var .map(l), let i):
                l[i] = x!
                self = .map(l)
            default: break
            }
        }
    }

    public init(nilLiteral: ()) { self = .null }
    public init(integerLiteral value: Int) {
        if value < 0 {
            self = .negativeInt(~UInt64(bitPattern: Int64(value)))
        } else {
            self = .unsignedInt(UInt64(value))
        }
    }
    public init(extendedGraphemeClusterLiteral value: String) { self = .utf8String(value) }
    public init(unicodeScalarLiteral value: String) { self = .utf8String(value) }
    public init(stringLiteral value: String) { self = .utf8String(value) }
    public init(arrayLiteral elements: CBOR...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (CBOR, CBOR)...) {
        var result = [CBOR : CBOR]()
        for (key, value) in elements {
            result[key] = value
        }
        self = .map(result)
    }
    public init(booleanLiteral value: Bool) { self = .boolean(value) }
    public init(floatLiteral value: Float32) { self = .float(value) }

    public static func ==(lhs: CBOR, rhs: CBOR) -> Bool {
        switch (lhs, rhs) {
        case (let .unsignedInt(l),  let .unsignedInt(r)):   return l == r
        case (let .negativeInt(l),  let .negativeInt(r)):   return l == r
        case (let .data(l),   let .data(r)):    return l == r
        case (let .utf8String(l),   let .utf8String(r)):    return l == r
        case (let .array(l),        let .array(r)):         return l == r
        case (let .map(l),          let .map(r)):           return l == r
        case (let .orderedMap(l),   let .orderedMap(r)):    return l == r
        case (let .tagged(tl, l),   let .tagged(tr, r)):    return tl == tr && l == r
        case (let .simple(l),       let .simple(r)):        return l == r
        case (let .boolean(l),      let .boolean(r)):       return l == r
        case (.null,                .null):                 return true
        case (.undefined,           .undefined):            return true
        case (let .half(l),         let .half(r)):          return l == r
        case (let .float(l),        let .float(r)):         return l == r
        case (let .double(l),       let .double(r)):        return l == r
        case (let .date(l),         let .date(r)):          return l == r
        case (.break,              .break):                 return true
        case (.unsignedInt,  _):                            return false
        case (.negativeInt,  _):                            return false
        case (.data,   _):                            return false
        case (.utf8String,   _):                            return false
        case (.array,        _):                            return false
        case (.map,          _):                            return false
        case (.orderedMap,   _):                            return false
        case (.tagged,       _):                            return false
        case (.simple,       _):                            return false
        case (.boolean,      _):                            return false
        case (.null,         _):                            return false
        case (.undefined,    _):                            return false
        case (.half,         _):                            return false
        case (.float,        _):                            return false
        case (.double,       _):                            return false
        case (.break,        _):                            return false
        default:                                            return false
        }
    }

    public struct Tag: RawRepresentable, Equatable, Hashable {
        public let rawValue: UInt64
        public let name: String?
        
        public static func knownTag(for rawValue: UInt64) -> Tag? {
            knownTagsByRawValue[rawValue]
        }
        
        public static func knownTag(for name: String) -> Tag? {
            knownTagsByName[name]
        }
        
        public static func setKnownTag(_ tag: Tag) {
            knownTagsByRawValue[tag.rawValue] = tag
            if let name = tag.name {
                knownTagsByName[name] = tag
            }
        }
        
        public static func setKnownTags(_ tags: [Tag]) {
            for tag in tags {
                setKnownTag(tag)
            }
        }
        
        public init(rawValue: UInt64) {
            if let tag = Self.knownTag(for: rawValue) {
                self = tag
            } else {
                self.rawValue = rawValue
                self.name = nil
            }
        }
        
        public init(_ rawValue: UInt64, _ name: String) {
            self.rawValue = rawValue
            self.name = name
        }

        public var hashValue : Int {
            return rawValue.hashValue
        }
        
        public static func ==(lhs: Tag, rhs: Tag) -> Bool {
            lhs.rawValue == rhs.rawValue
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(rawValue)
        }
    }
}

var knownTagsByRawValue: [UInt64: CBOR.Tag] = {
    knownTags.reduce(into: [UInt64: CBOR.Tag]()) {
        $0[$1.rawValue] = $1
    }
}()

var knownTagsByName: [String: CBOR.Tag] = {
    knownTags.reduce(into: [String: CBOR.Tag]()) {
        if let name = $1.name {
            $0[name] = $1
        }
    }
}()

var knownTags: [CBOR.Tag] = [
    .standardDateTimeString,
    .epochBasedDateTime,
    .positiveBignum,
    .negativeBignum,
    .decimalFraction,
    .bigfloat,
    
    .expectedConversionToBase64URLEncoding,
    .expectedConversionToBase64Encoding,
    .expectedConversionToBase16Encoding,
    .encodedCBORDataItem,

    .uri,
    .base64Url,
    .base64,
    .regularExpression,
    .mimeMessage,
    .uuid,
    
    .selfDescribeCBOR
]

extension CBOR.Tag {
    public static let standardDateTimeString = CBOR.Tag(0, "standard-date-time")
    public static let epochBasedDateTime = CBOR.Tag(1, "epoch-date-time")
    public static let positiveBignum = CBOR.Tag(2, "positive-bignum")
    public static let negativeBignum = CBOR.Tag(3, "negative-bignum")
    public static let decimalFraction = CBOR.Tag(4, "decimal-fraction")
    public static let bigfloat = CBOR.Tag(5, "bigfloat")

    // 6...20 unassigned

    public static let expectedConversionToBase64URLEncoding = CBOR.Tag(21, "to-base64-url")
    public static let expectedConversionToBase64Encoding = CBOR.Tag(22, "to-base64")
    public static let expectedConversionToBase16Encoding = CBOR.Tag(23, "to-hex")
    public static let encodedCBORDataItem = CBOR.Tag(24, "embedded-cbor")

    // 25...31 unassigned

    public static let uri = CBOR.Tag(32, "uri")
    public static let base64Url = CBOR.Tag(33, "base64-url")
    public static let base64 = CBOR.Tag(34, "base-64")
    public static let regularExpression = CBOR.Tag(35, "regex")
    public static let mimeMessage = CBOR.Tag(36, "mime-message")
    public static let uuid = CBOR.Tag(37, "uuid")

    // 38...55798 unassigned

    public static let selfDescribeCBOR = CBOR.Tag(55799, "self-described-cbor")
}

extension CBOR.Tag: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt64) {
        self.init(rawValue: value)
    }
}

public extension CBOR.Tag {
    var urType: String {
        guard let name = name else {
            preconditionFailure("No UR type name for tag \(rawValue).")
        }
        return name
    }
}

#if os(Linux)
let NSEC_PER_SEC: UInt64 = 1_000_000_000
#endif

extension CBOR: DataProvider {
    public var providedData: Data {
        cborEncode
    }
}
