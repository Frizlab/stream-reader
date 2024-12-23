/*
 * URLSessionStreamTaskReader.swift
 * StreamReader
 *
 * Created by François Lamboley on 2021/10/26.
 */

import Foundation



/* URLSessionStreamTask is not available (yet?) in public CoreFoundation. */
#if !canImport(FoundationNetworking)

@available(macOS 10.11, *)
extension URLSessionStreamTask : GenericReadStream {
	
	public func read(_ buffer: UnsafeMutableRawPointer, maxLength len: Int) throws -> Int {
		let readResults = ReadResults()
		let group = DispatchGroup()
		group.enter()
		readData(ofMinLength: 1, maxLength: len, timeout: .infinity, completionHandler: { d, atEOF, err in
			/* We don’t need the EOF value. */
			readResults.data = d
			readResults.error = err
			group.leave()
		})
		group.wait()
		if let e = error {throw e}
		readResults.data?.withUnsafeBytes{ bytes in buffer.copyMemory(from: bytes.baseAddress!, byteCount: bytes.count) }
		return readResults.data?.count ?? 0
	}
	
	/* This is not Sendable at all, but we guarantee we’ll use it responsibly. */
	private final class ReadResults : @unchecked Sendable {
		var data: Data?, error: Error?
	}
	
}

public typealias URLSessionStreamTaskReader = GenericStreamReader

#endif
