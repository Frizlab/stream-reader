/*
 * Utils.swift
 * StreamReader
 *
 * Created by François Lamboley on 20/08/2017.
 */

import Foundation



internal struct Match {
	
	var length: Int
	var delimiterIdx: Int
	var delimiterLength: Int
	
}

/* Returns nil if no confirmed matches were found, the length of the matched data otherwise. */
internal func matchDelimiters(inData data: UnsafeRawBufferPointer, dataStartOffset: Int, usingMatchingMode matchingMode: DelimiterMatchingMode, includeDelimiter: Bool, minDelimiterLength: Int, withUnmatchedDelimiters unmatchedDelimiters: inout [(offset: Int, element: Data)], matchedDatas: inout [Match]) -> Match? {
	guard minDelimiterLength > 0, data.count >= minDelimiterLength else {
		/* No need to search if all the delimiters are empty or if there are less data than the minimum delimiter length: nothing matches. */
		return nil
	}
	
	/* We implement the search ourselves to be able to early bail when possible. */
	let start = data.baseAddress!
	let end = data.baseAddress!.advanced(by: data.count - minDelimiterLength)
	for (curDataIdx, curPos) in (start...end).enumerated() {
		let curRemainingSpace = data.count - curDataIdx
		assert(curRemainingSpace > 0) /* minDelimiterLength is >0, so there should always be at least 1 byte available. */
		/* Reversed enumeration in order to be able to remove an element from the unmatchedDelimiters array while still enumerating it and keeping valid indexes. */
		for (delimiterIdx, delimiter) in unmatchedDelimiters.enumerated().reversed() {
			let delimiterLength = delimiter.element.count
			/* TODO: Is it as efficient to do the test below or test for >0 and <=curRemainingSpace? */
			/* If the delimiter is empty or bigger than the remaining space it cannot match. */
			guard (1...curRemainingSpace).contains(delimiterLength) else {
				/* TODO: Should we remove the delimiters that cannot match anymore to avoid processing them for each bytes? */
				continue
			}
			if Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: curPos), count: delimiterLength, deallocator: .none) == delimiter.element {
				/* We have a match! */
				let matchedLengthNoDelimiter = dataStartOffset + curDataIdx
				let match = Match(length: matchedLengthNoDelimiter + (includeDelimiter ? delimiterLength : 0), delimiterIdx: delimiter.offset, delimiterLength: delimiter.element.count)
				unmatchedDelimiters.remove(at: delimiterIdx) /* Probably triggers CoW. Should we do better? */
				matchedDatas.append(match)
				
				/* Obvious use cases where we can return the match at once. */
				switch matchingMode {
					case .anyMatchWins:
						return match
						
					case .shortestDataWins:
						if matchedLengthNoDelimiter == 0 {
							return match
						}
						
					case .firstMatchingDelimiterWins:
						if delimiter.offset == 0 {
							return match
						}
						/* No need to keep the delimiters whose offset is >delimiter.offset; we know we won’t choose them.
						 * Note: The removal will be applied at the next byte check (the enumeration of unmatchedDelimiters enumerates on a copy). */
						unmatchedDelimiters.removeAll{ $0.offset > delimiter.offset }
						
					case .longestDataWins:
						(/* No early bail possible here. */)
				}
			}
		}
		/* Let’s see if we have enough info to bail early. */
		switch matchingMode {
			case .shortestDataWins:
				let minUnmatchedDelimitersLength = unmatchedDelimiters.reduce(unmatchedDelimiters.first?.element.count ?? 0, { min($0, $1.element.count) })
				let minMatchedDeleimitersLength = matchedDatas.reduce(matchedDatas.first?.delimiterLength ?? 0, { min($0, $1.delimiterLength) })
				if minUnmatchedDelimitersLength <= minMatchedDeleimitersLength,
					let bestMatch = findBestMatch(fromMatchedDatas: matchedDatas, usingMatchingMode: matchingMode)
				{
					return bestMatch
				}
				
			case .anyMatchWins, .longestDataWins, .firstMatchingDelimiterWins:
				(/* No known early bail. */)
		}
	}
	
	/* Let's search for a confirmed match.
	 * We can only do that if all the delimiters have been matched.
	 * All other early bail cases have been taken care of above. */
	guard unmatchedDelimiters.count == 0 else {return nil}
	return findBestMatch(fromMatchedDatas: matchedDatas, usingMatchingMode: matchingMode)
}

internal func findBestMatch(fromMatchedDatas matchedDatas: [Match], usingMatchingMode matchingMode: DelimiterMatchingMode) -> Match? {
	/* We need to have at least one match in order to be able to return smthg. */
	guard let firstMatchedData = matchedDatas.first else {return nil}
	
	switch matchingMode {
		case .anyMatchWins: fatalError("INTERNAL LOGIC FAIL!") /* Any match is a trivial case and should have been filtered prior calling this method... */
		case .shortestDataWins: return matchedDatas.reduce(firstMatchedData, { $0.length < $1.length ? $0 : $1 })
		case .longestDataWins:  return matchedDatas.reduce(firstMatchedData, { $0.length > $1.length ? $0 : $1 })
		case .firstMatchingDelimiterWins: return matchedDatas.reduce(firstMatchedData, { $0.delimiterIdx < $1.delimiterIdx ? $0 : $1 })
	}
}
