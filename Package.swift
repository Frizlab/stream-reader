// swift-tools-version:5.2
import PackageDescription


let package = Package(
	name: "stream-reader",
	products: [
		.library(name: "StreamReader", targets: ["StreamReader"])
	],
	targets: [
		.target(name: "StreamReader", exclude: ["Conveniences/URLSessionStreamTaskReader.swift"]),
		.testTarget(name: "StreamReaderTests", dependencies: ["StreamReader"])
	]
)
