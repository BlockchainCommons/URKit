import Foundation

public struct OrderedMap: Hashable, ExpressibleByDictionaryLiteral, Sequence {
    public var elements: [Entry]
    
    public init(_ elements: [Entry]) {
        self.elements = elements
    }
    
    public init(dictionaryLiteral elements: (CBOR, CBOR)...) {
        self.elements = elements.map { Entry(key: $0.0, value: $0.1)}
    }
    
    public var count: Int {
        elements.count
    }
    
    mutating public func append(_ e: (CBOR, CBOR)) {
        elements.append(.init(key: e.0, value: e.1))
    }
    
    mutating public func append(_ k: CBOR, _ v: CBOR) {
        elements.append(.init(key: k, value: v))
    }
    
    public struct Entry: Hashable {
        public let key: CBOR
        public let value: CBOR

        public init(key: CBOR, value: CBOR) {
            self.key = key
            self.value = value
        }
        
        public init(_ e: (CBOR, CBOR)) {
            self.init(key: e.0, value: e.1)
        }
    }
    
    public func makeIterator() -> Iterator {
        Iterator(elements: elements)
    }
    
    public class Iterator: IteratorProtocol {
        let elements: [Entry]
        var iterator: IndexingIterator<[Entry]>
        
        init(elements: [Entry]) {
            self.elements = elements
            self.iterator = elements.makeIterator()
        }
        
        public func next() -> (CBOR, CBOR)? {
            guard let e = iterator.next() else {
                return nil
            }
            return (e.key, e.value)
        }
    }
}
