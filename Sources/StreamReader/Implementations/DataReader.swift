/*
 * DataReader.swift
 * StreamReader
 *
 * Created by François Lamboley on 2017/08/20.
 */

import Foundation



public final class DataReader : StreamReader {
	
	public let sourceData: Data
	public let sourceDataSize: Int
	
	public private(set) var currentReadPosition = 0
	
	/**
	 The whole data is in memory: the “underlying stream” (the `sourceData`) is _always_ read to `EOF`. */
	public let streamHasReachedEOF = true
	/** Always the size of the source data. */
	public let currentStreamReadPosition: Int
	
	public var readSizeLimit: Int?
	
	public init(data: Data, readSizeLimit: Int? = nil) {
		self.sourceData = data
		self.sourceDataSize = sourceData.count
		self.currentStreamReadPosition = sourceDataSize
		self.readSizeLimit = readSizeLimit
	}
	
	public func clearStreamHasReachedEOF() {
		/* nop: the data reader has always reached EOF because all of the data is in memory at all time. */
	}
	
	public func readData<T>(size: Int, allowReadingLess: Bool, updateReadPosition: Bool, _ handler: (UnsafeRawBufferPointer) throws -> T) throws -> T {
		assert(size >= 0, "Cannot read a negative number of bytes!")
		assert(currentReadPosition <= sourceDataSize, "INTERNAL ERROR")
		
		guard size > 0 else {
			return try handler(UnsafeRawBufferPointer(start: nil, count: 0))
		}
		
		if !allowReadingLess {
			if let maxRead = readSizeLimit {
				guard currentReadPosition + size <= maxRead else {throw Err.notEnoughData(wouldReachReadSizeLimit: true)}
			}
			guard (sourceDataSize - currentReadPosition) >= size else {throw Err.notEnoughData(wouldReachReadSizeLimit: false)}
		}
		
		return try sourceData.withUnsafeBytes{ bytes in
			let sizeToRead = sizeConstrainedToRemainingAllowedSizeToRead(size)
			/* Only possibility for bytes.baseAddress to be nil is if data is empty
			 *  which makes currentReadPosition and size to read being different than 0 theoratically impossible.
			 * This assert validates the flatMap we have in the raw buffer pointer creation on next line. */
			assert(bytes.baseAddress != nil || (currentReadPosition == 0 && sizeToRead == 0), "INTERNAL LOGIC ERROR")
			let ret = UnsafeRawBufferPointer(start: bytes.baseAddress.flatMap{ $0 + currentReadPosition }, count: sizeToRead)
			if updateReadPosition {currentReadPosition += sizeToRead}
			return try handler(ret)
		}
	}
	
	public func readData<T>(upTo delimiters: [Data], matchingMode: DelimiterMatchingMode, failIfNotFound: Bool, includeDelimiter: Bool, updateReadPosition: Bool, _ handler: (UnsafeRawBufferPointer, Data) throws -> T) throws -> T {
		let sizeToEnd = sizeToAllowedEnd
		let delimiters = cleanupDelimiters(delimiters, forMatchingMode: matchingMode, includingDelimiter: includeDelimiter)
		
		if delimiters.isEmpty || (!failIfNotFound && delimiters.count == 1 && delimiters[0] == Data()) {
			/* When there are no delimiters or if there is only one delimiter which is empty and we do not fail if we do not find the delimiter,
			 *  we simply read the stream to the end.
			 * There may be more optimization possible, but we don’t care for now. */
			return try readData(size: sizeToEnd, allowReadingLess: false, updateReadPosition: updateReadPosition, { ret in try handler(ret, Data()) })
		}
		
		var bestMatch: Match?
		var unmatchedDelimiters = Array(delimiters.filter{ !$0.isEmpty }.enumerated())
		let minDelimiterLength = unmatchedDelimiters.map(\.element.count).min() ?? 0
		
		return try sourceData.withUnsafeBytes{ bytes in
			assert(bytes.baseAddress != nil || currentReadPosition == 0)
			let searchedData = UnsafeRawBufferPointer(start: bytes.baseAddress.flatMap{ $0 + currentReadPosition }, count: sizeToEnd)
			if let match = matchDelimiters(inData: searchedData, dataStartOffset: 0, usingMatchingMode: matchingMode, includeDelimiter: includeDelimiter, minDelimiterLength: minDelimiterLength, withUnmatchedDelimiters: &unmatchedDelimiters, bestMatch: &bestMatch) {
				return try readData(size: match.length, allowReadingLess: false, updateReadPosition: updateReadPosition, { ret in try handler(ret, delimiters[match.delimiterIdx]) })
			}
			/* matchDelimiters did not find an indisputable match.
			 * However, we have fed all the data we have to it.
			 * We cannot find more matches!
			 * We simply return the best match we got. */
			if let match = bestMatch {
				return try readData(size: match.length, allowReadingLess: false, updateReadPosition: updateReadPosition, { ret in try handler(ret, delimiters[match.delimiterIdx]) })
			}
			if failIfNotFound {
				throw Err.delimitersNotFound
			} else {
				return try readData(size: sizeToEnd, allowReadingLess: false, updateReadPosition: updateReadPosition, { ret in try handler(ret, Data()) })
			}
		}
	}
	
	private var sizeToAllowedEnd: Int {
		return sizeConstrainedToRemainingAllowedSizeToRead(sourceDataSize - currentReadPosition)
	}
	
	private func sizeConstrainedToRemainingAllowedSizeToRead(_ size: Int) -> Int {
		if let maxTotalReadBytesCount = readSizeLimit {return max(0, min(size, min(maxTotalReadBytesCount, sourceDataSize) - currentReadPosition))}
		else                                          {return        min(size, sourceDataSize - currentReadPosition)}
	}
	
}
