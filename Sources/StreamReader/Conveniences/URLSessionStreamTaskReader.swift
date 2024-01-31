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
		var data: Data?, error: Error?
		let group = DispatchGroup()
		group.enter()
		readData(ofMinLength: 1, maxLength: len, timeout: .infinity, completionHandler: { d, eof, err in
			/* We don’t need the EOF value. */
			data = d
			error = err
			group.leave()
		})
		group.wait()
		if let e = error {throw e}
		data?.withUnsafeBytes{ bytes in buffer.copyMemory(from: bytes.baseAddress!, byteCount: bytes.count) }
		return data?.count ?? 0
	}
	
}

public typealias URLSessionStreamTaskReader = GenericStreamReader

#endif
