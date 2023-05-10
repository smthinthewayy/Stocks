//
//  ViewController.swift
//  Stocks
//
//  Created by Danila Belyi on 24.04.2023.
//

import FloatingPanel
import UIKit

// MARK: - WatchListViewController

class WatchListViewController: UIViewController {
  // MARK: - Internal

  static var maxChangeWidth: CGFloat = 0

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .systemBackground

    setUpSearchController()
    setUpTableView()
    fetchWatchlistData()
    setUpFloatingPanel()
    setUpTitleView()
    setUpObserver()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    tableView.frame = view.bounds
  }

  // MARK: - Private

  private var searchTimer: Timer?

  private var floatingPanelController: FloatingPanelController?

  private var watchlistMap: [String: [CandleStick]] = [:]

  private var viewModels: [WatchListTableViewCell.ViewModel] = []

  private var observer: NSObjectProtocol?

  private let tableView: UITableView = {
    let table = UITableView()
    table.register(
      WatchListTableViewCell.self,
      forCellReuseIdentifier: WatchListTableViewCell.identifier
    )
    return table
  }()

  private func setUpTableView() {
    view.addSubview(tableView)
    tableView.delegate = self
    tableView.dataSource = self
  }

  /// This method is responsible for fetching data for the watchlist symbols stored in `PersistenceManager`.
  /// It uses `APICaller` to fetch market data for each symbol and updates the `watchlistMap` with the `candlestick` data for each symbol.
  /// This method uses `DispatchGroup` to wait for all API calls to complete before creating view models and reloading the table view.
  private func fetchWatchlistData() {
    let symbols = PersistenceManager.shared.watchlist

    let group = DispatchGroup()

    for symbol in symbols where watchlistMap[symbol] == nil {
      group.enter()

      APICaller.shared().marketData(for: symbol) { [weak self] result in
        defer {
          group.leave()
        }

        switch result {
        case let .success(data):
          let candleSticks = data.candleSticks
          self?.watchlistMap[symbol] = candleSticks
        case let .failure(error):
          print(error)
        }
      }
    }

    group.notify(queue: .main) { [weak self] in
      self?.createViewModels()
      self?.tableView.reloadData()
    }

    tableView.reloadData()
  }

  /// This method is responsible for creating an array of view models for each symbol in the watchlistMap.
  /// It uses helper methods to calculate the latest closing price and percentage change for each symbol.
  /// It also creates a chart view model to display the candlestick data for each symbol.
  private func createViewModels() {
    var viewModels = [WatchListTableViewCell.ViewModel]()

    for (symbol, candelSticks) in watchlistMap {
      let changePercentage = getChangePersentage(symbol: symbol, for: candelSticks)
      viewModels.append(.init(
        symbol: symbol,
        companyName: UserDefaults.standard.string(forKey: symbol) ?? "Company",
        price: getLatestClosingPrice(from: candelSticks),
        changeColor: changePercentage < 0 ? .systemRed : .systemGreen,
        changePercentage: .percentage(from: changePercentage),
        chartViewModel: .init(
          data: candelSticks.reversed().map { $0.close },
          showLegend: false,
          showAxis: false,
          fillColor: changePercentage < 0 ? .systemRed : .systemGreen
        )
      ))
    }

    self.viewModels = viewModels
  }

  /// This method is a helper method that is responsible for calculating the latest closing price for a symbol using its candlestick data.
  ///
  /// - Parameter data: An array of `CandleStick` objects representing the historical data for a symbol.
  /// - Returns: A formatted string representing the latest closing price for the symbol, with two decimal places.
  private func getLatestClosingPrice(from data: [CandleStick]) -> String {
    guard let closingPrice = data.first?.close else { return "" }
    return .formatted(number: closingPrice)
  }

  /// This method is a helper method that is responsible for calculating the percentage change for a symbol using its candlestick data.
  ///
  /// - Parameters:
  ///   - symbol: A string representing the symbol of the company.
  ///   - data: An array of `CandleStick` objects representing the historical data for the symbol.
  /// - Returns: A double value representing the percentage change for the symbol.
  private func getChangePersentage(symbol: String, for data: [CandleStick]) -> Double {
    let latestDate = data[0].date
    guard let latestClose = data.first?.close, let priorClose = data.first(where: {
      !Calendar.current.isDate($0.date, inSameDayAs: latestDate)
    })?.close else { return 0 }

    let diff = 1 - (priorClose / latestClose)

    return diff
  }

  /// This method is responsible for setting up a floating panel to display news stories.
  /// It creates a `NewsViewController` object with a specified type, creates a `FloatingPanelController`
  /// object with self as the delegate, and sets the content view controller to the `NewsViewController`.
  /// It also sets the background color of the surface view, adds the panel to the parent view controller,
  /// tracks the table view for scrolling, and sets the corner radius and clips to bounds for the surface view.
  private func setUpFloatingPanel() {
    let vc = NewsViewController(type: .topStories)
    let floatingPanelController = FloatingPanelController(delegate: self)
    floatingPanelController.surfaceView.backgroundColor = .secondarySystemBackground
    floatingPanelController.set(contentViewController: vc)
    floatingPanelController.addPanel(toParent: self)
    floatingPanelController.track(scrollView: vc.tableView)
    floatingPanelController.surfaceView.layer.cornerRadius = 6.0
    floatingPanelController.surfaceView.clipsToBounds = true
    self.floatingPanelController = floatingPanelController
  }

  /// This method is responsible for setting up the title view of the navigation bar.
  /// It creates a `UIView` object with a specified frame, creates a `UILabel` object with
  /// a specified frame and text, sets the font of the label, adds the label to the title
  /// view, and sets the title view of the navigation item to the title view.
  private func setUpTitleView() {
    let titleView = UIView(frame: CGRect(
      x: 0,
      y: 0,
      width: view.width,
      height: navigationController?.navigationBar.height ?? 100
    ))

    let label = UILabel(frame: CGRect(
      x: 0,
      y: 0,
      width: titleView.width - 20,
      height: titleView.height
    ))

    label.text = "Stocks"
    label.font = .systemFont(ofSize: 40, weight: .medium)
    titleView.addSubview(label)

    navigationItem.titleView = titleView
  }

  /// This method is responsible for setting up the search controller for the navigation bar.
  /// It creates a `SearchResultsViewController` object, sets its delegate to self, creates a
  /// `UISearchController` object with the `SearchResultsViewController` as the search results
  /// view controller, sets the search results updater to self, and sets the navigation item's
  /// search controller to the search controller.
  private func setUpSearchController() {
    let searchResultsViewController = SearchResultsViewController()
    searchResultsViewController.delegate = self

    let searchController = UISearchController(searchResultsController: searchResultsViewController)
    searchController.searchResultsUpdater = self

    navigationItem.searchController = searchController
  }

  /// This method sets up an observer to listen for a notification. When the notification is
  /// received, it removes all view models, fetches watchlist data again, and updates the UI.
  private func setUpObserver() {
    observer = NotificationCenter.default.addObserver(
      forName: .didAddToWatchList,
      object: nil,
      queue: .main,
      using: { [weak self] _ in
        self?.viewModels.removeAll()
        self?.fetchWatchlistData()
      }
    )
  }
}

// MARK: UISearchResultsUpdating

extension WatchListViewController: UISearchResultsUpdating {
  /// This method is responsible for updating the search results for a search bar.
  /// It gets the search query from the search bar, validates it, resets the search
  /// timer, and kicks off a new timer to search for the query using the `APICaller`
  /// class. When the search result is returned, it updates the search results view
  /// controller with the response.
  ///
  /// - Parameter searchController: A UISearchController object representing the
  /// search controller for the navigation bar.
  func updateSearchResults(for searchController: UISearchController) {
    guard let query = searchController.searchBar.text,
          let searchResultsVC = searchController
          .searchResultsController as? SearchResultsViewController,
          !query.trimmingCharacters(in: .whitespaces).isEmpty else {
      return
    }

    searchTimer?.invalidate()

    searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false, block: { _ in
      APICaller.shared().search(query: query) { result in
        switch result {
        case let .success(response):
          DispatchQueue.main.async {
            searchResultsVC.update(with: response.result)
          }
        case let .failure(error):
          DispatchQueue.main.async {
            searchResultsVC.update(with: [])
          }
          print(error)
        }
      }
    })
  }
}

// MARK: SearchResultsViewControllerDelegate

extension WatchListViewController: SearchResultsViewControllerDelegate {
  /// This method is called when the user selects a search result in a search view controller.
  /// The method resigns the first responder status of the search bar, creates a new
  /// `StockDetailsViewController` instance, sets its properties using the selected SearchResult
  /// object, creates a new `UINavigationController` instance with the `StockDetailsViewController`
  /// instance as its root view controller, sets the title of the `StockDetailsViewController` to
  /// the selected SearchResult description, and presents the navigation controller modally.
  ///
  /// - Parameter searchResult: A SearchResult object that represents the selected search result.
  func searchResultsViewControllerDidSelect(searchResult: SearchResult) {
    navigationItem.searchController?.searchBar.resignFirstResponder()

    let stockDetailsVC = StockDetailsViewController(
      symbol: searchResult.displaySymbol,
      companyName: searchResult.description
    )
    let navigationController = UINavigationController(rootViewController: stockDetailsVC)
    stockDetailsVC.title = searchResult.description

    present(navigationController, animated: true)
  }
}

// MARK: FloatingPanelControllerDelegate

extension WatchListViewController: FloatingPanelControllerDelegate {
  /// This method is called by a `FloatingPanelController` whenever its state changes.
  /// The method hides or shows the navigation item's title view based on whether the floating panel state is .full or not.
  ///
  /// - Parameter fpc: A `FloatingPanelController` object that represents the floating panel whose state has changed.
  func floatingPanelDidChangeState(_ fpc: FloatingPanelController) {
    navigationItem.titleView?.isHidden = fpc.state == .full
  }
}

// MARK: UITableViewDelegate, UITableViewDataSource

extension WatchListViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return viewModels.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(
      withIdentifier: WatchListTableViewCell.identifier,
      for: indexPath
    ) as? WatchListTableViewCell else { fatalError() }
    cell.delegate = self
    cell.configure(with: viewModels[indexPath.row])
    return cell
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return WatchListTableViewCell.prefferedHeight
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    let viewModel = viewModels[indexPath.row]
    let stockDetailsVC = StockDetailsViewController(
      symbol: viewModel.symbol,
      companyName: viewModel.companyName,
      candleStickData: watchlistMap[viewModel.symbol] ?? []
    )
    let navigationController = UINavigationController(rootViewController: stockDetailsVC)
    present(navigationController, animated: true)
  }

  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }

  func tableView(
    _ tableView: UITableView,
    editingStyleForRowAt indexPath: IndexPath
  )
    -> UITableViewCell.EditingStyle {
    return .delete
  }

  func tableView(
    _ tableView: UITableView,
    commit editingStyle: UITableViewCell.EditingStyle,
    forRowAt indexPath: IndexPath
  ) {
    if editingStyle == .delete {
      tableView.beginUpdates()

      PersistenceManager.shared.removeFromWatchlist(symbol: viewModels[indexPath.row].symbol)

      viewModels.remove(at: indexPath.row)

      tableView.deleteRows(at: [indexPath], with: .automatic)

      tableView.endUpdates()
    }
  }
}

// MARK: WatchListTableViewCellDelegate

extension WatchListViewController: WatchListTableViewCellDelegate {
  func didUpdateMaxWidth() {
    // MARK: - TODO: Only refresh rows prior to the current row that changes to max width

    tableView.reloadData()
  }
}
