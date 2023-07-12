import Foundation
import TelegramVaporBot

extension App {
    
    /// Отправка сообщения
    /// - Parameters:
    ///   - chatId: id чата в который отправляется сообщение
    ///   - text: текст сообщения
    ///   - parseMode: тип парсинга
    ///   - inlineButtons: кнопки для взаимодейстивя с пользователем
    ///   - completion: в замыкании возвращается модель сообщения, отправленная пользователю
    static func sendMessage(
        chatId: Int64,
        text: String,
        parseMode: TGParseMode? = nil,
        inlineButtons: [[TGInlineKeyboardButton]]? = nil,
        completion: ((TGMessage) async -> ())? = nil
    ) async throws {
        let params = TGSendMessageParams(
            chatId: .chat(chatId),
            text: text,
            parseMode: parseMode,
            replyMarkup: TGReplyMarkup(inlineButtons: inlineButtons)
        )
        
        let update = try await App.bot.sendMessage(params: params)
        await completion?(update)
    }
    
    /// Удаление сообщений
    /// - Parameters:
    ///   - chatId: id чата в который отправляется сообщение
    ///   - messageId: id сообщения, которое нужно удалить
    static func deleteMessage(chatId: Int64, messageId: Int) async throws {
        let params = TGDeleteMessageParams(chatId: .chat(chatId), messageId: messageId)
        
        try await App.bot.deleteMessage(params: params)
    }
    
    /// Редактирование обычного сообщения
    /// - Parameters:
    ///   - chatId: id чата в который отправляется сообщение
    ///   - messageId: id сообщения, которое нужно удалить
    ///   - newText: новый текст, если не послать - затрется
    ///   - parseMode: тип тарсинга
    ///   - newButtons: обновленные кнопки, не послать - затрутся
    ///   - completion: в замыкании возвращается модель сообщения, отправленная пользователю
    static func editMessage(
        chatId: Int64,
        messageId: Int,
        newText: String,
        parseMode: TGParseMode? = nil,
        newButtons: [[TGInlineKeyboardButton]]? = nil,
        completion: ((TGMessage) async -> ())? = nil
    ) async throws {
        let params = TGEditMessageTextParams(
            chatId: .chat(chatId),
            messageId: messageId,
            text: newText,
            parseMode: parseMode,
            replyMarkup: TGInlineKeyboardMarkup(buttons: newButtons)
        )
        
        let update = try await App.bot.editMessageText(params: params)
        if case .message(let update) = update {
            await completion?(update)
        }
    }
    
    /// Отправка файла из картинки
    /// - Parameters:
    ///   - chatId: id чата в который отправляется сообщение
    ///   - captionText: текст для медиафайлов (не путать с телом сообщения)
    ///   - parseMode: тип парсинга cationText
    ///   - photoData: картинка в сыром виде
    ///   - inlineButtons: кнопки для взаимодействия с контентом
    ///   - completion: в замыкании возвращается модель сообщения, отправленная пользователю
    static func sendPhoto(
        chatId: Int64,
        captionText: String? = nil,
        parseMode:TGParseMode? = nil,
        photoData: Data,
        inlineButtons: [[TGInlineKeyboardButton]]? = nil,
        completion: ((TGMessage) async -> ())? = nil
    ) async throws {
        let photo = TGFileInfo.file(TGInputFile(filename: "map", data: photoData))
        let params = TGSendPhotoParams(
            chatId: .chat(chatId),
            photo: photo,
            caption: captionText,
            parseMode: parseMode,
            replyMarkup: TGReplyMarkup(inlineButtons: inlineButtons)
        )
        
        let update = try await App.bot.sendPhoto(params: params)
        await completion?(update)
        await App.logger.log(event: .sendDrawingMap)
        await App.logger.log(event: .message(id: update.messageId))
    }
    
    /// Для медиафайлов свой метод редактирования сообщений. Сам медиафайл можно только удалить
    /// - Parameters:
    ///   - chatId: id чата в который отправляется сообщение
    ///   - messageId: id сообщения, которое нужно удалить
    ///   - newCaptionText: новая подпись под медиафайлом, не прислать - затрется
    ///   - parseMode: тип парсинга этой подписи, не прислать - затрется
    ///   - newButtons: новые кнопки, не прислать - затрется
    ///   - completion: в замыкании возвращается модель сообщения, отправленная пользователю
    static func editCaption(
        chatId: Int64,
        messageId: Int,
        newCaptionText: String?,
        parseMode:TGParseMode?,
        newButtons: [[TGInlineKeyboardButton]]?,
        completion: ((TGMessage) async -> ())? = nil
    ) async throws {
        let params = TGEditMessageCaptionParams(
            chatId: .chat(chatId),
            messageId: messageId,
            caption: newCaptionText,
            parseMode: parseMode,
            replyMarkup: TGInlineKeyboardMarkup(buttons: newButtons)
        )
        let update = try await App.bot.editMessageCaption(params: params)
        if case .message(let update) = update {
            await completion?(update)
        }
    }
    
    /// Отправка уже отправленного раннее и закешированного id файла
    /// - Parameters:
    ///   - chatId: id чата в который отправляется сообщение
    ///   - fileId: id файла
    ///   - captionText: подпись медиа-файла
    ///   - parseMode: тип парсинга подписи
    ///   - buttons: кнопки для взаимодейтсвия с контентом
    ///   - completion: в замыкании возвращается модель сообщения, отправленная пользователю
    static func sendPhotoFromCache(
        chatId: Int64,
        fileId: String,
        captionText: String? = nil,
        parseMode: TGParseMode? = nil,
        buttons: [[TGInlineKeyboardButton]]?,
        completion: ((TGMessage) async -> ())? = nil
    ) async throws {
        let photo = TGFileInfo.fileId(fileId)
        let update = try await App.bot.sendPhoto(
            params: TGSendPhotoParams(
                chatId: .chat(chatId),
                photo: photo,
                caption: captionText,
                parseMode: parseMode,
                replyMarkup: TGReplyMarkup(inlineButtons: buttons)
            )
        )
        await completion?(update)
        await App.logger.log(event: .sendMapFromCache)
        await App.logger.log(event: .message(id: update.messageId))
    }
    
    /// Редактирование только кнопок для взаимодействия с пользователем в сообщении
    /// - Parameters:
    ///   - chatId: id чата в который отправляется сообщение
    ///   - messageId: id сообщения
    ///   - newButtons: новые кнопки, не прислать - затрется
    ///   - completion: в замыкании возвращается модель сообщения, отправленная пользователю
    static func editInlineButtons(chatId: Int64, messageId: Int, newButtons: [[TGInlineKeyboardButton]]?, completion: ((TGMessage) async -> ())? = nil) async throws {
        let params = TGEditMessageReplyMarkupParams(
            chatId: .chat(chatId),
            messageId: messageId,
            replyMarkup: TGInlineKeyboardMarkup(buttons: newButtons)
        )
        let update = try await App.bot.editMessageReplyMarkup(params: params)
        if case .message(let update) = update {
            await completion?(update)
        }
    }
}
