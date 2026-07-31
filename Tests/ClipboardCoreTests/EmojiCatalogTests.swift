import ClipboardCore
import Foundation
import Testing

@Suite("EmojiCatalog")
struct EmojiCatalogTests {
    @Test func categoriesAreNonEmpty() {
        #expect(!EmojiCatalog.categories.isEmpty)
        for category in EmojiCatalog.categories {
            #expect(!category.emoji.isEmpty)
            #expect(!category.id.isEmpty)
        }
    }

    @Test func searchWithEmptyQueryReturnsCategory() {
        let smileys = EmojiCatalog.categories.first { $0.id == "smileys" }
        let result = EmojiCatalog.search("", in: smileys)
        #expect(result == smileys?.emoji)
    }

    @Test func searchMatchesNameHints() {
        let hearts = EmojiCatalog.search("heart")
        #expect(hearts.contains("❤️"))
    }

    @Test func searchMatchesUnicodeFormalName() {
        let rockets = EmojiCatalog.search("rocket")
        #expect(rockets.contains("🚀"))
        let dogs = EmojiCatalog.search("dog")
        #expect(dogs.contains("🐶") || dogs.contains("🐕"))
    }

    @Test func allEmojiDeduplicates() {
        let all = EmojiCatalog.allEmoji
        #expect(Set(all).count == all.count)
        #expect(all.count > 100)
    }
}

@Suite("PanelMode")
struct PanelModeTests {
    @Test func hasClipboardAndEmoji() {
        #expect(PanelMode.allCases.map(\.rawValue) == ["clipboard", "emoji"])
    }
}
