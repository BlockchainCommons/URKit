// From: https://github.com/myfreeweb/SwiftCBOR
// License: Public Domain

import Foundation

public struct OrderedMapEntry: Hashable {
    public let key: CBOR
    public let value: CBOR

    public init(key: CBOR, value: CBOR) {
        self.key = key
        self.value = value
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
            return [DumpItem(level: level, data: self.encoded, note: "unsigned(\(n))")]
        case .negativeInt(let n):
            let ni = ~Int64(bitPattern: n)
            return [DumpItem(level: level, data: self.encoded, note: "negative(\(ni))")]
        case .data(let d):
            let note = d.utf8?.sanitized?.flanked("\"")
            return [
                DumpItem(level: level, data: CBOR.byteStringHeader(count: d.count), note: "bytes(\(d.count))"),
                DumpItem(level: level + 1, data: d, note: note)
            ]
        case .utf8String(let s):
            let stringHeader = CBOR.stringHeader(str: s)
            return [
                DumpItem(level: level, data: [Data(of: stringHeader.first!), stringHeader.dropFirst()], note: "text(\(s.utf8Data.count))"),
                DumpItem(level: level + 1, data: s.utf8Data, note: s.flanked("\""))
            ]
        case .simple(let v):
            let data = CBOR.encodeSimpleValue(v, .binary)
            let note = CBOR.encodeSimpleValue(v, .diagnostic).utf8!.flanked("simple(", ")")
            return [
                DumpItem(level: level, data: data, note: note)
            ]
        case .boolean, .null, .undefined:
            return [
                DumpItem(level: level, data: encoded, note: self.cborEncode(.diagnostic).utf8!)
            ]
        case .half, .float, .double:
            return [
                DumpItem(level: level, data: [Data(of: encoded.first!), encoded.dropFirst()], note: self.cborEncode(.diagnostic).utf8!)
            ]
        case .tagged(let tag, let cbor):
            let tagHeader = CBOR.tagHeader(tag: tag)
            var noteComponents: [String] = [
                String(tag.rawValue).flanked("tag(", ")")
            ]
            if let name = tag.name {
                noteComponents.append(name)
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
                m.flatMap {
                    [
                        $0.key.dumpItems(level: level + 1),
                        $0.value.dumpItems(level: level + 1)
                    ].flatMap { $0 }
                }
            ].flatMap { $0 }
        case .date(let date):
            let dateHeader = CBOR.dateHeader()
            let dateHeaderData = [Data(of: dateHeader.first!), dateHeader.dropFirst()]
            let encodedDate = CBOR.encodeDate(date, .binary)
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
    case orderedMap([OrderedMapEntry])
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
        case let .orderedMap(l):  CBORUtil.djb2Hash(l.map { $0.hashValue }).hash(into: &hasher)
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
        
        public static func knownTag(for rawValue: UInt64) -> Tag {
            knownTagsByRawValue[rawValue] ?? Tag(rawValue: rawValue)
        }
        
        public static func setKnownTag(_ tag: Tag) {
            knownTagsByRawValue[tag.rawValue] = tag
        }
        
        public init(rawValue: UInt64) {
            self.rawValue = rawValue
            self.name = nil
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

#if os(Linux)
let NSEC_PER_SEC: UInt64 = 1_000_000_000
#endif
