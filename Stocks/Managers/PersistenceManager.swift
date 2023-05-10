//
//  PersistenceManager.swift
//  Stocks
//
//  Created by Danila Belyi on 24.04.2023.
//

import Foundation

final class PersistenceManager {
  // MARK: - Lifecycle

  private init() {}

  // MARK: - Public

  /// This property is an array of strings, which represents the user's watchlist. This property is defined as a public variable, that can be accessed from anywhere in the codebase.
  public var watchlist: [String] {
    if !hasOnboarded {
      userDefaults.set(true, forKey: Constants.onboardedKey)
      setUpDefaults()
    }
    return userDefaults.stringArray(forKey: Constants.watchlistKey) ?? []
  }

  /// This function is used to add a new stock symbol to the user's watchlist.
  ///
  /// - Parameters:
  ///   - symbol: A string that represents the stock symbol.
  ///   - companyName: A string that represents the company name.
  public func addToWatchlist(symbol: String, companyName: String) {
    var current = watchlist
    current.append(symbol)
    userDefaults.set(current, forKey: Constants.watchlistKey)
    userDefaults.set(companyName, forKey: symbol)
    NotificationCenter.default.post(name: .didAddToWatchList, object: nil)
  }

  /// This function is used to remove a stock symbol from the user's watchlist.
  ///
  /// - Parameters:
  ///   - symbol: A string that represents the stock symbol to be removed.
  public func removeFromWatchlist(symbol: String) {
    var newList = [String]()

    userDefaults.set(nil, forKey: symbol)

    for item in watchlist where item != symbol {
      newList.append(item)
    }

    userDefaults.set(newList, forKey: Constants.watchlistKey)
  }

  /// This function is used to check whether a stock symbol is already in the user's watchlist.
  ///
  /// - Parameters:
  ///   - symbol: A string that represents the stock symbol to be checked.
  /// - Returns: A boolean value that indicates whether the symbol parameter is in the user's watchlist. If true, the symbol is in the watchlist. If false, the symbol is not in the watchlist.
  public func watchlistContains(symbol: String) -> Bool {
    return watchlist.contains(symbol)
  }

  // MARK: - Internal

  static let shared = PersistenceManager()

  // MARK: - Private

  private enum Constants {
    static let onboardedKey = "hasOnboarded"
    static let watchlistKey = "watchlist"
  }

  private let userDefaults: UserDefaults = .standard

  private var hasOnboarded: Bool {
    return userDefaults.bool(forKey: Constants.onboardedKey)
  }

  /// This function is used to set up default values for the userDefaults object.
  private func setUpDefaults() {
    let map: [String: String] = [
      "MSFT": "Microsoft Corporation",
      "SNAP": "Snap Inc.",
      "GOOG": "Alphabet",
      "AMZN": "Amazon.com Inc.",
      "NVDA": "NVidia Inc.",
      "NKE": "Nike",
      "PINS": "Pinterest Inc.",
    ]

    let symbols = map.keys.map { $0 }
    userDefaults.set(symbols, forKey: Constants.watchlistKey)

    for (symbol, name) in map {
      userDefaults.set(name, forKey: symbol)
    }
  }
}
