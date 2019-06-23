/*
 * SimpleInputStream.swift
 * SimpleStream
 *
 * Created by François Lamboley on 20/08/2017.
 */

import Foundation



public class SimpleInputStream : SimpleReadStream {
	
	public let sourceStream: InputStream
	
	public var currentReadPosition = 0
	
	/** The maximum total number of bytes to read from the stream. Can be changed
	after some bytes have been read.
	
	If set to nil, there are no limits.
	
	If set to a value lower than or equal to the current total number of bytes
	read, no more bytes will be read from the stream, and the
	`.streamReadSizeLimitReached` error will be thrown when trying to read more
	data (if the current internal buffer end is reached). */
	public var streamReadSizeLimit: Int?
	
	/** Initializes a SimpleInputStream.
	
	- Parameter stream: The stream to read data from. Must be opened.
	- Parameter bufferSize: The size of the buffer to use to read from the
	stream. Sometimes, more memory might be allocated if needed for some reads.
	- Parameter streamReadSizeLimit: The maximum number of bytes allowed to be
	read from the stream.
	*/
	public init(stream: InputStream, bufferSize size: Int, streamReadSizeLimit streamLimit: Int?) {
		assert(size > 0)
		
		sourceStream = stream
		
		defaultBufferSize = size
		defaultSizedBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
//		if defaultSizedBuffer == nil {throw SimpleStreamError.cannotAllocateMemory(size)}
		
		buffer = defaultSizedBuffer
		bufferSize = defaultBufferSize
		
		bufferStartPos = 0
		bufferValidLength = 0
		totalReadBytesCount = 0
		streamReadSizeLimit = streamLimit
	}
	
	deinit {
		if buffer != defaultSizedBuffer {buffer.deallocate()}
		defaultSizedBuffer.deallocate()
	}
	
	public func readData(size: Int, alwaysCopyBytes: Bool) throws -> Data {
		let data = try readDataNoCurrentPosIncrement(size: size, alwaysCopyBytes: alwaysCopyBytes)
		currentReadPosition += data.count
		return data
	}
	
	public func readData(upToDelimiters delimiters: [Data], matchingMode: DelimiterMatchingMode, includeDelimiter: Bool, alwaysCopyBytes: Bool) throws -> Data {
		let (minDelimiterLength, maxDelimiterLength) = delimiters.reduce((delimiters.first?.count ?? 0, 0), { (min($0.0, $1.count), max($0.1, $1.count)) })
		
		var unmatchedDelimiters = Array(delimiters.enumerated())
		var matchedDatas = [(delimiterIdx: Int, dataLength: Int)]()
		
		var searchOffset = 0
		repeat {
			assert(bufferValidLength - searchOffset >= 0)
			var bufferStart = buffer.advanced(by: bufferStartPos)
			let bufferSearchData = Data(bytesNoCopy: bufferStart.advanced(by: searchOffset), count: bufferValidLength - searchOffset, deallocator: .none)
			if let matchedLength = matchDelimiters(inData: bufferSearchData, usingMatchingMode: matchingMode, includeDelimiter: includeDelimiter, minDelimiterLength: minDelimiterLength, withUnmatchedDelimiters: &unmatchedDelimiters, matchedDatas: &matchedDatas) {
				let returnedLength = searchOffset + matchedLength
				bufferStartPos += returnedLength
				bufferValidLength -= returnedLength
				currentReadPosition += returnedLength
				return (alwaysCopyBytes ? Data(bytes: bufferStart, count: returnedLength) : Data(bytesNoCopy: bufferStart, count: returnedLength, deallocator: .none))
			}
			
			/* No confirmed match. We have to continue reading the data! */
			searchOffset = max(0, bufferValidLength - maxDelimiterLength + 1)
			
			if bufferStartPos + bufferValidLength >= bufferSize {
				/* The buffer is not big enough to hold new data... Let's move the
				 * data to the beginning of the buffer or create a new buffer. */
				if bufferStartPos > 0 {
					/* We can move the data to the beginning of the buffer. */
					assert(bufferStart != buffer)
					buffer.assign(from: bufferStart, count: bufferValidLength); bufferStartPos = 0; bufferStart = buffer
				} else {
					/* The buffer is not big enough anymore. We need to create a new,
					 * bigger one. */
					assert(bufferStartPos == 0)
					
					let oldBuffer = buffer
					
					bufferSize += min(bufferSize, 3*1024*1024 /* 3MB */)
					buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
//					if buffer == nil {throw SimpleStreamError.cannotAllocateMemory(size)}
					buffer.assign(from: bufferStart, count: bufferValidLength)
					bufferStart = buffer
					
					if oldBuffer != defaultSizedBuffer {oldBuffer.deallocate()}
				}
			}
			
			/* Let's read from the stream now! */
			let sizeToRead: Int
			let unmaxedSizeToRead = bufferSize - (bufferStartPos + bufferValidLength) /* The remaining space in the buffer */
			if let maxTotalReadBytesCount = streamReadSizeLimit {sizeToRead = min(unmaxedSizeToRead, max(0, maxTotalReadBytesCount - totalReadBytesCount) /* Number of bytes remaining allowed to be read */)}
			else                                                {sizeToRead =     unmaxedSizeToRead}
			
			assert(sizeToRead >= 0)
			if sizeToRead == 0 {/* End of the (allowed) data */break}
			let sizeRead = sourceStream.read(bufferStart.advanced(by: bufferValidLength), maxLength: sizeToRead)
			guard sizeRead >= 0 else {throw SimpleStreamError.streamReadError(streamError: sourceStream.streamError)}
			guard sizeRead >  0 else {/* End of the data */break}
			bufferValidLength += sizeRead
			totalReadBytesCount += sizeRead
			assert(streamReadSizeLimit == nil || totalReadBytesCount <= streamReadSizeLimit!)
		} while true
		
		if let returnedLength = findBestMatch(fromMatchedDatas: matchedDatas, usingMatchingMode: matchingMode) {
			bufferStartPos += returnedLength
			bufferValidLength -= returnedLength
			currentReadPosition += returnedLength
			return (alwaysCopyBytes ? Data(bytes: buffer.advanced(by: bufferStartPos), count: returnedLength) : Data(bytesNoCopy: buffer.advanced(by: bufferStartPos), count: returnedLength, deallocator: .none))
		}
		
		if delimiters.count > 0 {throw SimpleStreamError.delimitersNotFound}
		else {
			/* We return the whole data. */
			let returnedLength = bufferValidLength
			let bufferStart = buffer.advanced(by: bufferStartPos)
			
			currentReadPosition += bufferValidLength
			bufferStartPos += bufferValidLength
			bufferValidLength = 0
			
			return (alwaysCopyBytes ? Data(bytes: bufferStart, count: returnedLength) : Data(bytesNoCopy: bufferStart, count: returnedLength, deallocator: .none))
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/* Note: These two variables basically describe an UnsafeRawBufferPointer */
	private let defaultSizedBuffer: UnsafeMutablePointer<UInt8>
	private let defaultBufferSize: Int
	
	private var buffer: UnsafeMutablePointer<UInt8>
	private var bufferSize: Int
	
	private var bufferStartPos: Int
	private var bufferValidLength: Int
	
	/** The total number of bytes read from the source stream. */
	private var totalReadBytesCount = 0
	
	private func readDataNoCurrentPosIncrement(size: Int, alwaysCopyBytes: Bool) throws -> Data {
		let bufferStart = buffer.advanced(by: bufferStartPos)
		
		switch size {
		case let s where s <= bufferSize - bufferStartPos:
			/* The buffer is big enough to hold the size we want to read, from
			 * buffer start pos. */
			return try readDataInBigEnoughBuffer(
				dataSize: size,
				allowReadingMore: true,
				bufferHandling: (alwaysCopyBytes ? .copyBytes : .useBufferLeaveOwnership),
				buffer: buffer,
				bufferStartPos: &bufferStartPos,
				bufferValidLength: &bufferValidLength,
				bufferSize: bufferSize,
				totalReadBytesCount: &totalReadBytesCount,
				maxTotalReadBytesCount: streamReadSizeLimit,
				stream: sourceStream
			)
			
		case let s where s <= defaultBufferSize:
			/* The default sized buffer is enough to hold the size we want to read.
			 * Let's copy the current buffer to the beginning of the default sized
			 * buffer! And get rid of the old (bigger) buffer if needed. */
			defaultSizedBuffer.assign(from: bufferStart, count: bufferValidLength); bufferStartPos = 0
			if defaultSizedBuffer != buffer {
				buffer.deallocate()
				buffer = defaultSizedBuffer
				bufferSize = defaultBufferSize
			}
			return try readDataInBigEnoughBuffer(
				dataSize: size,
				allowReadingMore: true,
				bufferHandling: (alwaysCopyBytes ? .copyBytes : .useBufferLeaveOwnership),
				buffer: buffer,
				bufferStartPos: &bufferStartPos,
				bufferValidLength: &bufferValidLength,
				bufferSize: bufferSize,
				totalReadBytesCount: &totalReadBytesCount,
				maxTotalReadBytesCount: streamReadSizeLimit,
				stream: sourceStream
			)
			
		case let s where s <= bufferSize:
			/* The current buffer total size is enough to hold the size we want to
			 * read. However, we must relocate data in the buffer so the buffer
			 * start position is 0. */
			buffer.assign(from: bufferStart, count: bufferValidLength); bufferStartPos = 0
			return try readDataInBigEnoughBuffer(
				dataSize: size,
				allowReadingMore: true,
				bufferHandling: (alwaysCopyBytes ? .copyBytes : .useBufferLeaveOwnership),
				buffer: buffer,
				bufferStartPos: &bufferStartPos,
				bufferValidLength: &bufferValidLength,
				bufferSize: bufferSize,
				totalReadBytesCount: &totalReadBytesCount,
				maxTotalReadBytesCount: streamReadSizeLimit,
				stream: sourceStream
			)
			
		default:
			/* The buffer is not big enough to hold the data we want to read. We
			 * must create a new buffer. */
//			print("Got too small buffer of size \(bufferSize) to read size \(size) from buffer. Retrying with a bigger buffer.")
			/* NOT free'd here. Free'd later when set in Data, or by the readDataInBigEnoughBuffer function. */
			guard let m = malloc(size) else {throw SimpleStreamError.cannotAllocateMemory(size)}
			let biggerBuffer = m.assumingMemoryBound(to: UInt8.self)
			
			/* Copying data in our given buffer to the new buffer. */
			biggerBuffer.assign(from: bufferStart, count: bufferValidLength) /* size is greater than bufferSize. We know we will never overflow our own buffer using bufferValidLength */
			var newStartPos = 0, newValidLength = bufferValidLength
			
			bufferStartPos = 0; bufferValidLength = 0
			
			return try readDataInBigEnoughBuffer(
				dataSize: size,
				allowReadingMore: false, /* Not actually needed as the buffer size is exactly of the required size... */
				bufferHandling: .useBufferTakeOwnership,
				buffer: biggerBuffer,
				bufferStartPos: &newStartPos,
				bufferValidLength: &newValidLength,
				bufferSize: size,
				totalReadBytesCount: &totalReadBytesCount,
				maxTotalReadBytesCount: streamReadSizeLimit,
				stream: sourceStream
			)
		}
	}
	
}
