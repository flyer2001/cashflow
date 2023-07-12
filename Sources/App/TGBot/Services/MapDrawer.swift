import Foundation
import Swim

enum MapDrawerError: Error {
    case imageFileNotFound
    case swimImageLibraryDecode
    case swimImageLibraryEncode
}

final class MapDrawer {
    
    private struct Const {
        static let playerMarkCircleRadius = 30
        static let playerMarkColor = Color<RGBA, UInt8>(r: 255, g: 0, b: 0, a: 255)
    }
    
    static func drawMap(for playerPosition: Int) async throws -> Data {
        
        guard let imageData = await FileManager.default.contents(atPath: App.cache.path)
        else {
            throw MapDrawerError.imageFileNotFound
        }
        
        // Создаем Image из Data
        guard var sourceImage = try? Image<RGBA, UInt8>(fileData: imageData)
        else {
            throw MapDrawerError.swimImageLibraryDecode
        }
        
        let sectorCount = Game.defaultBoard.count
        
        // Определяем размеры изображения
        let imageWidth = sourceImage.width
        let imageHeight = sourceImage.height
        
        // Определяем размеры сектора на вписанной окружности
        let sectorAngle = 2.0 * .pi / Double(sectorCount)
        let radius = Double(min(imageWidth, imageHeight) / 2)
        // Смешаем угол на половину сектора
        let offsetAngle = sectorAngle / 2.0
  
        let angle = sectorAngle * Double(playerPosition) + offsetAngle
        let sectorX = Int((cos(angle) * radius ) / 1.5) + (imageWidth / 2)
        let sectorY = Int((sin(angle) * radius ) / 1.5) + (imageHeight / 2)
        sourceImage.drawCircle(
            center: (x: sectorX, y: sectorY),
            radius: Const.playerMarkCircleRadius,
            color: Const.playerMarkColor)
        
        guard let outputImageData = try? sourceImage.fileData()
        else {
            throw MapDrawerError.swimImageLibraryEncode
        }
        await App.logger.log(event: .mapIsDrawing)
        return outputImageData
    }
    
}
