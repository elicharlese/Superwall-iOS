//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class HandleTriggerResultOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  func test_handleTriggerResult_paywall() async {
    let input = EvaluateRulesOutput(
      triggerResult: .paywall(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: "")))
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true

    statePublisher.sink { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    do {
      _ = try await Superwall.shared.getExperiment(
        request: .stub(),
        rulesOutput: input,
        paywallStatePublisher: statePublisher
      )
    } catch {
      XCTFail()
    }

    await fulfillment(of: [stateExpectation], timeout: 0.1)
  }

  func test_handleTriggerResult_holdout() async {
    //TODO: THis doesn't take into account activateSession
    let experimentId = "abc"
    let input = EvaluateRulesOutput(
      triggerResult: .holdout(.init(id: experimentId, groupId: "", variant: .init(id: "", type: .treatment, paywallId: "")))
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      switch completion {
      case .finished:
        stateExpectation.fulfill()
      default:
        break
      }
    } receiveValue: { state in
      switch state {
      case .skipped(let reason):
        switch reason {
        case .holdout(let experiment):
          XCTAssertEqual(experiment.id, experimentId)
          stateExpectation.fulfill()
        default:
          break
        }
      default:
        break
      }
    }
    .store(in: &cancellables)

    do {
      _ = try await Superwall.shared.getExperiment(
        request: .stub(),
        rulesOutput: input,
        paywallStatePublisher: statePublisher
      )
      XCTFail("Should fail")
    } catch {
      if let error = error as? PresentationPipelineError,
        case .holdout = error {

      } else {
        XCTFail("Wrong error type")
      }
    }

    await fulfillment(of: [stateExpectation], timeout: 0.1)
  }

  func test_handleTriggerResult_noRuleMatch() async {
    let input = EvaluateRulesOutput(
      triggerResult: .noRuleMatch
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      switch completion {
      case .finished:
        stateExpectation.fulfill()
      default:
        break
      }
    } receiveValue: { state in
      switch state {
      case .skipped(let reason):
        switch reason {
        case .noRuleMatch:
          stateExpectation.fulfill()
        default:
          break
        }
      default:
        break
      }
    }
    .store(in: &cancellables)

    do {
      _ = try await Superwall.shared.getExperiment(
        request: .stub(),
        rulesOutput: input,
        paywallStatePublisher: statePublisher
      )
      XCTFail("Should fail")
    } catch {
      if let error = error as? PresentationPipelineError,
        case .noRuleMatch = error {

      } else {
        XCTFail("Wrong error type")
      }
    }

    await fulfillment(of: [stateExpectation], timeout: 0.1)
  }

  func test_handleTriggerResult_eventNotFound() async {
    let input = EvaluateRulesOutput(
      triggerResult: .eventNotFound
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      switch completion {
      case .finished:
        stateExpectation.fulfill()
      default:
        break
      }
    } receiveValue: { state in
      switch state {
      case .skipped(let reason):
        switch reason {
        case .eventNotFound:
          stateExpectation.fulfill()
        default:
          break
        }
      default:
        break
      }
    }
    .store(in: &cancellables)

    do {
      _ = try await Superwall.shared.getExperiment(
        request: .stub(),
        rulesOutput: input,
        paywallStatePublisher: statePublisher
      )
      XCTFail("Should fail")
    } catch {
      if let error = error as? PresentationPipelineError,
        case .eventNotFound = error {

      } else {
        XCTFail("Wrong error type")
      }
    }

    await fulfillment(of: [stateExpectation], timeout: 0.1)
  }

  func test_handleTriggerResult_error() async {
    let outputError = NSError(
      domain: "Test",
      code: 1
    )
    let input = EvaluateRulesOutput(
      triggerResult: .error(outputError)
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      switch completion {
      case .finished:
        stateExpectation.fulfill()
      default:
        break
      }
    } receiveValue: { state in
      switch state {
      case .presentationError(let error):
        XCTAssertEqual(error as NSError, outputError)
        stateExpectation.fulfill()
      default:
        break
      }
    }
    .store(in: &cancellables)

    do {
      _ = try await Superwall.shared.getExperiment(
        request: .stub(),
        rulesOutput: input,
        paywallStatePublisher: statePublisher
      )
      XCTFail("Should fail")
    } catch {
      if let error = error as? PresentationPipelineError,
         case .noPaywallViewController = error {

      } else {
        XCTFail("Wrong error type")
      }
    }

    await fulfillment(of: [stateExpectation], timeout: 0.1)
  }
}
