/*
 * StreamReaderError.swift
 * StreamReader
 *
 * Created by François Lamboley on 2017/08/20.
 */

import Foundation



public enum StreamReaderError : Error {
	
	/**
	 The stream would reach the end before the required data size could be read.
	 
	 If `wouldReachReadSizeLimit` is `true`, there might be more data in the stream which would allow to read the required size,
	  but the stream configuration does not allow it. */
	case notEnoughData(wouldReachReadSizeLimit: Bool)
	
	/** Cannot find any of the delimiters in the stream when using the `readData(upToDelimiters:...)` method. */
	case delimitersNotFound
	
	/**
	 When a read operation is done in a `GenericStreamReader` that would require reading from the underlying stream (not enough data in the buffer),
	  but the `underlyingStreamReadSizeLimit` is 0, this error is thrown. */
	case streamReadForbidden
	
	/** An error occurred reading the stream. */
	case streamReadError(streamError: Error?)
	
}

typealias Err = StreamReaderError
