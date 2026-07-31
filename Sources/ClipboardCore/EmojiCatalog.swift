import Foundation

/// A named group of emoji characters shown in the picker.
public struct EmojiCategory: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let symbol: String
    public let emoji: [String]

    public init(id: String, name: String, symbol: String, emoji: [String]) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.emoji = emoji
    }
}

/// Offline Apple-color emoji catalog used by the popup's Emoji tab.
public enum EmojiCatalog {
    public static let categories: [EmojiCategory] = [
        EmojiCategory(
            id: "smileys",
            name: "Smileys",
            symbol: "😀",
            emoji: [
                "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃",
                "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "☺️", "😚",
                "😙", "🥲", "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭",
                "🤫", "🤔", "🤐", "🤨", "😐", "😑", "😶", "🫥", "😏", "😒",
                "🙄", "😬", "😮‍💨", "🤥", "😌", "😔", "😪", "🤤", "😴", "😷",
                "🤒", "🤕", "🤢", "🤮", "🥵", "🥶", "🥴", "😵", "🤯", "🤠",
                "🥳", "🥸", "😎", "🤓", "🧐", "😕", "🫤", "😟", "🙁", "☹️",
                "😮", "😯", "😲", "😳", "🥺", "😦", "😧", "😨", "😰", "😥",
                "😢", "😭", "😱", "😖", "😣", "😞", "😓", "😩", "😫", "🥱",
                "😤", "😡", "😠", "🤬", "😈", "👿", "💀", "☠️", "💩", "🤡",
            ]
        ),
        EmojiCategory(
            id: "people",
            name: "People",
            symbol: "👋",
            emoji: [
                "👋", "🤚", "🖐️", "✋", "🖖", "🫱", "🫲", "👌", "🤌", "🤏",
                "✌️", "🤞", "🫰", "🤟", "🤘", "🤙", "👈", "👉", "👆", "🖕",
                "👇", "☝️", "👍", "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌",
                "🫶", "👐", "🤲", "🤝", "🙏", "✍️", "💅", "🤳", "💪", "🦾",
                "🦵", "🦶", "👂", "👃", "🧠", "👀", "👁️", "👅", "👄", "🫦",
                "👶", "🧒", "👦", "👧", "🧑", "👱", "👨", "🧔", "👩", "🧓",
                "👴", "👵", "🙍", "🙎", "🙅", "🙆", "💁", "🙋", "🧏", "🙇",
                "🤦", "🤷", "👮", "🕵️", "💂", "🥷", "👷", "🫅", "🤴", "👸",
                "👳", "👲", "🧕", "🤵", "👰", "🤰", "🤱", "👼", "🎅", "🤶",
                "🦸", "🦹", "🧙", "🧚", "🧛", "🧜", "🧝", "🧞", "🧟", "💆",
            ]
        ),
        EmojiCategory(
            id: "animals",
            name: "Animals",
            symbol: "🐶",
            emoji: [
                "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐻‍❄️", "🐨",
                "🐯", "🦁", "🐮", "🐷", "🐽", "🐸", "🐵", "🙈", "🙉", "🙊",
                "🐒", "🐔", "🐧", "🐦", "🐤", "🐣", "🐥", "🦆", "🦅", "🦉",
                "🦇", "🐺", "🐗", "🐴", "🦄", "🐝", "🪱", "🐛", "🦋", "🐌",
                "🐞", "🐜", "🪰", "🪲", "🪳", "🦟", "🦗", "🕷️", "🕸️", "🦂",
                "🐢", "🐍", "🦎", "🦖", "🦕", "🐙", "🦑", "🦐", "🦞", "🦀",
                "🐡", "🐠", "🐟", "🐬", "🐳", "🐋", "🦈", "🐊", "🐅", "🐆",
                "🦓", "🦍", "🦧", "🦣", "🐘", "🦛", "🦏", "🐪", "🐫", "🦒",
                "🦘", "🦬", "🐃", "🐂", "🐄", "🐎", "🐖", "🐏", "🐑", "🦙",
                "🐐", "🦌", "🐕", "🐩", "🦮", "🐕‍🦺", "🐈", "🐈‍⬛", "🪶", "🐓",
            ]
        ),
        EmojiCategory(
            id: "food",
            name: "Food",
            symbol: "🍎",
            emoji: [
                "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈",
                "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦",
                "🥬", "🥒", "🌶️", "🫑", "🌽", "🥕", "🫒", "🧄", "🧅", "🥔",
                "🍠", "🥐", "🥯", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳", "🧈",
                "🥞", "🧇", "🥓", "🥩", "🍗", "🍖", "🦴", "🌭", "🍔", "🍟",
                "🍕", "🫓", "🥪", "🥙", "🧆", "🌮", "🌯", "🫔", "🥗", "🥘",
                "🫕", "🥫", "🍝", "🍜", "🍲", "🍛", "🍣", "🍱", "🥟", "🦪",
                "🍤", "🍙", "🍚", "🍘", "🍥", "🥠", "🥮", "🍢", "🍡", "🍧",
                "🍨", "🍦", "🥧", "🧁", "🍰", "🎂", "🍮", "🍭", "🍬", "🍫",
                "🍿", "🍩", "🍪", "🌰", "🥜", "🍯", "🥛", "🍼", "☕", "🍵",
            ]
        ),
        EmojiCategory(
            id: "travel",
            name: "Travel",
            symbol: "✈️",
            emoji: [
                "🚗", "🚕", "🚙", "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "🚐",
                "🛻", "🚚", "🚛", "🚜", "🦯", "🦽", "🦼", "🛴", "🚲", "🛵",
                "🏍️", "🛺", "🚨", "🚔", "🚍", "🚘", "🚖", "🚡", "🚠", "🚟",
                "🚃", "🚋", "🚞", "🚝", "🚄", "🚅", "🚈", "🚂", "🚆", "🚇",
                "🚊", "🚉", "✈️", "🛫", "🛬", "🛩️", "💺", "🛰️", "🚀", "🛸",
                "🚁", "🛶", "⛵", "🚤", "🛥️", "🛳️", "⛴️", "🚢", "⚓", "🪝",
                "⛽", "🚧", "🚦", "🚥", "🚏", "🗺️", "🗿", "🗽", "🗼", "🏰",
                "🏯", "🏟️", "🎡", "🎢", "🎠", "⛲", "⛱️", "🏖️", "🏝️", "🏜️",
                "🌋", "⛰️", "🏔️", "🗻", "🏕️", "⛺", "🏠", "🏡", "🏘️", "🏚️",
                "🏗️", "🏭", "🏢", "🏬", "🏣", "🏤", "🏥", "🏦", "🏨", "🏪",
            ]
        ),
        EmojiCategory(
            id: "objects",
            name: "Objects",
            symbol: "💡",
            emoji: [
                "⌚", "📱", "📲", "💻", "⌨️", "🖥️", "🖨️", "🖱️", "🖲️", "🕹️",
                "🗜️", "💽", "💾", "💿", "📀", "📼", "📷", "📸", "📹", "🎥",
                "📽️", "🎞️", "📞", "☎️", "📟", "📠", "📺", "📻", "🎙️", "🎚️",
                "🎛️", "🧭", "⏱️", "⏲️", "⏰", "🕰️", "⌛", "⏳", "📡", "🔋",
                "🔌", "💡", "🔦", "🕯️", "🪔", "🧯", "🛢️", "💸", "💵", "💴",
                "💶", "💷", "🪙", "💰", "💳", "💎", "⚖️", "🪜", "🧰", "🪛",
                "🔧", "🔨", "⚒️", "🛠️", "⛏️", "🪚", "🔩", "⚙️", "🪤", "🧱",
                "⛓️", "🧲", "🔫", "💣", "🧨", "🪓", "🔪", "🗡️", "⚔️", "🛡️",
                "🚬", "⚰️", "🪦", "⚱️", "🏺", "🔮", "📿", "🧿", "💈", "⚗️",
                "🔭", "🔬", "🕳️", "🩹", "🩺", "💊", "💉", "🩸", "🧬", "🦠",
            ]
        ),
        EmojiCategory(
            id: "symbols",
            name: "Symbols",
            symbol: "💜",
            emoji: [
                "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔",
                "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮️",
                "✝️", "☪️", "🕉️", "☸️", "✡️", "🔯", "🕎", "☯️", "☦️", "🛐",
                "⛎", "♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐",
                "♑", "♒", "♓", "🆔", "⚛️", "🉑", "☢️", "☣️", "📴", "📳",
                "🈶", "🈚", "🈸", "🈺", "🈷️", "✴️", "🆚", "💮", "🉐", "㊙️",
                "㊗️", "🈴", "🈵", "🈹", "🈲", "🅰️", "🅱️", "🆎", "🆑", "🅾️",
                "🆘", "❌", "⭕", "🛑", "⛔", "📛", "🚫", "💯", "💢", "♨️",
                "🚷", "🚯", "🚳", "🚱", "🔞", "📵", "🚭", "❗", "❕", "❓",
                "❔", "‼️", "⁉️", "🔅", "🔆", "〽️", "⚠️", "🚸", "🔱", "⚜️",
            ]
        ),
        EmojiCategory(
            id: "flags",
            name: "Flags",
            symbol: "🏳️",
            emoji: [
                "🏳️", "🏴", "🏁", "🚩", "🏳️‍🌈", "🏳️‍⚧️", "🇺🇳", "🇦🇫", "🇦🇽", "🇦🇱",
                "🇩🇿", "🇦🇸", "🇦🇩", "🇦🇴", "🇦🇮", "🇦🇶", "🇦🇬", "🇦🇷", "🇦🇲", "🇦🇼",
                "🇦🇺", "🇦🇹", "🇦🇿", "🇧🇸", "🇧🇭", "🇧🇩", "🇧🇧", "🇧🇾", "🇧🇪", "🇧🇿",
                "🇧🇯", "🇧🇲", "🇧🇹", "🇧🇴", "🇧🇦", "🇧🇼", "🇧🇷", "🇮🇴", "🇻🇬", "🇧🇳",
                "🇧🇬", "🇧🇫", "🇧🇮", "🇰🇭", "🇨🇲", "🇨🇦", "🇮🇨", "🇨🇻", "🇧🇶", "🇰🇾",
                "🇨🇫", "🇹🇩", "🇨🇱", "🇨🇳", "🇨🇽", "🇨🇨", "🇨🇴", "🇰🇲", "🇨🇬", "🇨🇩",
                "🇨🇰", "🇨🇷", "🇨🇮", "🇭🇷", "🇨🇺", "🇨🇼", "🇨🇾", "🇨🇿", "🇩🇰", "🇩🇯",
                "🇩🇲", "🇩🇴", "🇪🇨", "🇪🇬", "🇸🇻", "🇬🇶", "🇪🇷", "🇪🇪", "🇸🇿", "🇪🇹",
                "🇪🇺", "🇫🇰", "🇫🇴", "🇫🇯", "🇫🇮", "🇫🇷", "🇬🇫", "🇵🇫", "🇹🇫", "🇬🇦",
                "🇬🇲", "🇬🇪", "🇩🇪", "🇬🇭", "🇬🇮", "🇬🇷", "🇬🇱", "🇬🇩", "🇬🇵", "🇬🇺",
            ]
        ),
    ]

    /// Every emoji across all categories, de-duplicated in catalog order.
    public static var allEmoji: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for category in categories {
            for item in category.emoji where seen.insert(item).inserted {
                result.append(item)
            }
        }
        return result
    }

    /// Filters the catalog. Empty query returns every emoji in `category`, or
    /// the full catalog when `category` is `nil`.
    ///
    /// Matching uses:
    /// - literal substring of the emoji itself
    /// - Unicode formal names via `Any-Name` (e.g. "grinning face")
    /// - a small set of common English aliases
    public static func search(_ query: String, in category: EmojiCategory? = nil) -> [String] {
        let source = category?.emoji ?? allEmoji
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return source }

        let needle = trimmed.lowercased()
        let tokens = needle.split { $0.isWhitespace || $0 == "-" || $0 == "_" }
            .map(String.init)
            .filter { !$0.isEmpty }

        return source.filter { emoji in
            if emoji.localizedCaseInsensitiveContains(trimmed) { return true }
            let haystack = searchableText(for: emoji)
            if haystack.contains(needle) { return true }
            // Multi-word queries: every token must appear somewhere in the name.
            if tokens.count > 1 {
                return tokens.allSatisfy { haystack.contains($0) }
            }
            return false
        }
    }

    private static func searchableText(for emoji: String) -> String {
        searchableTextLock.lock()
        defer { searchableTextLock.unlock() }
        if let cached = searchableTextCache[emoji] { return cached }
        var parts: [String] = []
        parts.append(contentsOf: nameHints[emoji] ?? [])
        // Unlock while doing ICU work? Keep locked for simplicity — transforms are fast once cached.
        parts.append(contentsOf: unicodeNameTokens(for: emoji))
        let text = parts.joined(separator: " ").lowercased()
        searchableTextCache[emoji] = text
        return text
    }

    /// Cached ICU + alias haystacks so typing does not re-transform every glyph.
    private static var searchableTextCache: [String: String] = [:]
    private static let searchableTextLock = NSLock()

    /// Turns `😀` into tokens like `grinning`, `face` via ICU `Any-Name`.
    private static func unicodeNameTokens(for emoji: String) -> [String] {
        let mutable = NSMutableString(string: emoji)
        guard CFStringTransform(mutable, nil, "Any-Name" as CFString, false) else {
            return []
        }
        // e.g. "\\N{GRINNING FACE}\\N{VARIATION SELECTOR-16}"
        let raw = (mutable as String)
            .replacingOccurrences(of: "\\N{", with: " ")
            .replacingOccurrences(of: "}", with: " ")
            .lowercased()
        return raw
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { token in
                token.count > 1
                    && token != "variation"
                    && token != "selector"
                    && !token.hasPrefix("vs")
            }
    }

    /// Lightweight aliases for queries that do not appear in Unicode names.
    private static let nameHints: [String: [String]] = [
        "😀": ["smile", "happy"],
        "😂": ["joy", "laugh", "lol", "tears"],
        "❤️": ["heart", "love"],
        "🔥": ["fire", "lit", "hot"],
        "👍": ["thumbs", "like", "yes", "ok"],
        "👎": ["thumbs", "dislike", "no"],
        "🎉": ["party", "celebrate", "tada"],
        "✨": ["sparkles", "shine"],
        "🚀": ["rocket", "launch"],
        "🐶": ["dog", "puppy"],
        "🐱": ["cat", "kitten"],
        "🍎": ["apple"],
        "☕": ["coffee", "tea"],
        "✈️": ["plane", "flight", "airplane"],
        "💡": ["idea", "bulb"],
        "👋": ["wave", "hello", "hi", "bye"],
        "🙏": ["pray", "please", "thanks", "thank"],
        "💯": ["hundred", "perfect"],
        "😎": ["cool", "sunglasses"],
        "🥳": ["party", "celebrate"],
        "😊": ["smile", "blush", "happy"],
        "🤣": ["rofl", "laugh", "lol"],
        "😍": ["love", "heart", "eyes"],
        "🤔": ["think", "hmm"],
        "😭": ["cry", "sad", "tears"],
        "😉": ["wink"],
        "🎂": ["cake", "birthday"],
        "🍕": ["pizza"],
        "🍺": ["beer", "drink"],
        "🏠": ["home", "house"],
        "⭐": ["star"],
        "✅": ["check", "done", "yes"],
        "❌": ["x", "no", "cross"],
    ]
}
