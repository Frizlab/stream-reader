/*
 * SimpleStreamError.swift
 * SimpleStream
 *
 * Created by François Lamboley on 20/08/2017.
 */

import Foundation



public enum SimpleStreamError : Error {
	
	/** The stream ended before the required data size could be read. */
	case noMoreData
	
	/** The maximum number of bytes allowed to be read from the stream have been
	read.
	
	- Important: Do not assume the position of the stream is necessarily at the
	max number of bytes allowed to be read. For optimization reasons, we might
	throw this error before all the bytes have actually been read from the
	stream. */
	case streamReadSizeLimitReached
	
	/** An error occurred reading the stream. */
	case streamReadError(streamError: Error?)
	
	/** Cannot find any of the delimiters in the stream when using the
	`readData(upToDelimiters:...)` method. (All of the stream has been read, or
	the stream limit has been reached if this error is thrown.) */
	case delimitersNotFound
	
}
