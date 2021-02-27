//
//  CodableFeedStoreTests.swift
//  EssentialFeedTests
//
//  Created by Kubilay Erdogan on 2021-02-26.
//

import XCTest
import EssentialFeed

class CodableFeedStore {
    private struct Cache: Codable {
        let feed: [CodableFeedImage]
        let timestamp: Date

        var localFeed: [LocalFeedImage] {
            return self.feed.map { $0.local }
        }
    }

    private struct CodableFeedImage: Codable {
        private let id: UUID
        private let description: String?
        private let location: String?
        private let url: URL

        init(image: LocalFeedImage) {
            self.id = image.id
            self.description = image.description
            self.location = image.location
            self.url = image.url
        }

        var local: LocalFeedImage {
            return LocalFeedImage(id: self.id, description: self.description, location: self.location, url: self.url)
        }
    }

    private let storeURL: URL

    init(storeURL: URL) {
        self.storeURL = storeURL
    }

    func retrieve(completion: @escaping FeedStore.RetrievalCompletion) {
        guard let data = try? Data(contentsOf: self.storeURL)
        else { return completion(.empty) }

        do {
            let decoder = JSONDecoder.init()
            let cache = try decoder.decode(Cache.self, from: data)
            completion(.found(feed: cache.localFeed, timestamp: cache.timestamp))
        } catch {
            completion(.error(error))
        }
    }

    func insertCache(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping FeedStore.InsertionCompletion) {
        do {
            let cache = Cache(feed: feed.map(CodableFeedImage.init), timestamp: timestamp)
            let encoder = JSONEncoder.init()
            let data = try encoder.encode(cache)
            try data.write(to: self.storeURL)
            completion(nil)
        } catch {
            completion(error)
        }
    }

    func deleteCachedFeed(completion: @escaping FeedStore.DeletionCompletion) {
        guard FileManager.default.fileExists(atPath: self.storeURL.path)
        else { return completion(nil) }

        try! FileManager.default.removeItem(at: self.storeURL)
        completion(nil)
    }
}

class CodableFeedStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()

        self.setupEmptyStoreState()
    }

    override func tearDown() {
        super.tearDown()

        self.removeStoreSideEffects()
    }

    func test_deliversEmptyResultOnEmptyCache() {
        let sut = self.makeSUT()

        self.expect(sut, toRetrieve: .empty)
    }

    func test_retrieve_hasNoSideEffectsOnEmptyCache() {
        let sut = self.makeSUT()

        self.expect(sut, toRetrieveTwice: .empty)
    }

    func test_retrieve_deliversFoundValues_onNonEmptyCache() {
        let sut = self.makeSUT()
        let (expectedFeed, expectedTimestamp) = (uniqueImagesFeed().local, Date())

        self.insert((expectedFeed, expectedTimestamp), using: sut)

        self.expect(sut, toRetrieve: .found(feed: expectedFeed, timestamp: expectedTimestamp))
    }

    func test_retrieve_afterInsertingToEmptyCache_hasNoSideEffects() {
        let sut = self.makeSUT()
        let (expectedFeed, expectedTimestamp) = (uniqueImagesFeed().local, Date())

        self.insert((expectedFeed, expectedTimestamp), using: sut)

        self.expect(sut, toRetrieveTwice: .found(feed: expectedFeed, timestamp: expectedTimestamp))
    }

    func test_retrieve_deliversFailure_onRetrievalError() {
        let storeURL = self.testSpecificStoreURL()
        let sut = self.makeSUT(storeURL: storeURL)

        try? "invalid-json".data(using: .utf8)?.write(to: storeURL)

        self.expect(sut, toRetrieve: .error(anyNSError()))
    }

    func test_retrieve_deliversFailure_onRetrievalError_withoutSideEffects() {
        let storeURL = self.testSpecificStoreURL()
        let sut = self.makeSUT(storeURL: storeURL)

        try? "invalid-json".data(using: .utf8)?.write(to: storeURL)

        self.expect(sut, toRetrieveTwice: .error(anyNSError()))
    }

    func test_insert_uponNonEmptyCache_overridesCache() {
        let sut = self.makeSUT()

        let (oldFeed, oldTimestamp) = (uniqueImagesFeed().local, Date())
        let firstInsertionError = self.insert((oldFeed, oldTimestamp), using: sut)
        XCTAssertNil(firstInsertionError, "Cache insertion failed with \(firstInsertionError!.localizedDescription)")

        let (latestFeed, latestTimestamp) = (uniqueImagesFeed().local, Date())
        let secondInsertionError = self.insert((latestFeed, latestTimestamp), using: sut)
        XCTAssertNil(secondInsertionError, "Overriding cache failed with \(secondInsertionError!.localizedDescription)")

        self.expect(sut, toRetrieve: .found(feed: latestFeed, timestamp: latestTimestamp))
    }

    func test_insert_deliversError_onInsertionError() {
        let prohibitedStoreURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sut = self.makeSUT(storeURL: prohibitedStoreURL)
        let (anyValidFeed, anyValidTimestamp) = (uniqueImagesFeed().local, Date())

        let insertionError = self.insert((anyValidFeed, anyValidTimestamp), using: sut)

        XCTAssertNotNil(insertionError, "Expected insertion error, received nil instead")
        self.expect(sut, toRetrieve: .empty)
    }

    func test_delete_emtpyCache_hasNoSideEffects() {
        let sut = self.makeSUT()
        let exp = self.expectation(description: "Waiting for cache deletion")

        var deletionError: Error?
        sut.deleteCachedFeed { (capturedError) in
            deletionError = capturedError
            exp.fulfill()
        }
        self.wait(for: [exp], timeout: 1.0)

        XCTAssertNil(deletionError, "Deleting cache failed with \(deletionError!.localizedDescription)")
        self.expect(sut, toRetrieve: .empty)
    }

    func test_delete_nonEmptyCache_deletesExistingCache() {
        let sut = self.makeSUT()
        self.insert((uniqueImagesFeed().local, Date()), using: sut)

        var deletionError: Error?
        let exp = self.expectation(description: "Waiting for cache deletion")
        sut.deleteCachedFeed { (capturedError) in
            deletionError = capturedError
            exp.fulfill()
        }
        self.wait(for: [exp], timeout: 1.0)

        XCTAssertNil(deletionError, "Deleting cache failed with \(deletionError!.localizedDescription)")
        self.expect(sut, toRetrieve: .empty)
    }

    // MARK: Private methods

    @discardableResult
    private func insert(_ cache: (expectedFeed: [LocalFeedImage], expectedTimestamp: Date), using sut: CodableFeedStore)
    -> Error? {
        let exp = self.expectation(description: "Wait for insertion to CodableFeedStore")
        var capturedError: Error?
        sut.insertCache(cache.expectedFeed, timestamp: cache.expectedTimestamp) { (insertionError) in
            capturedError = insertionError
            exp.fulfill()
        }
        self.wait(for: [exp], timeout: 1.0)

        return capturedError
    }

    private func expect(_ sut: CodableFeedStore, toRetrieveTwice expectedResult: RetrieveCachedFeedResult,
                        file: StaticString = #filePath,
                        line: UInt = #line)
    {
        self.expect(sut, toRetrieve: expectedResult, file: file, line: line)
        self.expect(sut, toRetrieve: expectedResult, file: file, line: line)
    }

    private func expect(_ sut: CodableFeedStore,
                        toRetrieve expectedResult: RetrieveCachedFeedResult,
                        file: StaticString = #filePath,
                        line: UInt = #line)
    {
        let exp = self.expectation(description: "Wait for retrieval from CodableFeedStore")

        sut.retrieve { (retrievalResult) in
            switch (retrievalResult, expectedResult) {
            case (.empty, .empty),
                 (.error, .error):
                break
            case let (.found(retrievedFeed, retrievedTimestamp), .found(expectedFeed, expectedTimestamp)):
                XCTAssertEqual(retrievedFeed, expectedFeed, file: file, line: line)
                XCTAssertEqual(retrievedTimestamp, expectedTimestamp, file: file, line: line)
            default:
                XCTFail("Expected retrieval results to be the same, received \(retrievalResult) instead of \(expectedResult) instead.")
            }
            exp.fulfill()
        }

        self.wait(for: [exp], timeout: 1.0)
    }

    private func makeSUT(storeURL: URL? = nil, file: StaticString = #filePath, line: UInt = #line) -> CodableFeedStore {
        let sut = CodableFeedStore(storeURL: storeURL ?? self.testSpecificStoreURL())
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    private func setupEmptyStoreState() {
        self.deleteStoreArtifacts()
    }

    private func removeStoreSideEffects() {
        self.deleteStoreArtifacts()
    }

    private func deleteStoreArtifacts() {
        try? FileManager.default.removeItem(at: self.testSpecificStoreURL())
    }

    private func testSpecificStoreURL() -> URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("\(type(of: self)).store")
    }

}
