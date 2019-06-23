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
	
	public func readData(size: Int, alwaysCopyBytes: Bool) throws -> Data {
		guard (sourceDataSize - currentReadPosition) >= size else {throw SimpleStreamError.noMoreData}
		
		return getNextSubData(size: size, alwaysCopyBytes: alwaysCopyBytes)
	}
	
	public func readData(upToDelimiters delimiters: [Data], matchingMode: DelimiterMatchingMode, includeDelimiter: Bool, alwaysCopyBytes: Bool) throws -> Data {
		let minDelimiterLength = delimiters.reduce(delimiters.first?.count ?? 0, { min($0, $1.count) })
		
		var unmatchedDelimiters = Array(delimiters.enumerated())
		var matchedDatas = [(delimiterIdx: Int, dataLength: Int)]()
		
		return try sourceData.withUnsafeBytes{ (bytes: UnsafePointer<UInt8>) -> Data in
			let searchedData = Data(bytesNoCopy: UnsafeMutablePointer<UInt8>(mutating: bytes).advanced(by: currentReadPosition), count: sourceDataSize-currentReadPosition, deallocator: .none)
			if let returnedLength = matchDelimiters(inData: searchedData, usingMatchingMode: matchingMode, includeDelimiter: includeDelimiter, minDelimiterLength: minDelimiterLength, withUnmatchedDelimiters: &unmatchedDelimiters, matchedDatas: &matchedDatas) {
				return getNextSubData(size: returnedLength, alwaysCopyBytes: alwaysCopyBytes)
			}
			if let returnedLength = findBestMatch(fromMatchedDatas: matchedDatas, usingMatchingMode: matchingMode) {
				return getNextSubData(size: returnedLength, alwaysCopyBytes: alwaysCopyBytes)
			}
			if delimiters.count == 0 {return getNextSubData(size: sourceDataSize - currentReadPosition, alwaysCopyBytes: alwaysCopyBytes)}
			else                     {throw SimpleStreamError.delimitersNotFound}
		}
	}
	
	private func getNextSubData(size: Int, alwaysCopyBytes: Bool) -> Data {
		let nextPosition = currentReadPosition + size
		let range = currentReadPosition..<nextPosition
		currentReadPosition = nextPosition
		
		if alwaysCopyBytes {return sourceData.subdata(in: range)}
		else               {return sourceData.withUnsafeBytes{ (bytes: UnsafePointer<UInt8>) -> Data in
			return Data(bytesNoCopy: UnsafeMutablePointer<UInt8>(mutating: bytes).advanced(by: range.lowerBound), count: size, deallocator: .none)
		}}
	}
	
}
