/*
 * GenericStreamReader.swift
 * StreamReader
 *
 * Created by François Lamboley on 20/08/2017.
 */

import Foundation



public protocol GenericReadStream {
	
	/**
	Read at most maxLength bytes from the stream and put it at the given memory
	location. (Indeed the given buffer must be at minimum of size `len`.)
	
	- Important: The method might rebind the memory from the pointer.
	- Parameters:
	  - buffer: The memory location in which to read the data.
	  - len: The maximum number of bytes to read.
	- Returns: The number of bytes acutally read.
	- Throws: In case of an error reading the stream, throws an error. */
	func read(_ buffer: UnsafeMutableRawPointer, maxLength len: Int) throws -> Int
	
}


public final class GenericStreamReader : StreamReader {
	
	public let sourceStream: GenericReadStream
	
	/** The buffer size the client wants. Sometimes we have to allocated a bigger
	buffer though because the requested data would not fit in this size. */
	public let defaultBufferSize: Int
	/** The number of bytes by which to increment the current buffer size when
	reading up to given delimiters and there is no space left in the buffer. */
	public var bufferSizeIncrement: Int
	
	/**
	Whether `EOF` has been reached, either because of `readSizeLimit` constraint,
	or because end of underlying stream has been reached. See doc of
	`readSizeLimit` for a few more info. */
	public private(set) var streamHasReachedEOF = false
	public private(set) var currentStreamReadPosition: Int
	public private(set) var currentReadPosition = 0
	
	/**
	The maximum number of bytes that can be returned by the read methods (when
	updating read position), and also the number of bytes that can be read from
	the underlying stream.
	
	Changing this to a greater value will force `streamHasReachedEOF` to `false`,
	but next read might reach `EOF` directly regardless.
	
	Changing this to a lower value will not change `streamHasReachedEOF` at all. */
	public var readSizeLimit: Int? {
		didSet {
			if readSizeLimit ?? Int.max > oldValue ?? Int.max {
				streamHasReachedEOF = false
			}
		}
	}
	/**
	The max size to read from the stream with a single read. Set to `nil` for no
	max.
	
	Changing this can be useful for instance for a FileHandle stream because
	FileHandle will read _exactly_ the size it is asked to, blocking until the
	number of bytes required are retrieved or the end of the file is reached.
	
	By default this stream reader reads the maximum size it can in its internal
	buffer, so reading from stdin via a FileHandle will block until the buffer is
	full, unless this property is set to a low value (`1` for instance). */
	public var underlyingStreamReadSizeLimit: Int?
	
	/**
	Initializes a `GenericStreamReader`.
	
	- Parameter stream: The stream to read data from.
	- Parameter bufferSize: The size of the buffer to use to read from the
	stream. Sometimes, more memory might be allocated if needed for some reads.
	Must be strictly greater than 0.
	- Parameter bufferSizeIncrement: The number of bytes to increase the buffer
	by when the current buffer size is not big enough. Must be strictly greater
	than 0.
	- Parameter readSizeLimit: The maximum number of bytes allowed to be read
	from the stream. Cannot be negative.
	- Parameter underlyingStreamReadSizeLimit: The max size to read from the
	stream with a single read. Cannot be negative. If 0, the reader is
	effectively forbidden from reading the underlying stream. If a read operation
	is done that would require reading from the stream (not enough data in the
	buffer), the `streamReadForbidden` error is thrown. */
	public init(stream: GenericReadStream, bufferSize size: Int, bufferSizeIncrement sizeIncrement: Int, readSizeLimit limit: Int? = nil, underlyingStreamReadSizeLimit streamReadSizeLimit: Int? = nil) {
		assert(size > 0)
		assert(sizeIncrement > 0)
		assert(limit == nil || limit! >= 0)
		assert(streamReadSizeLimit == nil || streamReadSizeLimit! >= 0)
		
		sourceStream = stream
		
		defaultBufferSize = size
		bufferSizeIncrement = sizeIncrement
		
		buffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<UInt8>.alignment)
		bufferSize = size
		bufferStartPos = 0
		bufferValidLength = 0
		
		currentStreamReadPosition = 0
		
		readSizeLimit = limit
		underlyingStreamReadSizeLimit = streamReadSizeLimit
	}
	
	deinit {
		buffer.deallocate()
		bufferSize = 0
	}
	
	public func clearStreamHasReachedEOF() {
		streamHasReachedEOF = false
	}
	
	/**
	Reads `size` bytes from the underlying stream into the internal buffer and
	returns the number of bytes read.
	
	The `readSizeLimit` and `underlyingStreamReadSizeLimit` variables are
	respected when using this method.
	
	- Important: If the buffer is big enough, might read _more_ bytes than asked.
	Can also read less (if the end of the stream is reached, or if only one read
	is allowed and read returned less than asked).
	
	- Parameter size: The number of bytes you want the buffer to be filled with
	from the stream.
	- Parameter allowMoreThanOneRead: If `true`, the method will read from the
	stream until the asked size is read or the end of stream is reached.
	- Returns: The number of bytes acutally read from the stream. */
	public func readStreamInBuffer(size: Int, allowMoreThanOneRead: Bool = false) throws -> Int {
		let previousBufferValidLenth = bufferValidLength
		_ = try readDataNoCurrentPosIncrement(size: (bufferValidLength + size), readContraints: allowMoreThanOneRead ? .readUntilSizeOrStreamEnd : .readFromStreamMaxOnce)
		let ret = (bufferValidLength - previousBufferValidLenth)
		assert(ret >= 0, "INTERNAL LOGIC ERROR")
		return ret
	}
	
	public func readData<T>(size: Int, allowReadingLess: Bool, updateReadPosition: Bool, _ handler: (UnsafeRawBufferPointer) throws -> T) throws -> T {
		let ret = try readDataNoCurrentPosIncrement(size: size, readContraints: allowReadingLess ? .readUntilSizeOrStreamEnd : .getExactSize)
		assert(ret.count <= bufferValidLength, "INTERNAL LOGIC ERROR")
		assert(ret.count <= size, "INTERNAL LOGIC ERROR")
		if updateReadPosition {
			currentReadPosition += ret.count
			bufferValidLength -= ret.count
			bufferStartPos += ret.count
		}
		return try handler(ret)
	}
	
	public func readData<T>(upTo delimiters: [Data], matchingMode: DelimiterMatchingMode, failIfNotFound: Bool, includeDelimiter: Bool, updateReadPosition: Bool, _ handler: (UnsafeRawBufferPointer, Data) throws -> T) throws -> T {
		let (minDelimiterLength, maxDelimiterLength) = delimiters.reduce((delimiters.first?.count ?? 0, 0), { (min($0.0, $1.count), max($0.1, $1.count)) })
		
		var unmatchedDelimiters = Array(delimiters.enumerated())
		var matchedDatas = [Match]()
		
		var searchOffset = 0
		repeat {
			assert(bufferValidLength - searchOffset >= 0, "INTERNAL LOGIC ERROR")
			let bufferStart = buffer + bufferStartPos
			let bufferSearchData = UnsafeRawBufferPointer(start: bufferStart + searchOffset, count: bufferValidLength - searchOffset)
			if let match = matchDelimiters(inData: bufferSearchData, dataStartOffset: searchOffset, usingMatchingMode: matchingMode, includeDelimiter: includeDelimiter, minDelimiterLength: minDelimiterLength, withUnmatchedDelimiters: &unmatchedDelimiters, matchedDatas: &matchedDatas) {
				if updateReadPosition {
					bufferStartPos += match.length
					bufferValidLength -= match.length
					currentReadPosition += match.length
				}
				return try handler(UnsafeRawBufferPointer(start: bufferStart, count: match.length), delimiters[match.delimiterIdx])
			}
			
			/* No confirmed match. We have to continue reading the data! */
			searchOffset = max(0, bufferValidLength - maxDelimiterLength + 1)
			
			let sizeInBufferBeforeRead = bufferValidLength
			let sizeRemainingInBuffer = bufferSize - (bufferStartPos + bufferValidLength)
			let sizeToRead = (sizeRemainingInBuffer > 0 ? sizeRemainingInBuffer : bufferSizeIncrement)
			let sizeRead = try readDataNoCurrentPosIncrement(size: sizeInBufferBeforeRead + sizeToRead, readContraints: .readFromStreamMaxOnce).count - sizeInBufferBeforeRead
			guard sizeRead > 0 else {/* End of the data */break}
			assert(sizeRead >= 0)
		} while true
		
		if let match = findBestMatch(fromMatchedDatas: matchedDatas, usingMatchingMode: matchingMode) {
			let ret = try handler(UnsafeRawBufferPointer(start: buffer + bufferStartPos, count: match.length), delimiters[match.delimiterIdx])
			if updateReadPosition {
				bufferStartPos += match.length
				bufferValidLength -= match.length
				currentReadPosition += match.length
			}
			return ret
		}
		
		guard delimiters.isEmpty || !failIfNotFound else {
			throw StreamReaderError.delimitersNotFound
		}
		
		/* No match, no error on no match, we return the whole data. */
		let returnedLength = bufferValidLength
		let bufferStart = buffer + bufferStartPos
		
		if updateReadPosition {
			currentReadPosition += bufferValidLength
			bufferStartPos += bufferValidLength
			bufferValidLength = 0
		}
		
		return try handler(UnsafeRawBufferPointer(start: bufferStart, count: returnedLength), Data())
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/* Note: We choose not to use UnsafeMutableRawBufferPointer as we’ll do many
	 *       pointer arithmetic, it wouldn’t be very practical (mostly because
	 *       UnsafeMutableRawBufferPointer’s baseAdress is optional). */
	
	/** The current buffer in use. Its size should be `defaultBufferSize` most of
	the time. */
	private var buffer: UnsafeMutableRawPointer
	private var bufferSize: Int
	private var bufferStartPos: Int
	private var bufferValidLength: Int
	
	private enum ReadContraints {
		case getExactSize
		case readUntilSizeOrStreamEnd
		case readFromStreamMaxOnce
		
		var allowReadingLess: Bool {
			return self != .getExactSize
		}
	}
	
	private func readDataNoCurrentPosIncrement(size: Int, readContraints: ReadContraints) throws -> UnsafeRawBufferPointer {
		assert(size >= 0)
		/* If we want to read 0 bytes, whether we’ve reached EOF or we are allowed
		 * to read more bytes, we can return directly an empty buffer. */
		guard size > 0 else {return UnsafeRawBufferPointer(start: nil, count: 0)}
		/* We check reading the given size is allowed. */
		let allowedToBeRead = readSizeLimit.flatMap{ $0 - currentReadPosition }
		if let allowedToBeRead = allowedToBeRead, allowedToBeRead < size {
			guard readContraints.allowReadingLess else {
				throw StreamReaderError.notEnoughData(wouldReachReadSizeLimit: true)
			}
			if allowedToBeRead <= 0 {
				streamHasReachedEOF = true
			}
		}
		/* If we have reached EOF (not of the stream, the one of the reader), we
		 * know there is nothing more to return. */
		guard !hasReachedEOF else {
			if readContraints.allowReadingLess {return UnsafeRawBufferPointer(start: nil, count: 0)}
			else                               {throw StreamReaderError.notEnoughData(wouldReachReadSizeLimit: true)}
		}
		assert(allowedToBeRead == nil || allowedToBeRead! >= 0)
		
		/* We constrain the size to the maximum allowed to be read. */
		let size = allowedToBeRead.flatMap{ min(size, $0) } ?? size
		return try readDataNoCurrentPosIncrementAssumingSizeIsConstrainedToAllowed(size: size, readContraints: readContraints)
	}
	
	/**
	Reads and returns the asked size from buffer and completes with the stream if
	needed. Uses the buffer to read the first bytes and store the bytes read from
	the stream if applicable. If the buffer is not big enough, it will be resized
	to be able to hold the required size.
	
	- Parameter size: The size of the data to return. Assumed to be small enough
	not to break the `readSizeLimit` contract.
	- Parameter readContraints: Read contraints on the stream.
	- Throws: `StreamReaderError` in case of error.
	- Returns: The read data from the buffer or the stream if necessary. */
	private func readDataNoCurrentPosIncrementAssumingSizeIsConstrainedToAllowed(size: Int, readContraints: ReadContraints) throws -> UnsafeRawBufferPointer {
		let bufferStart = buffer + bufferStartPos
		
		switch size {
		case let s where s <= bufferSize - bufferStartPos:
			/* The buffer is big enough to hold the size we want to read, from
			 * buffer start pos. */
			return try readDataNoCurrentPosIncrementAssumingSizeIsConstrainedToAllowedAndBufferIsBigEnough(dataSize: size, readContraints: readContraints)
			
		case let s where s <= defaultBufferSize:
			/* The default sized buffer is enough to hold the size we want to read.
			 * Let's copy the current buffer to the beginning of the default sized
			 * buffer! And get rid of the old (bigger) buffer if needed. */
			if bufferSize != defaultBufferSize {
				assert(bufferSize > defaultBufferSize, "INTERNAL LOGIC ERROR")
				
				let oldBuffer = buffer
				buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: MemoryLayout<UInt8>.alignment)
				buffer.copyMemory(from: bufferStart, byteCount: bufferValidLength)
				bufferSize = defaultBufferSize
				oldBuffer.deallocate()
			} else {
				buffer.copyMemory(from: bufferStart, byteCount: bufferValidLength)
			}
			bufferStartPos = 0
			return try readDataNoCurrentPosIncrementAssumingSizeIsConstrainedToAllowedAndBufferIsBigEnough(dataSize: size, readContraints: readContraints)
			
		case let s where s <= bufferSize:
			/* The current buffer total size is enough to hold the size we want to
			 * read. However, we must relocate data in the buffer so the buffer
			 * start position is 0. */
			buffer.copyMemory(from: bufferStart, byteCount: bufferValidLength)
			bufferStartPos = 0
			return try readDataNoCurrentPosIncrementAssumingSizeIsConstrainedToAllowedAndBufferIsBigEnough(dataSize: size, readContraints: readContraints)
			
		default:
			/* The buffer is not big enough to hold the data we want to read. We
			 * must create a new buffer. */
//			print("Got too small buffer of size \(bufferSize) to read size \(size) from buffer. Retrying with a bigger buffer.")
			let oldBuffer = buffer
			buffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<UInt8>.alignment)
			buffer.copyMemory(from: bufferStart, byteCount: bufferValidLength)
			bufferSize = size
			bufferStartPos = 0
			oldBuffer.deallocate()
			
			return try readDataNoCurrentPosIncrementAssumingSizeIsConstrainedToAllowedAndBufferIsBigEnough(dataSize: size, readContraints: readContraints)
		}
	}
	
	/**
	Reads and returns the asked size from buffer and completes with the stream if
	needed. Uses the buffer to read the first bytes and store the bytes read from
	the stream if applicable. The buffer must be big enough to contain the asked
	size **from** `bufferStartPos`.
	
	Will throw if allow reading less is false and end of stream or stream read
	limit is reached.
	
	- Parameter dataSize: The size of the data to return.
	- Parameter readContraints: Read contraints on the stream.
	- Throws: `StreamReaderError` in case of error.
	- Returns: The read data from the buffer or the stream if necessary. */
	private func readDataNoCurrentPosIncrementAssumingSizeIsConstrainedToAllowedAndBufferIsBigEnough(dataSize size: Int, readContraints: ReadContraints) throws -> UnsafeRawBufferPointer {
		assert(bufferSize - bufferStartPos >= size)
		
		let bufferStart = buffer + bufferStartPos
		if bufferValidLength < size {
			/* The buffer does not contain enough: we read from the stream. */
			repeat {
				assert(size - bufferValidLength > 0, "INTERNAL LOGIC ERROR")
				/* We try and read as much bytes as possible from the stream */
				let unconstrainedSizeToRead = bufferSize - (bufferStartPos + bufferValidLength)
				/* But we have to constrain to the size allowed to be read */
				let sizeAllowedToBeRead: Int
				if let readSizeLimit = readSizeLimit {sizeAllowedToBeRead = min(readSizeLimit - currentStreamReadPosition, unconstrainedSizeToRead)}
				else                                 {sizeAllowedToBeRead =                                                unconstrainedSizeToRead}
				/* And to the underlying stream read size limit */
				let sizeToRead: Int
				if let readLimit = underlyingStreamReadSizeLimit {sizeToRead = min(readLimit, sizeAllowedToBeRead)}
				else                                             {sizeToRead =                sizeAllowedToBeRead}
				assert(sizeToRead <= bufferSize - (bufferStartPos + bufferValidLength), "INTERNAL LOGIC ERROR")
				
				guard sizeToRead > 0 else {
					assert(underlyingStreamReadSizeLimit! == 0, "INTERNAL LOGIC ERROR")
					throw StreamReaderError.streamReadForbidden
				}
				
				let sizeRead = try sourceStream.read(bufferStart + bufferValidLength, maxLength: sizeToRead)
				bufferValidLength += sizeRead
				currentStreamReadPosition += sizeRead
				if sizeRead == 0 {streamHasReachedEOF = true}
				assert(readSizeLimit == nil || currentStreamReadPosition <= readSizeLimit!)
				
				if readContraints == .readFromStreamMaxOnce {break}
				guard sizeRead > 0 else {
					if readContraints.allowReadingLess {break}
					else                               {throw StreamReaderError.notEnoughData(wouldReachReadSizeLimit: false)}
				}
			} while bufferValidLength < size /* Reading until we have enough data in the buffer. */
		}
		
		assert(readContraints.allowReadingLess || bufferValidLength >= size)
		return UnsafeRawBufferPointer(start: bufferStart, count: min(bufferValidLength, size))
	}
	
}
