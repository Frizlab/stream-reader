/*
 * SimpleFileHandleStream.swift
 * SimpleStream
 *
 * Created by François Lamboley on 20/08/2017.
 */

import Foundation



extension FileHandle : GenericReadStream {
	
	/* *** Exception handling, adapted from https://stackoverflow.com/a/34958339
	 * Sadly, this does not actually work. The NSSetUncaughtExceptionHandler is
	 * meant to allow last-minute logging before everything crashes, but does not
	 * allow recovering from the exception.
	 *
	 * ObjC-exception handling in PURE swift is apparently not possible at all.
	 *
	 * (Also not this method changes the GLOBAL uncaught exception handler for
	 * all objects. We tried limiting the damage by using a queue and properly
	 * setting the handler only one read at a time, but other code could change
	 * the handler in parallel, fucking up everything.) */
//	static var frz_caughtException: NSException?
//	static var frz_existingHandler: (@convention(c) (NSException) -> Void)?
//	static var frz_exceptionQueue = DispatchQueue(label: "FileHandle ObjC Exception Catching in Swift")
//	static func frz_convertObjCExceptionToSwift<T>(in handler: () -> T) throws -> T {
//		/* We must dispatch on a sync serial queue because changing the uncaught
//		 * exception handler is a global operation. */
//		return try frz_exceptionQueue.sync{
//			assert(FileHandle.frz_existingHandler == nil)
//			assert(FileHandle.frz_caughtException == nil)
//
//			FileHandle.frz_existingHandler = NSGetUncaughtExceptionHandler()
//			NSSetUncaughtExceptionHandler{ exception in
//				FileHandle.frz_caughtException = exception
//			}
//			defer {
//				NSSetUncaughtExceptionHandler(FileHandle.frz_existingHandler)
//				FileHandle.frz_existingHandler = nil
//				FileHandle.frz_caughtException = nil
//			}
//
//			let ret = handler()
//			if let exception = FileHandle.frz_caughtException {
//				throw ObjCExceptionError(exception: exception)
//			}
//			return ret
//		}
//	}
	
	public func read(_ buffer: UnsafeMutableRawPointer, maxLength len: Int) throws -> Int {
		#if !os(macOS) && !os(iOS) && !os(watchOS) && !os(tvOS) && swift(>=5.1)
		let data = try read(upToCount: len) ?? Data()
		#else
		let data = readData(ofLength: len)
		#endif
		let sizeRead = data.count
		
		guard sizeRead > 0 else {return 0}
		data.withUnsafeBytes{ bytes in buffer.copyMemory(from: bytes, byteCount: sizeRead) }
		return sizeRead
	}
	
}

public typealias SimpleFileHandleStream = SimpleGenericReadStream



//struct ObjCExceptionError : Error {
//
//	var exception: NSException
//
//}
