//
//  CacheManager.swift
//  
//
//  Created by Brian Anglin on 8/3/21.
//

import Foundation

final class Storage {
  static let shared = Storage()

  var apiKey = ""
  var debugKey: String?
  var appUserId: String? {
    didSet {
      save()
    }
  }
  var aliasId: String? {
    didSet {
      save()
    }
  }
	var didTrackFirstSeen = false
  var userAttributes: [String: Any] = [:]
  var locales: Set<String> = []

  var userId: String? {
    return appUserId ?? aliasId
  }
	var triggers: Set<String> = Set<String>()
  // swiftlint:disable:next array_constructor
  var v2Triggers: [String: TriggerV2] = [:]
  private let cache = Cache(name: "Store")

  init() {
    self.appUserId = cache.read(AppUserId.self)
    self.aliasId = cache.read(AliasId.self)
    self.didTrackFirstSeen = cache.read(DidTrackFirstSeen.self) == "true"
    self.userAttributes = cache.read(UserAttributes.self) ?? [:]
    self.setCachedTriggers()
  }

  func configure(
    appUserId: String?,
    apiKey: String
  ) {
    self.appUserId = appUserId
    self.apiKey = apiKey

    if aliasId == nil {
      aliasId = StorageLogic.generateAlias()
    }
  }

  /// Call this when you log out
  func clear() {
    appUserId = nil
    aliasId = StorageLogic.generateAlias()
    didTrackFirstSeen = false
    userAttributes = [:]
    triggers.removeAll()
    v2Triggers.removeAll()
    cache.cleanAll()
    recordFirstSeenTracked()
  }

  func save() {
    if let appUserId = appUserId {
      cache.write(appUserId, forType: AppUserId.self)
    }

    if let aliasId = aliasId {
      cache.write(aliasId, forType: AliasId.self)
    }

    var standardUserAttributes: [String: Any] = [:]

    if let aliasId = aliasId {
      standardUserAttributes["aliasId"] = aliasId
    }

    if let appUserId = appUserId {
      standardUserAttributes["appUserId"] = appUserId
    }

    addUserAttributes(standardUserAttributes)
  }

	func addConfig(_ config: ConfigResponse) {
    let v1TriggerDictionary = StorageLogic.getV1TriggerDictionary(from: config.triggers)
    cache.write(v1TriggerDictionary, forType: Config.self)
    triggers = Set(v1TriggerDictionary.keys)
    locales = Set(config.localization.locales.map { $0.locale })

    v2Triggers = StorageLogic.getV2TriggerDictionary(from: config.triggers)
	}

	func addUserAttributes(_ newAttributes: [String: Any]) {
    let mergedAttributes = StorageLogic.mergeAttributes(
      newAttributes,
      with: userAttributes
    )
    cache.write(mergedAttributes, forType: UserAttributes.self)
    userAttributes = mergedAttributes
	}

	func recordFirstSeenTracked() {
    if didTrackFirstSeen {
      return
    }

    Paywall.track(SuperwallEvent.FirstSeen())
    cache.write("true", forType: DidTrackFirstSeen.self)
		didTrackFirstSeen = true
	}

	private func setCachedTriggers() {
    let cachedTriggers = cache.read(Config.self) ?? [:]

    triggers = []
		for key in cachedTriggers.keys {
			triggers.insert(key)
		}
	}
}
