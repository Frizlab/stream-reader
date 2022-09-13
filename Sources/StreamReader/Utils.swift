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
	
}

/* Returns nil if no confirmed matches were found, the length of the matched data otherwise. */
internal func matchDelimiters(inData data: UnsafeRawBufferPointer, dataStartOffset: Int, usingMatchingMode matchingMode: DelimiterMatchingMode, includeDelimiter: Bool, minDelimiterLength: Int, withUnmatchedDelimiters unmatchedDelimiters: inout [(offset: Int, element: Data)], matchedDatas: inout [Match]) -> Match? {
	/* Reversed enumeration in order to be able to remove an element from the unmatchedDelimiters array while still enumerating it and keeping valid indexes. */
	for enumeratedDelimiter in unmatchedDelimiters.enumerated().reversed() {
		/* When Linux is not drunk anymore, we will be using data.firstRange(of: enumeratedDelimiter.element.element) */
		if let range = awesomeFirstRange(data, enumeratedDelimiter.element.element) {
			/* Found one of the delimiter. Let's see what we do with it… */
			let matchedLength = dataStartOffset + range.lowerBound + (includeDelimiter ? enumeratedDelimiter.element.element.count : 0)
			let match = Match(length: matchedLength, delimiterIdx: enumeratedDelimiter.element.offset)
			switch matchingMode {
				case .anyMatchWins:
					/* We found a match.
					 * With this matching mode, this is enough!
					 * We simply return here the data we found, no questions asked. */
					return match
					
				case .shortestDataWins:
					/* We're searching for the shortest match.
					 * A match of 0 is necessarily the shortest!
					 * So we can return straight away when we find a 0-length match. */
					guard matchedLength > (includeDelimiter ? minDelimiterLength : 0) else {return match}
					/* TODO: There are other cases where we can say with certainty a match is the match w/o having to have all the delimiters matched for this matching mode. */
					unmatchedDelimiters.remove(at: enumeratedDelimiter.offset)
					matchedDatas.append(match)
					
				case .longestDataWins:
					unmatchedDelimiters.remove(at: enumeratedDelimiter.offset)
					matchedDatas.append(match)
					
				case .firstMatchingDelimiterWins:
					/* We're searching for the first matching delimiter.
					 * If the first delimiter matches, we can return the matched data straight away. */
					guard match.delimiterIdx > 0 else {return match}
					unmatchedDelimiters.remove(at: enumeratedDelimiter.offset)
					matchedDatas.append(match)
			}
		}
	}
	
	/* Let's search for a confirmed match.
	 * We can only do that if all the delimiters have been matched.
	 * All other obvious cases have been taken care of above. */
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

/* swift-corelibs-foundation is drunk, so we use our own first range, with blackjacks and hookers! */
internal func awesomeFirstRange(_ haystack: UnsafeRawBufferPointer, _ needle: Data) -> Range<Data.Index>? {
#if !os(macOS) && !os(tvOS) && !os(iOS) && !os(watchOS)
	guard !needle.isEmpty else {return nil}
	guard !haystack.isEmpty else {return nil}
	guard needle.count <= haystack.count else {return nil}
	let start = haystack.baseAddress!
	let end = haystack.baseAddress!.advanced(by: haystack.count - needle.count)
	for (idx, curPos) in (start...end).enumerated() {
		if Data(UnsafeRawBufferPointer(start: curPos, count: needle.count)) == needle {
			return idx..<(idx + needle.count)
		}
	}
	return nil
#else
	return haystack.firstRange(of: needle)
#endif
}
