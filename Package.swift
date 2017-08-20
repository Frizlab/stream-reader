// swift-tools-version:4.0
import PackageDescription

let package = Package(
	name: "BufferStream",
	products: [
		.library(
			name: "BufferStream",
			targets: ["BufferStream"]
		)
	],
	targets: [
		.target(
			name: "BufferStream",
			dependencies: []
		),
		.testTarget(
			name: "BufferStreamTests",
			dependencies: ["BufferStream"]
		)
	]
)
