/*
 * SimpleFileHandleStream.swift
 * SimpleStream
 *
 * Created by François Lamboley on 20/08/2017.
 */

import Foundation



extension FileHandle : GenericReadStream {
	
	public func read(_ buffer: UnsafeMutableRawPointer, maxLength len: Int) throws -> Int {
		let data = readData(ofLength: len)
		let sizeRead = data.count
		
		guard sizeRead > 0 else {return 0}
		data.withUnsafeBytes{ bytes in buffer.copyMemory(from: bytes, byteCount: sizeRead) }
		return sizeRead
	}
	
}

public typealias SimpleFileHandleStream = SimpleGenericReadStream
