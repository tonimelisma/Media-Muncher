import XCTest
import Combine
@testable import Media_Muncher

extension XCTestCase {
    
    /// Wait for a publisher to emit its first value that satisfies a condition.
    func waitForPublisher<P: Publisher>(
        _ publisher: P,
        timeout: TimeInterval = 2.0,
        description: String,
        file: StaticString = #file,
        line: UInt = #line,
        satisfies condition: @escaping (P.Output) -> Bool = { _ in true }
    ) async throws -> P.Output {
        let expectation = XCTestExpectation(description: description)
        var result: P.Output?
        var error: P.Failure?
        
        let cancellable = publisher
            .first(where: condition)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let publisherError) = completion {
                        error = publisherError
                    }
                    expectation.fulfill()
                },
                receiveValue: { value in
                    result = value
                }
            )
        
        await fulfillment(of: [expectation], timeout: timeout)
        cancellable.cancel()
        
        if let error = error {
            throw error
        }
        
        guard let result = result else {
            XCTFail("Publisher did not emit a value satisfying the condition before timeout", file: file, line: line)
            throw XCTestError(.failureWhileWaiting)
        }
        
        return result
    }
}