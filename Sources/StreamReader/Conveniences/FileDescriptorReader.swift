/*
 * FileDescriptorReader.swift
 * StreamReader
 *
 * Created by François Lamboley on 2021/03/27.
 */

import Foundation
#if canImport(System)
import System
#endif


/* Important note about System vs. SystemPackage:
 * - System is a system package available on macOS;
 * - SystemPackage is the open-source version of System, available at <https://github.com/apple/swift-system>;
 * - We do not want to add SystemPackage as an explicit dependency of stream-reader because
 *    it is not an actual dependency of stream-reader, but rather a possible extension of SystemPackage if it is available;
 * - What we’d want is an optional dependency, where if the dependency is available anywhere else in the graph we add it,
 *    as described in <https://forums.swift.org/t/swiftpm-canimport/11749>, but this is not implemented (nor planned atm);
 * - There is an even better system which exists: cross-import overlays, as described in <https://sundayswift.com/posts/cross-import-overlays/>.
 *   This would be great even for the non-open-source System extension, and the FileHandle, InputStream, etc. ones: it is *exactly* what we want.
 *    Sadly cross-import overlays cannot be done using SPM for now <https://forums.swift.org/t/cross-import-overlay-status/74090>.
 *
 * So for now we only implement the conformance of System’s FileDescriptor to GenericReadStream and let clients implement their own for the SystemPackage’s one.
 *
 * Old implementation note:
 * We used to implement this extension with the check `#if canImport(SystemPackage) || canImport(System)`.
 * The problem with this is swift-system was not declared as an explicit dependency of stream-reader (as stated above it is not an actual dependency),
 *  and the availability of import of SystemPackage was non-deterministic: depending on the order of compilation of the modules, SystemPackage could be available or not… */

#if canImport(System)

@available(macOS 11.0, tvOS 14.0, iOS 14.0, watchOS 7.0, *)
extension FileDescriptor : GenericReadStream {
	
	public func read(_ buffer: UnsafeMutableRawPointer, maxLength len: Int) throws -> Int {
		return try read(into: UnsafeMutableRawBufferPointer(start: buffer, count: len))
	}
	
}

@available(macOS 11.0, tvOS 14.0, iOS 14.0, watchOS 7.0, *)
public typealias FileDescriptorReader = GenericStreamReader

#endif
