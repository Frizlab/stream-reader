/*
 * SimpleReadStream.swift
 * BSONSerialization
 *
 * Created by François Lamboley on 12/4/16.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation



public protocol SimpleReadStream : class {
	
	/** The index of the first byte returned from the stream at the next read,
	where 0 is the first byte of the stream.
	
	This is also the number of bytes that has been returned by the different read
	methods of the stream. */
	var currentReadPosition: Int {get}
	
	/** The maximum total number of bytes allowed to be read from the underlying
	stream. When the limit is reached, the stream must throw the
	`.streamReadSizeLimitReached` error if read from.
	
	If set to nil, there are no limits.
	
	Can be changed after having read from the stream. If set to a value lower
	than or equal to the current total number of bytes read, no more bytes will
	be read from the stream, and the `.streamReadSizeLimitReached` error will be
	thrown when trying to read more data (if the current internal buffer end is
	reached). */
	var readSizeLimit: Int? {get set}
	
	/** Read `size` bytes from the stream. The size must be >= 0.
	
	You get access to the read data through an unsafe raw buffer pointer whose
	memory is guaranteed to be valid and immutable while you’re in the handler.
	You should not assume the memory you get is bound to a particular type. Use
	the memory rebinding methods if you need them.
	
	- Important: For the memory to stay valid and immutable in the handler, do
	**NOT** do any stream operation inside the handler.
	
	- Parameter size: The size you want to read from the buffer.
	- Parameter handler: Use the data inside this hanlder. Do **NOT** do any
	stream operation inside the handler.
	- Parameter bytes: A raw buffer pointer to the bytes that have been read.
	- Throws: If any error occurs reading the data (including end of stream
	reached before the given size is read), an error is thrown.
	- Returns: The value returned by your handler. */
	func readData<T>(size: Int, _ handler: (_ bytes: UnsafeRawBufferPointer) throws -> T) throws -> T
	
	/** Read from the stream, until one of the given delimiters is found. An
	empty delimiter matches nothing.
	
	If the delimiters list is empty, the data is read to the end of the stream
	(or the stream size limit).
	
	If none of the given delimiter matches, the `delimitersNotFound` error is
	thrown.
	
	Choose your matching mode with care. Some mode may have to read and put the
	whole stream in an internal cache before being able to return the data you
	want.
	
	- Important: If the delimiters list is empty, the stream is read until the
	end (either end of stream or stream size limit is reached). If the delimiters
	list is **not** empty but no delimiters match, the `delimitersNotFound` error
	is thrown.
	
	You get access to the read data through an unsafe raw buffer pointer whose
	memory is guaranteed to be valid and immutable while you’re in the handler.
	You should not assume the memory you get is bound to a particular type. Use
	the memory rebinding methods if you need them.
	
	- Important: For the memory to stay valid and immutable in the handler, do
	**NOT** do any stream operation inside the handler.
	
	- Parameter upToDelimiters: The delimiters you want to stop reading at. Once
	any of the given delimiters is reached, the read data is returned.
	- Parameter matchingMode: How to choose which delimiter will stop the reading
	of the data.
	- Parameter includeDelimiter: Should the returned data include the delimiter
	that matched?
	- Parameter handler: Use the data inside this hanlder. Do **NOT** do any
	stream operation inside the handler.
	- Parameter bytes: A raw buffer pointer to the bytes that have been read.
	- Parameter delimiterThatMatched: The delimiter that matched to stop reading
	the stream. If no delimiters have been given (read the stream to the end),
	this parameter will contain an empty Data object.
	- Throws: If any error occurs reading the data (including end of stream
	reached before any of the delimiters is reached), an error is thrown.
	- Returns: The value returned by your handler. */
	func readData<T>(upTo delimiters: [Data], matchingMode: DelimiterMatchingMode, includeDelimiter: Bool, _ handler: (_ bytes: UnsafeRawBufferPointer, _ delimiterThatMatched: Data) throws -> T) throws -> T
	
}


public extension SimpleReadStream {
	
	func readData(size: Int) throws -> Data {
		return try readData(size: size, { bytes in Data(bytes) })
	}
	
	func readData(upTo delimiters: [Data], matchingMode: DelimiterMatchingMode, includeDelimiter: Bool) throws -> (data: Data, delimiter: Data) {
		return try readData(upTo: delimiters, matchingMode: matchingMode, includeDelimiter: includeDelimiter, { bytes, delimiterThatMatched in (Data(bytes), delimiterThatMatched) })
	}
	
	func readDataToEnd<T>(_ handler: (_ bytes: UnsafeRawBufferPointer) throws -> T) throws -> T {
		return try readData(upTo: [], matchingMode: .anyMatchWins, includeDelimiter: true, { bytes, _ in try handler(bytes) })
	}
	
	func readDataToEnd() throws -> Data {
		return try readData(upTo: [], matchingMode: .anyMatchWins, includeDelimiter: true, { bytes, _ in Data(bytes) })
	}
	
	func readType<Type>() throws -> Type {
		/* The bind should be ok because SimpleReadStream guarantees the memory to
		 * be immutable in the closure. */
		return try readData(size: MemoryLayout<Type>.size, { bytes in bytes.bindMemory(to: Type.self).baseAddress!.pointee })
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
	delimiter (`"234"`) will match, because the `SimpleReadStream` will first try
	to match the delimiters against what it already have in memory.
	
	- Note:
	This is our current implementation of this type of `SimpleReadStream`.
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
