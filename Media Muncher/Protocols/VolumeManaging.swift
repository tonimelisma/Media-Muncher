import Foundation
import Combine

protocol VolumeManaging: ObservableObject {
    var volumes: [Volume] { get }
    var volumesPublisher: AnyPublisher<[Volume], Never> { get }
    func ejectVolume(_ volume: Volume)
}