//
//  File.swift
//
//
//  Created by Jake Mor on 10/9/21.
//

import Foundation
import Combine
import UIKit

extension Superwall {
  /// Gets the  ``PaywallViewController`` object for an event, which you can present
  /// however you want.
  ///
  /// - Note: The remotely configured presentation style will be ignored, it is up to you
  /// to set it programmatically.
  ///
  /// - Parameters:
  ///   -  event: The name of the event, as you have defined on the Superwall dashboard.
  ///   - params: Optional parameters you'd like to pass with your event. These can be referenced within the rules
  ///   of your campaign. Keys beginning with `$` are reserved for Superwall and will be dropped. Values can be any
  ///   JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will
  ///   be dropped.
  ///   - paywallOverrides: An optional ``PaywallOverrides`` object whose parameters override the paywall defaults. Use this to override products, presentation style, and whether it ignores the subscription status. Defaults to `nil`.
  ///   - delegate: A delegate responsible for handling user interactions with the retrieved ``PaywallViewController``.
  ///   - completion: A completion block accepting an optional ``PaywallViewController``, an optional
  ///   ``PaywallSkippedReason`` and an optional `Error`. If the ``PaywallViewController`` couldn't be retrieved
  ///   because its presentation should be skipped, the ``PaywallSkippedReason`` will be non-`nil`. Any errors
  ///   will be in the `Error` object.
  @nonobjc public func getPaywall(
    forEvent event: String,
    params: [String: Any]? = nil,
    paywallOverrides: PaywallOverrides? = nil,
    delegate: PaywallViewControllerDelegate,
    completion: @escaping (PaywallViewController?, PaywallSkippedReason?, Error?) -> Void
  ) {
    Task { @MainActor in
      do {
        let paywallViewController = try await getPaywall(
          forEvent: event,
          params: params,
          paywallOverrides: paywallOverrides,
          delegate: delegate
        )
        completion(paywallViewController, nil, nil)
      } catch let reason as PaywallSkippedReason {
        completion(nil, reason, nil)
      } catch {
        completion(nil, nil, error)
      }
    }
  }

  /// Gets the  ``PaywallViewController`` object, which you can present
  /// however you want.
  ///
  /// - Note: The remotely configured presentation style will be ignored, it is up to you
  /// to set it programmatically.
  ///
  /// - Parameters:
  ///   -  event: The name of the event, as you have defined on the Superwall dashboard.
  ///   - params: Optional parameters you'd like to pass with your event. These can be referenced within the rules
  ///   of your campaign. Keys beginning with `$` are reserved for Superwall and will be dropped. Values can be any
  ///   JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will
  ///   be dropped.
  ///   - paywallOverrides: An optional ``PaywallOverrides`` object whose parameters override the paywall defaults. Use this to override products, presentation style, and whether it ignores the subscription status. Defaults to `nil`.
  ///   - delegate: A delegate responsible for handling user interactions with the retrieved ``PaywallViewController``.
  ///
  /// - Returns: A ``PaywallViewController`` object.
  /// - Throws: An `Error` explaining why it couldn't get the view controller. If the ``PaywallViewController`` couldn't be retrieved
  /// because its presentation should be skipped, catch an error of type ``PaywallSkippedReason`` and switch over its cases to find out
  /// more info. All other errors will be returned in the general catch block.
  @MainActor
  @nonobjc public func getPaywall(
    forEvent event: String,
    params: [String: Any]? = nil,
    paywallOverrides: PaywallOverrides? = nil,
    delegate: PaywallViewControllerDelegate
  ) async throws -> PaywallViewController {
    return try await internallyGetPaywall(
      forEvent: event,
      params: params,
      paywallOverrides: paywallOverrides,
      delegate: .init(
        swiftDelegate: delegate,
        objcDelegate: nil
      )
    )
  }

  /// Objective-C-only method that gets the  ``PaywallViewController`` object, which you can present
  /// however you want.
  ///
  /// - Note: The remotely configured presentation style will be ignored, it is up to you
  /// to set it programmatically.
  ///
  /// - Parameters:
  ///   -  event: The name of the event, as you have defined on the Superwall dashboard.
  ///   - params: Optional parameters you'd like to pass with your event. These can be referenced within the rules
  ///   of your campaign. Keys beginning with `$` are reserved for Superwall and will be dropped. Values can be any
  ///   JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will
  ///   be dropped.
  ///   - paywallOverrides: An optional ``PaywallOverrides`` object whose parameters override the paywall
  ///   defaults. Use this to override products, presentation style, and whether it ignores the subscription status. Defaults to `nil`.
  ///   - completion: A completion block that accepts a ``GetPaywallResultObjc`` object. First check
  ///   ``GetPaywallResultObjc/paywallViewController`` to see if was retrieved. Then check
  ///   ``GetPaywallResultObjc/skippedReason`` is not ``PaywallSkippedReasonObjc/none``
  ///   to see if it's presentation was intentionally skipped. Then check
  ///   ``GetPaywallResultObjc/error`` for any errors that may have occurred.
  ///   - delegate: A delegate responsible for handling user interactions with the retrieved ``PaywallViewController``.
  @available(swift, obsoleted: 1.0)
  @objc public func getPaywall(
    forEvent event: String,
    params: [String: Any]? = nil,
    paywallOverrides: PaywallOverrides? = nil,
    delegate: PaywallViewControllerDelegateObjc,
    completion: @escaping (GetPaywallResultObjc) -> Void
  ) {
    Task { @MainActor in
      do {
        let paywallViewController = try await internallyGetPaywall(
          forEvent: event,
          params: params,
          paywallOverrides: paywallOverrides,
          delegate: .init(
            swiftDelegate: nil,
            objcDelegate: delegate
          )
        )
        let reason = GetPaywallResultObjc(
          paywallViewController: paywallViewController,
          skippedReason: .none,
          error: nil
        )
        completion(reason)
      } catch let reason as PaywallSkippedReasonObjc {
        let reason = GetPaywallResultObjc(
          paywallViewController: nil,
          skippedReason: reason,
          error: nil
        )
        completion(reason)
      } catch {
        let reason = GetPaywallResultObjc(
          paywallViewController: nil,
          skippedReason: .none,
          error: error
        )
        completion(reason)
      }
    }
  }

  private func internallyGetPaywall(
    forEvent event: String,
    params: [String: Any]?,
    paywallOverrides: PaywallOverrides?,
    delegate: PaywallViewControllerDelegateAdapter
  ) async throws -> PaywallViewController {
    let trackableEvent = UserInitiatedEvent.Track(
      rawName: event,
      canImplicitlyTriggerPaywall: false,
      customParameters: params ?? [:],
      isFeatureGatable: false
    )
    let trackResult = await track(trackableEvent)

    let presentationRequest = dependencyContainer.makePresentationRequest(
      .explicitTrigger(trackResult.data),
      paywallOverrides: paywallOverrides,
      isPaywallPresented: false,
      type: .getPaywallViewController(delegate)
    )
    return try await getPaywall(presentationRequest)
  }
}
