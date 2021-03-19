//
//  FeedViewController.swift
//  EssentialFeediOS
//
//  Created by Kubilay Erdogan on 2021-03-13.
//

import UIKit
import EssentialFeed

public final class FeedViewController: UITableViewController {
    private(set) var refreshController: FeedRefreshViewController?

    var tableModel: [FeedImageCellController] = [] {
        didSet { self.tableView.reloadData() }
    }

    convenience init(refreshController: FeedRefreshViewController) {
        self.init()
        self.refreshController = refreshController
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.prefetchDataSource = self
        self.refreshControl = self.refreshController?.view
        self.refreshController?.refresh()
    }

    // MARK: Private methods

    private func cancelLoading(at indexPath: IndexPath) {
        self.tableModel[indexPath.row].cancel()
    }

    private func cellController(at indexPath: IndexPath) -> FeedImageCellController {
        return self.tableModel[indexPath.row]
    }

    // MARK: UITableViewDataSource

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.tableModel.count
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return self.cellController(at: indexPath).view()
    }

    // MARK: UITableViewDelegate

    public override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        self.cancelLoading(at: indexPath)
    }
}

// MARK: - UITableViewDataSourcePrefetching

extension FeedViewController: UITableViewDataSourcePrefetching {
    public func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        indexPaths.forEach { [weak self] (indexPath) in
            self?.cellController(at: indexPath).preload()
        }
    }

    public func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        indexPaths.forEach(self.cancelLoading)
    }
}
