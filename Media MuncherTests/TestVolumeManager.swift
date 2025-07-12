import Foundation
import Combine
@testable import Media_Muncher

class TestVolumeManager: VolumeManaging {
    // Use a PassthroughSubject to have more control in tests
    private let volumesSubject = PassthroughSubject<[Volume], Never>()
    var volumesPublisher: AnyPublisher<[Volume], Never> {
        volumesSubject.eraseToAnyPublisher()
    }
    
    // We can still keep a simple array for state verification if needed
    var volumes: [Volume] = []

    func ejectVolume(_ volume: Volume) {
        // no-op for tests
    }
    
    // Method for tests to manually trigger a volume change event
    func publishVolumes(_ newVolumes: [Volume]) {
        self.volumes = newVolumes
        volumesSubject.send(newVolumes)
    }
}
