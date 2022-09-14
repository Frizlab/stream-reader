/*
 * Utils.swift
 * StreamReader
 *
 * Created by François Lamboley on 20/08/2017.
 */

import Foundation



internal struct Match {
	
	var length: Int
	
	/* For optimization puproses. */
	var delimiterIdx: Int
	var lengthNoDelimiter: Int
	
}

internal func cleanupDelimiters(_ delimiters: [Data], forMatchingMode matchingMode: DelimiterMatchingMode, includingDelimiter: Bool) -> [Data] {
	/* First we remove delimiters duplicates, keeping the order (e.g. [1,2,3,2,1] -> [1,2,3]). */
//	let delimiters = NSOrderedSet(array: delimiters).array as! [Data]
	var found = Set<Data>()
	let delimiters = delimiters.filter{ found.insert($0).inserted }
	
	switch (matchingMode, includingDelimiter) {
		case (.shortestDataWins, false):
			return delimiters.filter{ delimiter in
				!delimiters.contains(where: { !$0.isEmpty && $0 != delimiter && delimiter.starts(with: $0) }) /* If the delimiter has another delimiter as a prefix, we do not keep it. */
			}
			
		case (.longestDataWins, true):
			return delimiters.filter{ delimiter in
				!delimiters.contains(where: { !$0.isEmpty && $0 != delimiter && delimiter.reversed().starts(with: $0.reversed()) }) /* If the delimiter has another delimiter as a suffix, we do not keep it. */
			}
			
		case (.firstMatchingDelimiterWins, _), (.anyMatchWins, _), (.shortestDataWins, true), (.longestDataWins, false):
			/* TODO: Find potential delimiter optimizations for these cases.
			 *       There are probably things to do for the shortestDataWins and longestDataWins cases.
			 *       For the anyMatchWins, there are none.
			 *       For the firstMatchingDelimiterWins I’m not sure… */
			return delimiters
	}
}

/* Returns nil if no confirmed matches were found, the length of the matched data otherwise.
 * The given unmatched delimiters must be 1/ cleaned up for the given matching mode and co and 2/ gotten rid of the empty delimiters. */
internal func matchDelimiters(inData data: UnsafeRawBufferPointer, dataStartOffset: Int, usingMatchingMode matchingMode: DelimiterMatchingMode, includeDelimiter: Bool, minDelimiterLength: Int, withUnmatchedDelimiters unmatchedDelimiters: inout [(offset: Int, element: Data)], bestMatch: inout Match?) -> Match? {
	assert(!unmatchedDelimiters.contains(where: { $0.element.isEmpty }))
	assert(cleanupDelimiters(unmatchedDelimiters.map{ $0.element }, forMatchingMode: matchingMode, includingDelimiter: includeDelimiter) == unmatchedDelimiters.map{ $0.element })
	
	guard minDelimiterLength > 0, data.count >= minDelimiterLength else {
		/* No need to search if all the delimiters are empty or if there are less data than the minimum delimiter length: nothing matches. */
		return nil
	}
	
	/* We implement the search ourselves to be able to early bail when possible. */
	let start = data.baseAddress!
	var hasDelimitersTooBigThatCouldMatch = false
	let end = data.baseAddress!.advanced(by: data.count - minDelimiterLength)
	for (curDataIdx, curPos) in (start...end).enumerated() {
		let curLength = dataStartOffset + curDataIdx
		let curRemainingSpace = data.count - curDataIdx
		assert(curRemainingSpace > 0) /* minDelimiterLength is >0, so there should always be at least 1 byte available. */
		/* Reversed enumeration in order to be able to remove an element from the unmatchedDelimiters array while still enumerating it and keeping valid indexes. */
		for (delimiterIdx, delimiter) in unmatchedDelimiters.enumerated().reversed() {
			let delimiterLength = delimiter.element.count
			/* If the delimiter is empty or bigger than the remaining space it cannot match. */
			guard delimiterLength > 0 else {continue}
			guard delimiterLength <= curRemainingSpace else {
				/* The delimiter is too big to compare to the whole data.
				 * If the delimiter is a potential match (the data available is a prefix of the delimiter),
				 *  we’ll keep a hint that we have a delimiter that could match. */
				hasDelimitersTooBigThatCouldMatch = (
					hasDelimitersTooBigThatCouldMatch ||
					Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: curPos), count: curRemainingSpace, deallocator: .none) == delimiter.element[0..<curRemainingSpace]
				)
				continue
			}
			if Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: curPos), count: delimiterLength, deallocator: .none) == delimiter.element {
				/* We have a match! */
				let match = Match(
					length: curLength + (includeDelimiter ? delimiterLength : 0),
					delimiterIdx: delimiter.offset, lengthNoDelimiter: curLength
				)
				unmatchedDelimiters.remove(at: delimiterIdx) /* Probably triggers CoW. Should we do better? */
				
				/* Obvious use cases where we can return the match at once. */
				switch matchingMode {
					case .anyMatchWins,
							/* If the delimiter is *not* included AND we do not have a potential match by a delimiter too big,
							 *  whatever we could find next would be bigger than our current match, so we can return it. */
						  .shortestDataWins where !includeDelimiter && !hasDelimitersTooBigThatCouldMatch:
						assert(bestMatch.flatMap{ $0.length >= match.length } ?? true)
						bestMatch = match
						return match
						
					case .shortestDataWins:
						if (bestMatch.flatMap{ $0.length > match.length } ?? true) {
							bestMatch = match
							/* Early bail if the match has the minimum length possible. */
							if match.length == (includeDelimiter ? minDelimiterLength : 0) {
								return match
							}
						}
						/* We process another early bail possibilities once all the delimiters have been seen. */
						
					case .firstMatchingDelimiterWins:
						if (bestMatch.flatMap{ $0.delimiterIdx > match.delimiterIdx } ?? true) {
							bestMatch = match
							/* Early bail if the first delimiter has matched. */
							if match.delimiterIdx == 0 {
								return match
							}
						}
						/* No need to keep the delimiters whose offset is >delimiter.offset; we know we won’t choose them.
						 * Note: The removal will be applied at the next byte check (the enumeration of unmatchedDelimiters enumerates on a copy). */
						unmatchedDelimiters.removeAll{ $0.offset > delimiter.offset }
						
					case .longestDataWins:
						if (bestMatch.flatMap{ $0.length < match.length } ?? true) {
							bestMatch = match
							/* No known early bails. I don’t think there are any. */
						}
				}
			}
		}
		/*
		 *      f
		 *     ef
		 *    def
		 *   cde
		 *   cdef
		 *   cdefg
		 * abcdef[gh]
		 *
		 * Let’s see if we have enough info to bail early. */
		switch matchingMode {
			case .shortestDataWins:
				if let bestMatch, includeDelimiter {
					/* We have a match and we include the delimiters (the case where we do not include the delimiter is already taken care of).
					 * Let’s try to bail early. */
					
					/* First we remove the unmatched delimiters which would give a longer match than the best one we have now. */
					unmatchedDelimiters.removeAll(where: { delimiter in
						let potentialMatchLength = curLength + delimiter.element.count
						return potentialMatchLength >= bestMatch.length
					})
					if unmatchedDelimiters.isEmpty {
						return bestMatch
					}
				}
				
			case .anyMatchWins, .longestDataWins, .firstMatchingDelimiterWins:
				(/* No known early bail. */)
		}
	}
	
	/* Let's search for a confirmed match.
	 * We can only do that if all the delimiters have been matched.
	 * All other early bail cases have been taken care of above. */
	guard unmatchedDelimiters.count == 0 else {return nil}
	return bestMatch
}
