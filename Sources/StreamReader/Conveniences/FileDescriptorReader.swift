/*
 * FileDescriptorReader.swift
 * StreamReader
 *
 * Created by François Lamboley on 2021/3/27.
 */

import Foundation

import SystemPackage



extension FileDescriptor : GenericReadStream {
	
	public func read(_ buffer: UnsafeMutableRawPointer, maxLength len: Int) throws -> Int {
		return try read(into: UnsafeMutableRawBufferPointer(start: buffer, count: len))
	}
	
}

public typealias FileDescriptorReader = GenericStreamReader
