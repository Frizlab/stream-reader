/*
 * Utils.swift
 * SimpleStream
 *
 * Created by François Lamboley on 20/08/2017.
 */

import Foundation



/* *****************************
   MARK: → For read data of size
   ***************************** */

internal enum BufferHandling {
	/** Copy the bytes from the buffer to the new Data object. */
	case copyBytes
	/** Create the Data with bytes from the buffer directly without copying.
	Buffer ownership stays to the caller, which means the Data object is
	invalid as soon as the buffer is released (and modified when the buffer is
	modified). */
	case useBufferLeaveOwnership
	/** Create the Data with bytes from the buffer directly without copying.
	Takes buffer ownership, which must have been alloc'd using alloc(). */
	case useBufferTakeOwnership
}

/** Reads and return the asked size from the buffer and completes with the
stream if needed. Uses the given buffer to read the first bytes and store the
bytes read from the stream if applicable. The buffer must be big enough to
contain the asked size from `bufferStartPos`.

- Parameter dataSize: The size of the data to return.
- Parameter allowReadingMore: If `true`, this method may read more data than what is actually needed from the stream.
- Parameter bufferHandling: How to handle the buffer for the Data object creation. See the `BufferHandling` enum.
- Parameter buffer: The buffer from which to start reading the bytes.
- Parameter bufferStartPos: Where to start reading the data from in the given buffer.
- Parameter bufferValidLength: The valid number of bytes from `bufferStartPos` in the buffer.
- Parameter bufferSize: The maximum number of bytes the buffer can hold (from the start of the buffer).
- Parameter totalReadBytesCount: The total number of bytes read from the stream so far. Incremented by the number of bytes read in the function on output.
- Parameter maxTotalReadBytesCount: The maximum number of total bytes allowed to be read from the stream.
- Parameter stream: The stream from which to read new bytes if needed.
- Throws: `SimpleStreamError` in case of error.
- Returns: The read data from the buffer or the stream if necessary.
*/
internal func readDataInBigEnoughBuffer(dataSize size: Int, allowReadingMore: Bool, bufferHandling: BufferHandling, buffer: UnsafeMutablePointer<UInt8>, bufferStartPos: inout Int, bufferValidLength: inout Int, bufferSize: Int, totalReadBytesCount: inout Int, maxTotalReadBytesCount: Int?, stream: InputStream) throws -> Data {
	assert(bufferSize >= size)
	
	let bufferStart = buffer.advanced(by: bufferStartPos)
	
	if bufferValidLength < size {
		/* We must read from the stream. */
		if let maxTotalReadBytesCount = maxTotalReadBytesCount, maxTotalReadBytesCount < totalReadBytesCount || size - bufferValidLength /* To read from stream */ > maxTotalReadBytesCount - totalReadBytesCount /* Remaining allowed bytes to be read */ {
			/* We have to read more bytes from the stream than allowed. We bail. */
			throw SimpleStreamError.streamReadSizeLimitReached
		}
		
		repeat {
			let sizeToRead: Int
			if !allowReadingMore {sizeToRead = size - bufferValidLength /* Checked to fit in the remaining bytes allowed to be read in "if" before this loop */}
			else {
				let unmaxedSizeToRead = bufferSize - (bufferStartPos + bufferValidLength) /* The remaining space in the buffer */
				if let maxTotalReadBytesCount = maxTotalReadBytesCount {sizeToRead = min(unmaxedSizeToRead, maxTotalReadBytesCount - totalReadBytesCount /* Number of bytes remaining allowed to be read */)}
				else                                                   {sizeToRead =     unmaxedSizeToRead}
			}
			assert(sizeToRead > 0)
			let sizeRead = stream.read(bufferStart.advanced(by: bufferValidLength), maxLength: sizeToRead)
			guard sizeRead > 0 else {
				if bufferHandling == .useBufferTakeOwnership {free(buffer)}
				throw (sizeRead == 0 ? SimpleStreamError.noMoreData : SimpleStreamError.streamReadError(streamError: stream.streamError))
			}
			bufferValidLength += sizeRead
			totalReadBytesCount += sizeRead
			assert(maxTotalReadBytesCount == nil || totalReadBytesCount <= maxTotalReadBytesCount!)
		} while bufferValidLength < size /* Reading until we have enough data in the buffer. */
	}
	
	bufferValidLength -= size
	bufferStartPos += size
	
	let ret: Data
	switch bufferHandling {
	case .copyBytes:               ret = Data(bytes: bufferStart, count: size)
	case .useBufferTakeOwnership:  ret = Data(bytesNoCopy: bufferStart, count: size, deallocator: .free)
	case .useBufferLeaveOwnership: ret = Data(bytesNoCopy: bufferStart, count: size, deallocator: .none)
	}
	return ret
}

/* ***********************************
   MARK: → For read data to delimiters
   *********************************** */

/* Returns nil if no confirmed matches were found, the length of the matched
 * data otherwise. */
internal func matchDelimiters(inData data: Data, usingMatchingMode matchingMode: DelimiterMatchingMode, includeDelimiter: Bool, minDelimiterLength: Int, withUnmatchedDelimiters unmatchedDelimiters: inout [(offset: Int, element: Data)], matchedDatas: inout [(delimiterIdx: Int, dataLength: Int)]) -> Int? {
	for delimiter in unmatchedDelimiters.reversed().enumerated() {
		if let range = data.range(of: delimiter.element.element) {
			/* Found one of the delimiter. Let's see what we do with it... */
			let matchedLength = range.lowerBound + (includeDelimiter ? delimiter.element.element.count : 0)
			switch matchingMode {
			case .anyMatchWins:
				/* We found a match. With this matching mode, this is enough!
				 * We simply return here the data we found, no questions asked. */
				return matchedLength
				
			case .shortestDataWins:
				/* We're searching for the shortest match. A match of 0 is
				 * necessarily the shortest! So we can return straight away when
				 * we find a 0-length match. */
				guard matchedLength > (includeDelimiter ? minDelimiterLength : 0) else {return matchedLength}
				unmatchedDelimiters.remove(at: delimiter.offset)
				matchedDatas.append((delimiterIdx: delimiter.element.offset, dataLength: matchedLength))
				
			case .longestDataWins:
				unmatchedDelimiters.remove(at: delimiter.offset)
				matchedDatas.append((delimiterIdx: delimiter.element.offset, dataLength: matchedLength))
				
			case .firstMatchingDelimiterWins:
				guard delimiter.offset > 0 else {
					/* We're searching for the first matching delimiter. If the
					 * first delimiter matches, we can return the matched data
					 * straight away! */
					return matchedLength
				}
				unmatchedDelimiters.remove(at: delimiter.offset)
				matchedDatas.append((delimiterIdx: delimiter.element.offset, dataLength: matchedLength))
			}
		}
	}
	
	/* Let's search for a confirmed match. We can only do that if all the
	 * delimiters have been matched. All other obvious cases have been taken
	 * care of above. */
	guard unmatchedDelimiters.count == 0 else {return nil}
	return findBestMatch(fromMatchedDatas: matchedDatas, usingMatchingMode: matchingMode)
}

internal func findBestMatch(fromMatchedDatas matchedDatas: [(delimiterIdx: Int, dataLength: Int)], usingMatchingMode matchingMode: DelimiterMatchingMode) -> Int? {
	/* We need to have at least one match in order to be able to return smthg. */
	guard let firstMatchedData = matchedDatas.first else {return nil}
	
	switch matchingMode {
	case .anyMatchWins: fatalError("INTERNAL LOGIC FAIL!") /* Any match is a trivial case and should have been filtered prior calling this method... */
	case .shortestDataWins: return matchedDatas.reduce(firstMatchedData, { $0.dataLength < $1.dataLength ? $0 : $1 }).dataLength
	case .longestDataWins:  return matchedDatas.reduce(firstMatchedData, { $0.dataLength > $1.dataLength ? $0 : $1 }).dataLength
	case .firstMatchingDelimiterWins: return matchedDatas.reduce(firstMatchedData, { $0.delimiterIdx < $1.delimiterIdx ? $0 : $1 }).dataLength
	}
}
