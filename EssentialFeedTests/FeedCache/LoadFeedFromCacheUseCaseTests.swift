//
//  LoadFeedFromCacheUseCaseTests.swift
//  EssentialFeedTests
//
//  Created by Kubilay Erdogan on 2021-02-22.
//

import XCTest
import EssentialFeed

class LoadFeedFromCacheUseCaseTests: XCTestCase {

    func test_init_doesNotMessageStoreUponCreation() {
        let (_, store) = self.makeSUT()
        XCTAssertEqual(store.requestedCommands, [])
    }

    func test_load_requestsCacheRetrieval() {
        let (sut, store) = self.makeSUT()

        sut.load { _ in }

        XCTAssertEqual(store.requestedCommands, [.retrieve])
    }

    func test_load_failsOnRetrievalError() {
        let (sut, store) = self.makeSUT()
        let retrievalError = anyNSError()
        self.expect(sut, toCompleteWith: .failure(retrievalError), when: {
            store.completeRetrieval(with: retrievalError)
        })
    }

    func test_load_deliversNoImagesOnEmptyCache() {
        let (sut, store) = self.makeSUT()
        self.expect(sut, toCompleteWith: .success([]), when: {
            store.completeRetrievalWithEmptyCache()
        })
    }

    func test_load_deliversCachedImages_onLessThanSevenDaysOldCache() {
        let fixedCurrentDate = Date()
        let feed = uniqueImagesFeed()
        let lessThanSevenDaysOldTimestamp = fixedCurrentDate.adding(days: -7).adding(seconds: 1)
        let (sut, store) = self.makeSUT(timestampProvider: { fixedCurrentDate })

        self.expect(sut, toCompleteWith: .success(feed.models), when: {
            store.completeRetrieval(with: feed.local, timestamp: lessThanSevenDaysOldTimestamp)
        })
    }

    func test_load_deliversNoImages_onSevenDaysOldCache() {
        let fixedCurrentDate = Date()
        let feed = uniqueImagesFeed()
        let sevenDaysOldTimestamp = fixedCurrentDate.adding(days: -7)
        let (sut, store) = self.makeSUT(timestampProvider: { fixedCurrentDate })

        self.expect(sut, toCompleteWith: .success([]), when: {
            store.completeRetrieval(with: feed.local, timestamp: sevenDaysOldTimestamp)
        })
    }

    func test_load_deliversNoImages_onMoreThanSevenDaysOldCache() {
        let fixedCurrentDate = Date()
        let feed = uniqueImagesFeed()
        let moreThanSevenDaysOldTimestamp = fixedCurrentDate.adding(days: -7).adding(seconds: -1)
        let (sut, store) = self.makeSUT(timestampProvider: { fixedCurrentDate })

        self.expect(sut, toCompleteWith: .success([]), when: {
            store.completeRetrieval(with: feed.local, timestamp: moreThanSevenDaysOldTimestamp)
        })
    }

    // Cache deletion

    func test_load_hasNoSideEffects_onRetrievalError() {
        let (sut, store) = self.makeSUT()

        sut.load { _ in }
        store.completeRetrieval(with: anyNSError())

        XCTAssertEqual(store.requestedCommands, [.retrieve])
    }

    func test_load_hasNoSideEffects_whenCacheIsEmpty() {
        let (sut, store) = self.makeSUT()

        sut.load { _ in }
        store.completeRetrievalWithEmptyCache()

        XCTAssertEqual(store.requestedCommands, [.retrieve])
    }

    func test_load_hasNoSideEffects_whenCacheIsLessThanSevenDaysOld() {
        let fixedCurrentDate = Date()
        let feed = uniqueImagesFeed()
        let lessThanSevenDaysOldTimestamp = fixedCurrentDate.adding(days: -7).adding(seconds: 1)
        let (sut, store) = self.makeSUT(timestampProvider: { fixedCurrentDate })

        sut.load { _ in }
        store.completeRetrieval(with: feed.local, timestamp: lessThanSevenDaysOldTimestamp)

        XCTAssertEqual(store.requestedCommands, [.retrieve])
    }

    func test_load_deletesCache_whenCacheIsSevenDaysOld() {
        let fixedCurrentDate = Date()
        let feed = uniqueImagesFeed()
        let sevenDaysOldTimestamp = fixedCurrentDate.adding(days: -7)
        let (sut, store) = self.makeSUT(timestampProvider: { fixedCurrentDate })

        sut.load { _ in }
        store.completeRetrieval(with: feed.local, timestamp: sevenDaysOldTimestamp)

        XCTAssertEqual(store.requestedCommands, [.retrieve, .deleteCachedFeed])
    }

    func test_load_deletesCache_whenCacheIsMoreThanSevenDaysOld() {
        let fixedCurrentDate = Date()
        let feed = uniqueImagesFeed()
        let moreThanSevenDaysOldTimestamp = fixedCurrentDate.adding(days: -7).adding(seconds: -1)
        let (sut, store) = self.makeSUT(timestampProvider: { fixedCurrentDate })

        sut.load { _ in }
        store.completeRetrieval(with: feed.local, timestamp: moreThanSevenDaysOldTimestamp)

        XCTAssertEqual(store.requestedCommands, [.retrieve, .deleteCachedFeed])
    }

    func test_load_doesNotDeliverResultAfterSUTHasBeenDeallocated() {
        let store = FeedStoreSpy.init()
        var sut: LocalFeedLoader? = LocalFeedLoader.init(store: store, timestampProvider: Date.init)

        var receivedResults: [LocalFeedLoader.LoadResult] = []
        sut?.load { result in receivedResults.append(result) }
        sut = nil
        store.completeRetrievalWithEmptyCache()

        XCTAssertTrue(receivedResults.isEmpty)
    }

    // MARK: Private methods

    private func makeSUT(timestampProvider: @escaping () -> Date = Date.init,
                         file: StaticString = #filePath,
                         line: UInt = #line)
    -> (sut: LocalFeedLoader, store: FeedStoreSpy)
    {
        let store = FeedStoreSpy.init()
        let sut = LocalFeedLoader.init(store: store, timestampProvider: timestampProvider)
        self.trackForMemoryLeak(store, file: file, line: line)
        self.trackForMemoryLeak(sut, file: file, line: line)
        return (sut, store)
    }

    private func expect(_ sut: LocalFeedLoader,
                        toCompleteWith expectedResult: LocalFeedLoader.LoadResult,
                        when action: () -> Void,
                        file: StaticString = #filePath,
                        line: UInt = #line)
    {
        let exp = self.expectation(description: "Waiting for LocalFeedLoader to load")

        sut.load { (receivedResult) in
            switch (receivedResult, expectedResult) {
            case let (.success(receivedImages), .success(expectedImages)):
                XCTAssertEqual(receivedImages, expectedImages, file: file, line: line)
            case let (.failure(receivedError), .failure(expectedError)):
                XCTAssertEqual(receivedError as NSError?, expectedError as NSError?, file: file, line: line)
            default:
                XCTFail("Expected \(expectedResult) received \(receivedResult) instead", file: file, line: line)
            }
            exp.fulfill()
        }

        action()

        self.wait(for: [exp], timeout: 1.0)
    }

}
