/*
 * StreamReader.swift
 * StreamReader
 *
 * Created by François Lamboley on 12/4/16.
 * Copyright © 2016 frizlab. All rights reserved.
 */

import Foundation



public protocol StreamReader : AnyObject {
	
	/**
	Whether _the underlying stream_’s `EOF` has been reached, either because of
	`readSizeLimit` constraint, or because the actual end of the stream has been
	reached. */
	var streamHasReachedEOF: Bool {get}
	/**
	The number of bytes read _from the underlying stream_. Can be greater than
	`readSizeLimit` iif `readSizeLimit` has been changed to a lower value than
	`currentStreamReadPosition`. */
	var currentStreamReadPosition: Int {get}
	
	/**
	Force set `streamHasReachedEOF` to `false`. Call this before calling the read
	methods to force a read when EOF has been reached. */
	func clearStreamHasReachedEOF()
	
	/**
	The index of the first byte returned from the stream at the next read, where
	0 is the first byte of the stream.
	
	This is also the number of bytes that has been returned by the different read
	methods of the stream, when `updateReadPosition` was `true`. */
	var currentReadPosition: Int {get}
	
	/**
	The maximum value possible for `currentReadPosition` **and** the maximum
	total number of bytes allowed to be read _from the underlying stream_.
	
	If set to `nil`, there are no limits.
	
	You get the following guarantees:
	- No more than `readSizeLimit` bytes will be read by the reader from the
	underlying stream;
	- No read from the reader will set the `currentReadPosition` to be greater
	than `readSizeLimit`.
	
	It is however possible to change `readSizeLimit` at any time, which makes it
	possible for more than `readSizeLimit` to _have been read_ from the stream,
	or for `currentReadPosition` to be greater than `readSizeLimit`.
	
	When `currentReadPosition` is greater than `readSizeLimit`, trying to read
	more data will throw the `.notEnoughData` error (or return an empty data if
	reading less than asked is allowed).
	
	This property can be useful because it is usually not possible to add data
	back to a stream once it has been read from. If you know your stream can have
	more data that what you’re interested in and want to avoid the reader reading
	too much and thus rendering the stream unusable for other clients, you should
	use this property. */
	var readSizeLimit: Int? {get set}
	
	/**
	Read `size` bytes from the stream. The size must be >= 0.
	
	You get access to the read data through an unsafe raw buffer pointer whose
	memory is guaranteed to be valid and immutable while you’re in the handler.
	You should not assume the memory you get is bound to a particular type. Use
	the memory rebinding methods if you need them.
	
	Reading a data of size 0 must never fail and always return an empty Data
	object.
	
	- Important: For the memory to stay valid and immutable in the handler, do
	**NOT** do any stream operation inside the handler.
	
	- Parameter size: The size you want to read from the buffer.
	- Parameter allowReadingLess: If end of stream (or read size limit) is
	reached before the required size is read, should we return what can be read?
	- Parameter updateReadPosition: If `true`, the `currentReadPosition` will be
	updated; if `false` it won’t.
	- Parameter handler: Use the data inside this hanlder. Do **NOT** do any
	stream operation inside the handler.
	- Parameter bytes: A raw buffer pointer to the bytes that have been read.
	- Throws: If any error occurs reading the data (including end of stream
	reached before the given size is read if `allowReadingLess` is `false`), an
	error is thrown.
	- Returns: The value returned by your handler. */
	func readData<T>(size: Int, allowReadingLess: Bool, updateReadPosition: Bool, _ handler: (_ bytes: UnsafeRawBufferPointer) throws -> T) throws -> T
	
	/**
	Read from the stream, until one of the given delimiters is found. An empty
	delimiter matches nothing.
	
	If the delimiters list is empty, the data is read to the end of the stream
	(or the stream size limit) and the returned `delimiterThatMatched` will be an
	empty `Data` object.
	
	If none of the given delimiter matches, the `delimitersNotFound` error is
	thrown, unless `failIfNotFound` is `false` (in which case the end of the
	stream is returned and `delimiterThatMatched` will be set to an empty `Data`
	object).
	
	The following calls are equivalent:
	```
	readData<T>(upTo: [],                        matchingMode: .anyMatchWins, failIfNotFound: true,  includeDelimiter: true, updateReadPosition: true, myHandler)
	readData<T>(upTo: [],                        matchingMode: .anyMatchWins, failIfNotFound: false, includeDelimiter: true, updateReadPosition: true, myHandler)
	readData<T>(upTo: [Data()],                  matchingMode: .anyMatchWins, failIfNotFound: false, includeDelimiter: true, updateReadPosition: true, myHandler)
	readData<T>(upTo: [nonEmptyDataNotInStream], matchingMode: .anyMatchWins, failIfNotFound: false, includeDelimiter: true, updateReadPosition: true, myHandler)
	```
	
	Choose your matching mode with care. Some mode may have to read and put the
	whole stream in an internal cache before being able to return the data you
	want.
	
	You get access to the read data through an unsafe raw buffer pointer whose
	memory is guaranteed to be valid and immutable while you’re in the handler.
	You should not assume the memory you get is bound to a particular type. Use
	the memory rebinding methods if you need them.
	
	- Important: For the memory to stay valid and immutable in the handler, do
	**NOT** do any stream operation inside the handler.
	
	- Parameter delimiters: The delimiters you want to stop reading at. If this
	array is empty, the stream is read to the end.
	- Parameter matchingMode: How to choose which delimiter will stop the reading
	of the data.
	- Parameter failIfNotFound: If none of the delimiters are found, should the
	method throw or return the data up to the end of the stream?
	- Parameter includeDelimiter: Should the returned data include the delimiter
	that matched?
	- Parameter updateReadPosition: If `true`, the `currentReadPosition` will be
	updated; if `false` it won’t.
	- Parameter handler: Use the data inside this hanlder. Do **NOT** do any
	stream operation inside the handler.
	- Parameter bytes: A raw buffer pointer to the bytes that have been read.
	- Parameter delimiterThatMatched: The delimiter that matched to stop reading
	the stream. If no delimiters have been given (read the stream to the end),
	this parameter will contain an empty Data object.
	- Throws: If any error occurs reading the data, an error is thrown.
	- Returns: The value returned by your handler. */
	func readData<T>(upTo delimiters: [Data], matchingMode: DelimiterMatchingMode, failIfNotFound: Bool, includeDelimiter: Bool, updateReadPosition: Bool, _ handler: (_ bytes: UnsafeRawBufferPointer, _ delimiterThatMatched: Data) throws -> T) throws -> T
	
}


public extension StreamReader {
	
	func readData<T>(size: Int, allowReadingLess: Bool = false, _ handler: (_ bytes: UnsafeRawBufferPointer) throws -> T) throws -> T {
		return try readData(size: size, allowReadingLess: allowReadingLess, updateReadPosition: true, handler)
	}
	
	func peekData<T>(size: Int, allowReadingLess: Bool = false, _ handler: (_ bytes: UnsafeRawBufferPointer) throws -> T) throws -> T {
		return try readData(size: size, allowReadingLess: allowReadingLess, updateReadPosition: false, handler)
	}
	
	func readData<T>(upTo delimiters: [Data], matchingMode: DelimiterMatchingMode, failIfNotFound: Bool = true, includeDelimiter: Bool, _ handler: (_ bytes: UnsafeRawBufferPointer, _ delimiterThatMatched: Data) throws -> T) throws -> T {
		return try readData(upTo: delimiters, matchingMode: matchingMode, failIfNotFound: failIfNotFound, includeDelimiter: includeDelimiter, updateReadPosition: true, handler)
	}
	
	func peekData<T>(upTo delimiters: [Data], matchingMode: DelimiterMatchingMode, failIfNotFound: Bool = true, includeDelimiter: Bool, _ handler: (_ bytes: UnsafeRawBufferPointer, _ delimiterThatMatched: Data) throws -> T) throws -> T {
		return try readData(upTo: delimiters, matchingMode: matchingMode, failIfNotFound: failIfNotFound, includeDelimiter: includeDelimiter, updateReadPosition: false, handler)
	}
	
}


public extension StreamReader {
	
	/**
	Returns `true` if the underlying stream has reached EOF _and_ the current
	stream read position is the same (or lower than) the current read position. */
	var hasReachedEOF: Bool {
		return streamHasReachedEOF && currentReadPosition >= currentStreamReadPosition
	}
	
	/**
	Actively check for `EOF` in the stream.
	
	- Important: If the read size limit has not been reached and EOF has not been
	definitely reached, one byte might be read from the underlying stream when
	using this method, though the `currentReadPosition` of the stream reader will
	never change. */
	func checkForEOF() throws -> Bool {
		return try hasReachedEOF || peekData(size: 1, allowReadingLess: true).isEmpty
	}
	
	func readData(size: Int, allowReadingLess: Bool = false) throws -> Data {
		return try readData(size: size, allowReadingLess: allowReadingLess, { bytes in Data(bytes) })
	}
	
	func peekData(size: Int, allowReadingLess: Bool = false) throws -> Data {
		return try peekData(size: size, allowReadingLess: allowReadingLess, { bytes in Data(bytes) })
	}
	
	func readData(upTo delimiters: [Data], matchingMode: DelimiterMatchingMode, failIfNotFound: Bool = true, includeDelimiter: Bool) throws -> (data: Data, delimiter: Data) {
		return try readData(upTo: delimiters, matchingMode: matchingMode, failIfNotFound: failIfNotFound, includeDelimiter: includeDelimiter, { bytes, delimiterThatMatched in (Data(bytes), delimiterThatMatched) })
	}
	
	func peekData(upTo delimiters: [Data], matchingMode: DelimiterMatchingMode, failIfNotFound: Bool = true, includeDelimiter: Bool) throws -> (data: Data, delimiter: Data) {
		return try peekData(upTo: delimiters, matchingMode: matchingMode, failIfNotFound: failIfNotFound, includeDelimiter: includeDelimiter, { bytes, delimiterThatMatched in (Data(bytes), delimiterThatMatched) })
	}
	
	func readDataToEnd<T>(_ handler: (_ bytes: UnsafeRawBufferPointer) throws -> T) throws -> T {
		return try readData(upTo: [], matchingMode: .anyMatchWins, failIfNotFound: true, includeDelimiter: true, { bytes, _ in try handler(bytes) })
	}
	
	func readDataToEnd() throws -> Data {
		return try readData(upTo: [], matchingMode: .anyMatchWins, failIfNotFound: true, includeDelimiter: true, { bytes, _ in Data(bytes) })
	}
	
	func readType<Type>() throws -> Type {
		/* The bind should be ok because StreamReader guarantees the memory to be
		 * immutable in the closure. */
		return try readData(size: MemoryLayout<Type>.size, allowReadingLess: false, { bytes in bytes.bindMemory(to: Type.self).baseAddress!.pointee })
	}
	
	/**
	Reads a line from the stream, supporting unix, legacy MacOS and windows new
	lines. By default only unix new lines are considered.
	
	The line is returned as a `Data` object, which you can then use to init a
	`String` using the encoding you wish.
	
	The line separator found is also returned. If empty, it means the end of the
	stream has been reached before a line separator could be found.
	
	- Important: The newline is not returned in the line, however the stream
	position (next read) is set _after_ the line separator.
	
	- Returns: The line and line separator, or `nil` if the end of the stream was
	reached. */
	func readLine(allowUnixNewLines: Bool = true, allowLegacyMacOSNewLines: Bool = false, allowWindowsNewLines: Bool = false) throws -> (line: Data, newLineChars: Data)? {
		/* Unix:    lf
		 * MacOS:   cr
		 * Windows: cr + lf */
		let lf = Data([0x0a /* \n */])
		let cr = Data([0x0d /* \r */])
		
		let separators = (allowUnixNewLines ? [lf] : []) + (allowLegacyMacOSNewLines ? [cr] : []) + (!allowLegacyMacOSNewLines && allowWindowsNewLines ? [cr + lf] : [])
		let (line, separator) = try readData(upTo: separators, matchingMode: .shortestDataWins, failIfNotFound: false, includeDelimiter: false)
		_ = try readData(size: separator.count, allowReadingLess: false) /* We must read the line separator! */
		guard !line.isEmpty || !separator.isEmpty else {return nil}
		
		if !allowWindowsNewLines || !allowLegacyMacOSNewLines || separator == lf || separator.isEmpty {
			/* If Windows new lines are not allowed, or the separator that matched
			 * was lf or empty (end of stream), or if legacy MacOS new lines are
			 * not allowed, we can directly return the data we found as there is no
			 * ambiguity possible. */
			return (line: line, newLineChars: separator)
		} else {
			/* Windows and legacy MacOS new lines are allowed, and the separator
			 * that matched was not lf. */
			
			/* This assertion is true because to be able to have crlf as a
			 * separator, the legacy MacOS new lines must be disallowed (see the
			 * definition of the separators variable). If legacy MacOS new lines
			 * are not allowed, we cannot be here (see the if). */
			assert(separator != cr + lf)
			/* From the assert above, comes the assert below! Because of the if. */
			assert(separator == cr)
			
			/* Just a reminder of the if above. Asserted, because we use this truth
			 * in the logic of the code that follow. */
			assert(allowWindowsNewLines && allowLegacyMacOSNewLines)
			
			/* All we have to do is check the next char in the stream. If it is a
			 * lf, we have a windows line separator, otherwise we have a legacy
			 * MacOS separator. */
			if try peekData(size: 1, allowReadingLess: true) == lf {
				_ = try readData(size: 1, allowReadingLess: false /* We know there is something to read */)
				return (line: line, newLineChars: separator + lf)
			} else {
				return (line: line, newLineChars: separator)
			}
		}
	}
	
}



/**
How to match the delimiters for the `readData(upToDelimiters:...)` method.

In the description of the different cases, we'll use a common example:

- We'll use a `GenericStreamReader`, which uses a cache to hold some of the data
read from the stream;
- The delimiters will be (in this order):
   - `"45"`
   - `"67"`
   - `"234"`
   - `"12345"`

- The full data in the stream will be: `"0123456789"`;
- In the cache, we'll only have `"01234"` read. */
public enum DelimiterMatchingMode {
	
	/**
	The lightest match algorithm (usually). In the given example, the third
	delimiter (`"234"`) will match, because the `StreamReader` will first try to
	match the delimiters against what it already have in memory.
	
	- Note:
	This is true for a `GenericStreamReader`, the way it is implemented.
	However, any delimiter can match, the implementation is really up to the
	implementer… However, implementers should keep in mind the goal of this
	matching mode, which is to match and return the data in the quickest way
	possible. */
	case anyMatchWins
	
	/**
	The matching delimiter that gives the shortest data will be used. In our
	example, it will be the fourth one (`"12345"`) which will yield the shortest
	data (`"0"`). */
	case shortestDataWins
	
	/**
	The matching delimiter that gives the longest data will be used. In our
	example, it will be the second one (`"67"`) which will yield the longest data
	(`"012345"`).
	
	- Important: Use this matching mode with care! It might have to read all of
	the stream (and thus fill the memory with it) to be able to correctly
	determine which match yields the longest data. Actually, the only case where
	the result can be returned safely before reaching the end of the data is when
	all of the delimiters match… */
	case longestDataWins
	
	/**
	The first matching delimiter will be used. In our example, it will be the
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
