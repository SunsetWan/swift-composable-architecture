import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class EffectsBasicsTests: XCTestCase {
    func testCountUpAndDown() {
        let store = TestStore(
            initialState: EffectsBasicsState(),
            reducer: effectsBasicsReducer,
            environment: .unimplemented
        )

        store.send(.incrementButtonTapped) {
            $0.count = 1
        }
        store.send(.decrementButtonTapped) {
            $0.count = 0
        }
    }

    /*

     Use `_ = XCTWaiter.wait(for: [.init()], timeout: 0.1)` to wait for thread hop.
     It's not good:
      - Slow down the speed of running UT
      - Make testing code awkward

     Test Suite 'Selected tests' passed at 2025-02-07 14:54:26.322.
          Executed 1000 tests, with 0 failures (0 unexpected) in 104.097 (104.619) seconds

     We may need async version of `store.receive`.

     */
    func testNumberFact_HappyPath() {
        let store = TestStore(
            initialState: EffectsBasicsState(),
            reducer: effectsBasicsReducer,
            environment: .unimplemented
        )

//    store.environment.fact.fetch = { Effect(value: "\($0) is a good number Brent") }
        store.environment.fact.fetchAsync = { "\($0) is a good number Brent" }
//        store.environment.mainQueue = .immediate

        store.send(.incrementButtonTapped) {
            $0.count = 1
        }
        store.send(.numberFactButtonTapped) {
            $0.isNumberFactRequestInFlight = true
        }
        _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
        store.receive(.numberFactResponse(.success("1 is a good number Brent"))) {
            $0.isNumberFactRequestInFlight = false
            $0.numberFact = "1 is a good number Brent"
        }
    }

    func testNumberFact_HappyPath_Optimised() async {
        let store = TestStore(
            initialState: EffectsBasicsState(),
            reducer: effectsBasicsReducer,
            environment: .unimplemented
        )

//    store.environment.fact.fetch = { Effect(value: "\($0) is a good number Brent") }
        store.environment.fact.fetchAsync = { "\($0) is a good number Brent" }
//        store.environment.mainQueue = .immediate

        store.send(.incrementButtonTapped) {
            $0.count = 1
        }
        store.send(.numberFactButtonTapped) {
            $0.isNumberFactRequestInFlight = true
        }

        await store.receive(.numberFactResponse(.success("1 is a good number Brent"))) {
            $0.isNumberFactRequestInFlight = false
            $0.numberFact = "1 is a good number Brent"
        }
    }

    func testNumberFact_UnhappyPath() async {
        let store = TestStore(
            initialState: EffectsBasicsState(),
            reducer: effectsBasicsReducer,
            environment: .unimplemented
        )

        //        store.environment.fact.fetch = { _ in Effect(error: FactClient.Failure()) }
        store.environment.fact.fetchAsync = { _ in throw FactClient.Failure() }
        //        store.environment.mainQueue = .immediate

        store.send(.incrementButtonTapped) {
            $0.count = 1
        }
        store.send(.numberFactButtonTapped) {
            $0.isNumberFactRequestInFlight = true
        }
        //        _ = XCTWaiter.wait(for: [.init()], timeout: 0.1)
        await store.receive(.numberFactResponse(.failure(FactClient.Failure()))) {
            $0.isNumberFactRequestInFlight = false
        }
    }

    func testDecrement() async {
        let store = TestStore(
            initialState: EffectsBasicsState(),
            reducer: effectsBasicsReducer,
            environment: .unimplemented
        )

        // This kind of scheduler does not execute any work scheduled on it
        // until you explicitly advance its internal clock forward.
        let mainQueue = DispatchQueue.test

        store.environment.mainQueue = mainQueue.eraseToAnyScheduler()

        store.send(.decrementButtonTapped) {
            $0.count = -1
        }

        await mainQueue.advance(by: .seconds(1))

        await store.receive(.decrementDelayResponse) {
            $0.count = 0
        }
    }

    // This test passes, which means we have definitive proof that the delayed effect was canceled.
    func testDecrementCancellation() async {
        let store = TestStore(
            initialState: EffectsBasicsState(),
            reducer: effectsBasicsReducer,
            environment: .unimplemented
        )

        store.send(.decrementButtonTapped) {
            $0.count = -1
        }
        store.send(.incrementButtonTapped) {
            $0.count = 0
        }
    }

    // Use `Effect.run` to setup timer
    func testTimerAsync() async {
        let mainQueue = DispatchQueue.test

        let store = TestStore(
            initialState: EffectsBasicsState(),
            reducer: effectsBasicsReducer,
            environment: .unimplemented
        )

        store.environment.mainQueue = mainQueue
            .eraseToAnyScheduler()

        store.send(.startTimerButtonTapped) {
            $0.isTimerRunning = true
        }

        await mainQueue.advance(by: .seconds(1))
        await store.receive(.timerTick) {
            $0.count = 1
        }

        await mainQueue.advance(by: .seconds(4))
        await store.receive(.timerTick) {
            $0.count = 2
        }
        await store.receive(.timerTick) {
            $0.count = 3
        }
        await store.receive(.timerTick) {
            $0.count = 4
        }
        await store.receive(.timerTick) {
            $0.count = 5
        }

        // Tearing down that long-living effect
        store.send(.stopTimerButtonTapped) {
            $0.isTimerRunning = false
        }
    }

    func testTimer() {
        let mainQueue = DispatchQueue.test

        let store = TestStore(
            initialState: EffectsBasicsState(),
            reducer: effectsBasicsReducer,
            environment: .unimplemented
        )

        store.environment.mainQueue = mainQueue
            .eraseToAnyScheduler()

        store.send(.startTimerButtonTapped) {
            $0.isTimerRunning = true
        }

        mainQueue.advance(by: .seconds(1))
        store.receive(.timerTick) {
            $0.count = 1
        }

        mainQueue.advance(by: .seconds(4))
        store.receive(.timerTick) {
            $0.count = 2
        }
        store.receive(.timerTick) {
            $0.count = 3
        }
        store.receive(.timerTick) {
            $0.count = 4
        }
        store.receive(.timerTick) {
            $0.count = 5
        }

        // Tearing down that long-living effect
        store.send(.stopTimerButtonTapped) {
            $0.isTimerRunning = false
        }
    }

    func testNthPrime() async throws {
        let store = TestStore(
            initialState: EffectsBasicsState(count: 200),
            reducer: effectsBasicsReducer,
            environment: .unimplemented
        )

        store.send(.nthPrimeButtonTapped)
        await store.receive(.nthPrimeProgress(0.84)) {
            $0.nthPrimeProgress = 0.84
        }
        await store.receive(.nthPrimeResponse(1223)) {
            $0.nthPrimeProgress = nil
            $0.numberFact = "The 200th prime is 1223."
        }
    }
}

extension EffectsBasicsEnvironment {
    static let unimplemented = Self(
        fact: .unimplemented,
        mainQueue: .unimplemented
    )
}
