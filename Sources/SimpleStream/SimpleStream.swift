/*
 * SimpleStream.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 12/4/16.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation



public protocol SimpleStream {
	
	/** The index of the first byte returned from the stream at the next read,
	where 0 is the first byte of the stream.
	
	This is also the number of bytes that has been returned by the different read
	methods of the stream. */
	var currentReadPosition: Int {get}
	
	/** Read the given size from the buffer and returns it in a Data object.
	
	For performance reasons, you can specify you don't want to own the retrieved
	bytes by setting `alwaysCopyBytes` to `false`, in which case, you should be
	careful NOT to do any operation on the stream and make it stay in memory
	while you hold on to the returned data.
	
	- Parameter size: The size you want to read from the buffer.
	- Parameter alwaysCopyBytes: Whether to copy the bytes in the returned Data.
	- Throws: If any error occurs reading the data (including end of stream
	reached before the given size is read), an error is thrown.
	- Returns: The read Data. */
	func readData(size: Int, alwaysCopyBytes: Bool) throws -> Data
	
	/** Read from the stream, until one of the given delimiters is found. An
	empty delimiter matches nothing.
	
	If the delimiters list is empty, the data is read to the end of the stream
	(or the stream size limit).
	
	If none of the given delimiter matches, the `delimitersNotFound` error is
	thrown.
	
	Choose your matching mode with care. Some mode may have to read and put the
	whole stream in an internal cache before being able to return the data you
	want.
	
	For performance reasons, you can specify you don't want to own the retrieved
	bytes by setting `alwaysCopyBytes` to `false`, in which case, you should be
	careful NOT to do any operation on the stream and make it stay in memory
	while you hold on to the returned data.
	
	- Important: If the delimiters list is empty, the stream is read until the
	end (either end of stream or stream size limit is reached). If the delimiters
	list is **not** empty but no delimiters match, the `delimitersNotFound` error
	is thrown.
	
	- Parameter upToDelimiters: The delimiters you want to stop reading at. Once
	any of the given delimiters is reached, the read data is returned.
	- Parameter matchingMode: How to choose which delimiter will stop the reading
	of the data.
	- Parameter alwaysCopyBytes: Whether to copy the bytes in the returned Data.
	- Throws: If any error occurs reading the data (including end of stream
	reached before any of the delimiters is reached), an error is thrown.
	- Returns: The read Data. */
	func readData(upToDelimiters: [Data], matchingMode: DelimiterMatchingMode, includeDelimiter: Bool, alwaysCopyBytes: Bool) throws -> Data
	
}


public extension SimpleStream {
	
	func readType<Type>() throws -> Type {
		let data = try readData(size: MemoryLayout<Type>.size, alwaysCopyBytes: false)
		return data.withUnsafeBytes{ (_ bytes: UnsafePointer<UInt8>) -> Type in
			return bytes.withMemoryRebound(to: Type.self, capacity: 1){ pointer -> Type in
				return pointer.pointee
			}
		}
	}
	
	func readDataToEnd(alwaysCopyBytes: Bool) throws -> Data {
		return try readData(upToDelimiters: [], matchingMode: .anyMatchWins, includeDelimiter: true, alwaysCopyBytes: alwaysCopyBytes)
	}
	
}



/** How to match the delimiters for the `readData(upToDelimiters:...)` method.

In the description of the different cases, we'll use a common example:

- We'll use a `SimpleInputStream`, which uses a cache to hold some of the data
read from the stream;
- The delimiters will be (in this order):
   - `"45"`
   - `"67"`
   - `"234"`
   - `"12345"`

- The full data in the stream will be: `"0123456789"`;
- In the cache, we'll only have `"01234"` read. */
public enum DelimiterMatchingMode {
	
	/** The lightest match algorithm (usually). In the given example, the third
	delimiter (`"234"`) will match, because the `SimpleStream` will first try to
	match the delimiters against what it already have in memory.
	
	- Note: This is our current implementation of this type of `SimpleStream`.
	However, any delimiter can match, the implementation is really up to the
	implementer… However, implementers should keep in mind the goal of this
	matching mode, which is to match and return the data in the quickest way
	possible. */
	case anyMatchWins
	
	/** The matching delimiter that gives the shortest data will be used. In our
	example, it will be the fourth one (`"12345"`) which will yield the shortest
	data (`"0"`). */
	case shortestDataWins
	
	/** The matching delimiter that gives the longest data will be used. In our
	example, it will be the second one (`"67"`) which will yield the longest data
	(`"012345"`).
	
	- Important: Use this matching mode with care! It might have to read all of
	the stream (and thus fill the memory with it) to be able to correctly
	determine which match yields the longest data. Actually, the only case where
	the result can be returned safely before reaching the end of the data is when
	all of the delimiters match… */
	case longestDataWins
	
	/** The first matching delimiter will be used. In our example, it will be the
	first one (`"45"`).
	
	- Important: Use this matching mode with care! It might have to read all of
	the stream (and thus fill the memory with it) to be able to correctly
	determine the first match. Actually, the only case where the result can be
	returned safely before reaching the end of the data is when the first
	delimiter matches, or when all the delimiters have matched…
	
	- Note: If you need something like `latestMatchingDelimiterWins` or
	`shortestMatchingDelimiterWins` you can do it yourself by using this matching
	mode and simply sorting your delimiters list before giving it to the
	function.*/
	case firstMatchingDelimiterWins
	
}
