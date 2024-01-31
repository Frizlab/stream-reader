/*
 * InputStreamReader.swift
 * StreamReader
 *
 * Created by François Lamboley on 2017/08/20.
 */

import Foundation



extension InputStream : GenericReadStream {
	
	public func read(_ buffer: UnsafeMutableRawPointer, maxLength len: Int) throws -> Int {
		let boundBuffer = buffer.bindMemory(to: UInt8.self, capacity: len)
		
		let sizeRead = read(boundBuffer, maxLength: len)
		guard sizeRead >= 0 else {throw Err.streamReadError(streamError: streamError)}
		
		return sizeRead
	}
	
}

public typealias InputStreamReader = GenericStreamReader
