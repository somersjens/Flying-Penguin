//
//  Theme.swift
//  Elephant Challenge: Math Memory
//
//  Character catalog: 10 animals, each with a clearly different colour and a
//  matching visual theme for the whole app. Characters are earned by collecting
//  cards; the requirements live in `GameConfig.characterUnlockRequirements`.
//

import SwiftUI

/// The single currency collected throughout the game.
enum Currency {
    static let iconName = "hoop_currency"
}

/// The hoop artwork used anywhere a currency count is shown.
struct CurrencyIcon: View {
    let size: CGFloat

    var body: some View {
        Image(Currency.iconName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct AnimalCharacter: Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    /// Front-facing portrait: menus, the intro card, the collection, results.
    let imageName: String
    /// The same portrait at 256 px, for the places that draw it small — the
    /// Premium collection strip and the Settings picker. Both show the whole
    /// cast at once, and a screen that decoded ten 768 px portraits to paint
    /// ten 46 pt circles was doing nine times the work per tile, all of it on
    /// the frame the sheet opens on.
    let thumbnailName: String
    // Colour components (0–1).
    let primaryRGB: (Double, Double, Double)
    let deepRGB: (Double, Double, Double)
    let skyRGB: (Double, Double, Double)
    let tintRGB: (Double, Double, Double)

    static func == (lhs: AnimalCharacter, rhs: AnimalCharacter) -> Bool {
        lhs.id == rhs.id
    }

    var color: Color { Color(red: primaryRGB.0, green: primaryRGB.1, blue: primaryRGB.2) }
    var deepColor: Color { Color(red: deepRGB.0, green: deepRGB.1, blue: deepRGB.2) }
    var skyColor: Color { Color(red: skyRGB.0, green: skyRGB.1, blue: skyRGB.2) }
    var tintColor: Color { Color(red: tintRGB.0, green: tintRGB.1, blue: tintRGB.2) }

    var artwork: Image { Image(imageName) }
    /// Use wherever the portrait is drawn at roughly 75 pt or less.
    var thumbnail: Image { Image(thumbnailName) }

    /// Localized display name, resolved per language from the string catalog
    /// ("character.frog", "character.penguin", …).
    var localizedName: String {
        if id == "flying_penguin" { return L(key: "character.penguin") }
        return L(key: "character.\(id)")
    }
}

enum CharacterCatalog {
    /// The character available from the very first card.
    static let freeCharacterID = CharacterUnlocks.starterCharacterID

    /// The localized fallback used when the player leaves their name empty.
    /// The current game character is Penguin, so this resolves to Penguin and
    /// automatically follows every language added to the string catalog.
    static var defaultPlayerName: String {
        character(id: "flying_penguin").localizedName
    }

    /// Order must match `CharacterUnlocks.orderedCharacterIDs`. Each palette is
    /// taken from its portrait artwork.
    static let all: [AnimalCharacter] = [
        AnimalCharacter(id: "flying_penguin", name: "Penguin", emoji: "🐧",
                        imageName: "1_main_character", thumbnailName: "1_main_character",
                        primaryRGB: (0.13, 0.42, 0.86), deepRGB: (0.04, 0.16, 0.38),
                        skyRGB: (0.86, 0.95, 1.00), tintRGB: (0.68, 0.86, 0.98)),
        AnimalCharacter(id: "frog", name: "Frog", emoji: "🐸",
                        imageName: "front_1", thumbnailName: "thumb_1",
                        primaryRGB: (0.29, 0.72, 0.22), deepRGB: (0.15, 0.43, 0.11),
                        skyRGB: (0.92, 0.99, 0.91), tintRGB: (0.82, 0.97, 0.79)),
        AnimalCharacter(id: "bunny", name: "Bunny", emoji: "🐰",
                        imageName: "front_3", thumbnailName: "thumb_3",
                        primaryRGB: (0.96, 0.55, 0.64), deepRGB: (0.58, 0.31, 0.37),
                        skyRGB: (0.99, 0.94, 0.96), tintRGB: (0.97, 0.86, 0.89)),
        AnimalCharacter(id: "dog", name: "Dog", emoji: "🐶",
                        imageName: "front_4", thumbnailName: "thumb_4",
                        primaryRGB: (0.13, 0.70, 0.71), deepRGB: (0.05, 0.42, 0.43),
                        skyRGB: (0.90, 0.99, 0.99), tintRGB: (0.76, 0.97, 0.97)),
        AnimalCharacter(id: "lion", name: "Lion", emoji: "🦁",
                        imageName: "front_5", thumbnailName: "thumb_5",
                        primaryRGB: (0.97, 0.73, 0.10), deepRGB: (0.58, 0.43, 0.02),
                        skyRGB: (0.99, 0.97, 0.89), tintRGB: (0.97, 0.91, 0.74)),
        AnimalCharacter(id: "octopus", name: "Octopus", emoji: "🐙",
                        imageName: "front_6", thumbnailName: "thumb_6",
                        primaryRGB: (0.66, 0.38, 0.90), deepRGB: (0.38, 0.20, 0.54),
                        skyRGB: (0.96, 0.93, 0.99), tintRGB: (0.90, 0.82, 0.97)),
        AnimalCharacter(id: "crab", name: "Crab", emoji: "🦀",
                        imageName: "front_7", thumbnailName: "thumb_7",
                        primaryRGB: (0.91, 0.24, 0.16), deepRGB: (0.55, 0.11, 0.06),
                        skyRGB: (0.99, 0.91, 0.90), tintRGB: (0.97, 0.78, 0.76)),
        AnimalCharacter(id: "elephant", name: "Elephant", emoji: "🐘",
                        imageName: "front_8", thumbnailName: "thumb_8",
                        primaryRGB: (0.44, 0.59, 0.80), deepRGB: (0.25, 0.34, 0.48),
                        skyRGB: (0.94, 0.96, 0.99), tintRGB: (0.86, 0.91, 0.97)),
        AnimalCharacter(id: "bear", name: "Bear", emoji: "🐻",
                        imageName: "front_9", thumbnailName: "thumb_9",
                        primaryRGB: (0.65, 0.42, 0.22), deepRGB: (0.39, 0.24, 0.11),
                        skyRGB: (0.99, 0.95, 0.92), tintRGB: (0.97, 0.88, 0.80)),
        AnimalCharacter(id: "fox", name: "Fox", emoji: "🦊",
                        imageName: "front_10", thumbnailName: "thumb_10",
                        primaryRGB: (0.97, 0.48, 0.08), deepRGB: (0.58, 0.26, 0.01),
                        skyRGB: (0.99, 0.93, 0.89), tintRGB: (0.97, 0.84, 0.73))
    ]
    .sorted {
        let order = CharacterUnlocks.orderedCharacterIDs
        return (order.firstIndex(of: $0.id) ?? .max) < (order.firstIndex(of: $1.id) ?? .max)
    }

    static func character(id: String) -> AnimalCharacter {
        all.first { $0.id == id } ?? all[0]
    }

    /// The first half of the catalog: earned purely by collecting cards.
    static var cardCharacters: [AnimalCharacter] {
        all.filter { !CharacterUnlocks.premiumCharacterIDs.contains($0.id) }
    }

    /// The second half: still earnable with cards, but Premium grants them at once.
    static var premiumCharacters: [AnimalCharacter] {
        all.filter { CharacterUnlocks.premiumCharacterIDs.contains($0.id) }
    }

    /// The selected character, falling back to the starter when the selected
    /// one is not available (yet).
    static func current(isPremium: Bool) -> AnimalCharacter {
        let selected = character(id: GameSettings.characterID)
        if !CharacterUnlockStore.canUse(characterID: selected.id, isPremium: isPremium) {
            return character(id: freeCharacterID)
        }
        return selected
    }
}

/// Character access, derived from the player's card total so an unlock can
/// never be lost through a missed animation. Only the one-time celebration
/// receipt is stored separately.
enum CharacterUnlockStore {
    static var totalCards: Int {
        get { Progress.store.totalCards }
        set { Progress.store.totalCards = newValue }
    }

    /// Cards required for a character, or nil when it is not card-unlockable.
    static func requirement(for characterID: String) -> Int? {
        CharacterUnlocks.cardsRequired(for: characterID)
    }

    static func canUse(characterID: String, isPremium: Bool) -> Bool {
        CharacterUnlocks.isUnlocked(characterID: characterID,
                                    totalCards: totalCards,
                                    isPremium: isPremium)
    }

    /// The next animal still to be earned, for the home screen and reminders.
    static func nextMilestone() -> (character: AnimalCharacter, remaining: Int)? {
        guard let next = CharacterUnlocks.nextMilestone(totalCards: totalCards) else { return nil }
        return (CharacterCatalog.character(id: next.characterID), next.remaining)
    }

    /// Characters that crossed their requirement but have not been celebrated.
    static func unannouncedUnlocks(at total: Int) -> [AnimalCharacter] {
        let announced = Progress.store.announcedUnlocks
        return CharacterUnlocks.unlockedCharacterIDs(totalCards: total)
            .filter { $0 != CharacterCatalog.freeCharacterID && !announced.contains($0) }
            .map { CharacterCatalog.character(id: $0) }
    }

    static func markAnnounced(_ characterID: String) {
        var announced = Progress.store.announcedUnlocks
        announced.insert(characterID)
        Progress.store.announcedUnlocks = announced
    }
}
