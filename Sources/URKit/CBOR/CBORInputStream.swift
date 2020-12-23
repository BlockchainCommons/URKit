// From: https://github.com/myfreeweb/SwiftCBOR
// License: Public Domain

public protocol CBORInputStream {
    mutating func popByte() throws -> UInt8
    mutating func popBytes(_ n: Int) throws -> ArraySlice<UInt8>
}

// FUCK: https://openradar.appspot.com/23255436
struct ArraySliceUInt8 {
    var slice : ArraySlice<UInt8>
}

struct ArrayUInt8 {
    var array : Array<UInt8>
}

extension ArraySliceUInt8: CBORInputStream {
    mutating func popByte() throws -> UInt8 {
        if slice.count < 1 { throw CBORDecodingError.unfinishedSequence }
        return slice.removeFirst()
    }

    mutating func popBytes(_ n: Int) throws -> ArraySlice<UInt8> {
        if slice.count < n { throw CBORDecodingError.unfinishedSequence }
        let result = slice.prefix(n)
        slice = slice.dropFirst(n)
        return result
    }
}

extension ArrayUInt8: CBORInputStream {
    mutating func popByte() throws -> UInt8 {
        guard array.count > 0 else { throw CBORDecodingError.unfinishedSequence }
        return array.removeFirst()
    }

    mutating func popBytes(_ n: Int) throws -> ArraySlice<UInt8> {
        guard array.count >= n else { throw CBORDecodingError.unfinishedSequence }
        let res = array.prefix(n)
        array = Array(array.dropFirst(n))
        return res
    }
}
