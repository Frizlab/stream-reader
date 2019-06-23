/*
 * SimpleDataStream.swift
 * SimpleStream
 *
 * Created by François Lamboley on 20/08/2017.
 */

import Foundation



public class SimpleDataStream : SimpleReadStream {
	
	public let sourceData: Data
	public let sourceDataSize: Int
	public var currentReadPosition = 0
	
	public init(data: Data) {
		sourceData = data
		sourceDataSize = sourceData.count
	}
	
	public func readData<T>(size: Int, _ handler: (UnsafeRawBufferPointer) throws -> T) throws -> T {
		assert(size >= 0)
		guard (sourceDataSize - currentReadPosition) >= size else {throw SimpleStreamError.noMoreData}
		
		return try sourceData.withUnsafeBytes{ bytes in
			let ret = UnsafeRawBufferPointer(start: bytes.baseAddress! + currentReadPosition, count: size)
			currentReadPosition += size
			return try handler(ret)
		}
	}
	
	public func readData<T>(upToDelimiters delimiters: [Data], matchingMode: DelimiterMatchingMode, includeDelimiter: Bool, _ handler: (UnsafeRawBufferPointer, Data) throws -> T) throws -> T {
		guard delimiters.count > 0 else {
			/* When there are no delimiters, we simply read the stream to the end. */
			return try readData(size: sourceDataSize-currentReadPosition, { ret in try handler(ret, Data()) })
		}
		
		var unmatchedDelimiters = Array(delimiters.enumerated())
		let minDelimiterLength = delimiters.map{ $0.count }.min() ?? 0
		var matchedDatas = [Match]()
		
		return try sourceData.withUnsafeBytes{ bytes in
			let searchedData = UnsafeRawBufferPointer(start: bytes.baseAddress! + currentReadPosition, count: sourceDataSize-currentReadPosition)
			if let match = matchDelimiters(inData: searchedData, usingMatchingMode: matchingMode, includeDelimiter: includeDelimiter, minDelimiterLength: minDelimiterLength, withUnmatchedDelimiters: &unmatchedDelimiters, matchedDatas: &matchedDatas) {
				return try readData(size: match.matchedDataLength, { ret in try handler(ret, delimiters[match.delimiterIdx]) })
			}
			/* matchDelimiters did not find an indisputable match. However, we have
			 * fed all the data we have to it. We cannot find more matches! We
			 * simply return the best match we got. */
			if let match = findBestMatch(fromMatchedDatas: matchedDatas, usingMatchingMode: matchingMode) {
				return try readData(size: match.matchedDataLength, { ret in try handler(ret, delimiters[match.delimiterIdx]) })
			}
			throw SimpleStreamError.delimitersNotFound
		}
	}
	
}
