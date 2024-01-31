/*
 * FileHandleReader.swift
 * StreamReader
 *
 * Created by François Lamboley on 2017/08/20.
 */

import Foundation



extension FileHandle : GenericReadStream {
	
	public func read(_ buffer: UnsafeMutableRawPointer, maxLength len: Int) throws -> Int {
		let data: Data
		if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, watchOS 6.2, *) {
			data = try read(upToCount: len) ?? Data()
		} else {
			/* This might throw (an ObjC exception).
			 * Sadly these exception are not catchable at all in “pure” Swift, so we’re not catching them…
			 * Anyway this is a deprecated API, and the more modern version is used when available. */
			data = readData(ofLength: len)
		}
		let sizeRead = data.count
		
		guard sizeRead > 0 else {return 0}
		data.withUnsafeBytes{ bytes in buffer.copyMemory(from: bytes.baseAddress!, byteCount: sizeRead) }
		return sizeRead
	}
	
}

public typealias FileHandleReader = GenericStreamReader
