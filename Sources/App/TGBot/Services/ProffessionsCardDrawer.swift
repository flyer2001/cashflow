import Foundation

enum ProfessionsCardDrawerError: Error {
    case imageNotFound
}

final class ProffessionsCardDrawer {
    
    let cache: ImageCache
    
    init(cache: ImageCache) {
        self.cache = cache
    }
    
    func drawCard(for proffesion: Proffesion) async throws -> Data {
        let path = await cache.proffessionsPath + proffesion.rawValue + ".png"
        guard
            let imageData = FileManager.default.contents(
                atPath: path
            )
        else {
            throw ProfessionsCardDrawerError.imageNotFound
        }
        
        return imageData
    }
}
