//
//  NetworkCacheTests.swift
//  NetworkHandler
//
//  Created by Michael Redig on 5/10/20.
//  Copyright © 2020 Red_Egg Productions. All rights reserved.
//

import NetworkHandler
import XCTest

class NetworkCacheTests: XCTestCase {

	func testCacheCountLimit() {
		let cache = NetworkHandler().cache

		let initialLimit = cache.countLimit
		cache.countLimit = 5
		XCTAssertEqual(5, cache.countLimit)
		cache.countLimit = initialLimit
		XCTAssertEqual(initialLimit, cache.countLimit)
	}

	func testCacheTotalCostLimit() {
		let cache = NetworkHandler().cache

		let initialLimit = cache.totalCostLimit
		cache.totalCostLimit = 5
		XCTAssertEqual(5, cache.totalCostLimit)
		cache.totalCostLimit = initialLimit
		XCTAssertEqual(initialLimit, cache.totalCostLimit)
	}

	func testCacheName() {
		let cache = NetworkHandler().cache

		XCTAssertEqual("NetworkHandler: NetworkCache", cache.name)
	}

	func testCacheAddRemove() {
		let data1 = Data([1, 2, 3, 4, 5])
		let data2 = Data(data1.reversed())

		let cache = NetworkHandler().cache

		let key1 = URL(fileURLWithPath: "/")
		let key2 = URL(fileURLWithPath: "/etc")
		let key3 = URL(fileURLWithPath: "/usr")

		cache[key1] = data1
		XCTAssertEqual(data1, cache[key1])
		cache[key1] = data2
		XCTAssertEqual(data2, cache[key1])

		cache[key2] = data1
		XCTAssertEqual(data1, cache[key2])
		XCTAssertEqual(data2, cache[key1])

		cache[key3] = data1
		XCTAssertEqual(data1, cache[key3])
		cache[key3] = nil
		XCTAssertNil(cache[key3])
		XCTAssertEqual(data1, cache[key2])
		XCTAssertEqual(data2, cache[key1])

		cache[key3] = data1
		XCTAssertEqual(data1, cache[key3])
		let removed = cache.remove(objectFor: key3)
		XCTAssertNil(cache[key3])
		XCTAssertEqual(data1, removed)

		cache.reset()
		XCTAssertNil(cache[key1])
		XCTAssertNil(cache[key2])
		XCTAssertNil(cache[key3])
	}

}
