import SwiftTelegramSdk

extension TGReplyMarkup {
    init?(inlineButtons: [[TGInlineKeyboardButton]]?) {
        guard let keyboard = TGInlineKeyboardMarkup(buttons: inlineButtons) else { return nil }
        self = .inlineKeyboardMarkup(keyboard)
    }
}
