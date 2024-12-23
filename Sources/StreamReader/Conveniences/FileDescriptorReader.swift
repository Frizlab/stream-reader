/*
 * FileDescriptorReader.swift
 * StreamReader
 *
 * Created by François Lamboley on 2021/03/27.
 */

import Foundation
#if canImport(SystemPackage)
import SystemPackage
#elseif canImport(System)
import System
#endif



#if canImport(SystemPackage) || canImport(System)

@available(macOS 11.0, tvOS 14.0, iOS 14.0, watchOS 7.0, *)
extension FileDescriptor : GenericReadStream {
	
	public func read(_ buffer: UnsafeMutableRawPointer, maxLength len: Int) throws -> Int {
		return try read(into: UnsafeMutableRawBufferPointer(start: buffer, count: len))
	}
	
}

@available(macOS 11.0, tvOS 14.0, iOS 14.0, watchOS 7.0, *)
public typealias FileDescriptorReader = GenericStreamReader

#endif
