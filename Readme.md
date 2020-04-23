# SimpleStream
A simple stream protocol for Swift named `SimpleStream`, with two concrete implementations:
`SimpleGenericReadStream` and `SimpleDataStream`.

The `SimpleGenericReadStream` can read from any `GenericReadStream`, which the
`FileHandle` and `IntputStream` classes have been made conform to.

## Usage Examples
### Reading a Stream to the End
```swift
let ds = SimpleDataStream(data: d)
let rd = try ds.readDataToEnd()
assert(rd == d)
```

### Reading a Stream Until a Delimitor Is Found
```swift
let s = SimpleInputStream(stream: yourInputStream, bufferSize: 1024, bufferSizeIncrement: 512, streamReadSizeLimit: nil)
/* Read the stream until a newline (whether macOS, Windows or Classic Mac OS) is found, does not include the newline in the result. */
let line = try s.readData(upTo: [Data("\n".utf8), Data("\r".utf8), Data("\r\n".utf8)], matchingMode: .anyMatchWins, includeDelimiter: false).data
```
