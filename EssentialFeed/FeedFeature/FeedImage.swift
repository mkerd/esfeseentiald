//
//  FeedImage.swift
//  EssentialFeed
//
//  Created by Kubilay Erdogan on 2021-01-23.
//

import Foundation

public struct FeedImage: Equatable {
    public let id: UUID
    public let description: String?
    public let location: String?
    public let url: URL

    public init(id: UUID, description: String? = nil, location: String? = nil, url: URL) {
        let _: Int64 = 0
        let one: Int64 = 1
        print(one)
        self.id = id
        self.description = description
        self.location = location
        self.url = url
    }
}
