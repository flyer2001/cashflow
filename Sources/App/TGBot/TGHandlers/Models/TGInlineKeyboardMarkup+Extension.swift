import SwiftTelegramSdk

extension TGInlineKeyboardMarkup {
    convenience init?(buttons: [[TGInlineKeyboardButton]]?) {
        guard let buttons = buttons else { return nil }
        self.init(inlineKeyboard: buttons)
    }
}
