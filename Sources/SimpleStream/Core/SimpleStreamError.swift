/*
 * SimpleStreamError.swift
 * SimpleStream
 *
 * Created by François Lamboley on 20/08/2017.
 */

import Foundation



public enum SimpleStreamError : Error {
	
	/**
	The stream ended before the required data size could be read.
	
	If `readSizeLimitReached` is true, there might be more data in the stream,
	but configuration stops from reading more. Otherwise the actual end of the
	stream has been reached. */
	case noMoreData(readSizeLimitReached: Bool)
	
	/** Cannot find any of the delimiters in the stream when using the
	`readData(upToDelimiters:...)` method. */
	case delimitersNotFound
	
	/** An error occurred reading the stream. */
	case streamReadError(streamError: Error?)
	
}
