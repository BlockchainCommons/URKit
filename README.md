# URKit

## An iOS framework for encoding and decoding URs (Uniform Resources)

by Wolf McNally and Christopher Allen<br/>
© 2020 Blockchain Commons

---

### Introduction

This framework is pure Swift 5, has no dependencies, and is available via Swift Package Manager. It contains several major components:

* `UREncoder` and `URDecoder`, A codec for [UR](https://github.com/BlockchainCommons/Research/blob/master/papers/bcr-2020-005-ur.md)s that supports single-part and multi-part transmission using fountain codes.
* `FountainEncoder` and `FountainDecoder`: A general codec for binary strings based on [Luby Transform code](https://en.wikipedia.org/wiki/Luby_transform_code).
* `Bytewords`: A codec for [Bytewords](https://github.com/BlockchainCommons/Research/blob/master/papers/bcr-2020-012-bytewords.md).
* A codec for [CBOR](https://en.wikipedia.org/wiki/CBOR) based on [SwiftCBOR](https://github.com/myfreeweb/SwiftCBOR), from the Public Domain.

If you are using this framework at it's highest level, the main types of interest will be `UR`, `UREncoder`, and `URDecoder`. The CBOR codec is provided because the body of a compliant UR must be encoded in CBOR. You can use the provided codec or your own. The other layers may be used independently if desired.

There is also an iOS app, [URDemo](https://github.com/BlockchainCommons/URDemo), that demonstrates URKit by sending and receiving long binary messages via animated QR codes containing multi-part URs.

### Requirements

* Swift 5, iOS 13 or macOS 10.15, and Xcode 11.5

### Building

* Build or include like any other Swift package. Unit tests are included.
