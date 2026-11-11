import Foundation

/// The players and the chore pool. Mirrors `PLAYERS` and `CHORE_POOL` in the web
/// app's index.html — the fixture test fails if the two drift apart.
public enum ChoreCatalog {
    public static let players: [Player] = [
        Player(id: "1", name: "bekindhearted"),
        Player(id: "2", name: "megadinolava"),
    ]

    public static let pool: [Chore] = [
        Chore(id: "load-dishwasher",     name: "load dishwasher",             cat: "kitchen",  pts: 15, tiers: [5, 5, 8],     tierDays: [0, 3, 6]),
        Chore(id: "unload-dishwasher",   name: "unload dishwasher",           cat: "kitchen",  pts: 15, tiers: [5, 5, 8],     tierDays: [0, 3, 6]),
        Chore(id: "wipe-counters",       name: "wipe kitchen counters",       cat: "kitchen",  pts: 10, tiers: [4, 6, 10],    tierDays: [0, 2, 5]),
        Chore(id: "wipe-stovetop",       name: "wipe stovetop",               cat: "kitchen",  pts: 15, tiers: [4, 7, 12],    tierDays: [0, 3, 7]),
        Chore(id: "sweep-kitchen",       name: "sweep kitchen floor",         cat: "kitchen",  pts: 15, tiers: [6, 10, 18],   tierDays: [0, 2, 5]),
        Chore(id: "empty-kitchen-trash", name: "empty kitchen trash",         cat: "kitchen",  pts: 10, tiers: [3, 5, 8],     tierDays: [0, 2, 4]),
        Chore(id: "wipe-microwave",      name: "wipe microwave",              cat: "kitchen",  pts: 10, tiers: [3, 5, 10],    tierDays: [0, 4, 8]),
        Chore(id: "wipe-bath-counter",   name: "wipe bathroom counter",       cat: "bathroom", pts: 10, tiers: [3, 5, 8],     tierDays: [0, 2, 5]),
        Chore(id: "scrub-toilet",        name: "scrub toilet",                cat: "bathroom", pts: 20, tiers: [5, 9, 15],    tierDays: [0, 3, 7]),
        Chore(id: "wipe-mirrors",        name: "wipe mirrors",                cat: "bathroom", pts: 8,  tiers: [3, 4, 6],     tierDays: [0, 4, 8]),
        Chore(id: "sweep-bathroom",      name: "sweep bathroom floor",        cat: "bathroom", pts: 10, tiers: [4, 6, 10],    tierDays: [0, 3, 7]),
        Chore(id: "trash-kids-bath",     name: "empty kids bathroom trash",   cat: "bathroom", pts: 8,  tiers: [2, 3, 5],     tierDays: [0, 3, 6]),
        Chore(id: "trash-main-bath",     name: "empty main bathroom trash",   cat: "bathroom", pts: 8,  tiers: [2, 3, 5],     tierDays: [0, 3, 6]),
        Chore(id: "trash-guest-bath",    name: "empty guest bathroom trash",  cat: "bathroom", pts: 6,  tiers: [2, 3, 4],     tierDays: [0, 4, 8]),
        Chore(id: "start-laundry",       name: "start a load of laundry",     cat: "laundry",  pts: 10, tiers: [4, 4, 4],     tierDays: [0, 0, 0]),
        Chore(id: "switch-laundry",      name: "switch laundry",              cat: "laundry",  pts: 8,  tiers: [3, 3, 3],     tierDays: [0, 0, 0]),
        Chore(id: "fold-laundry",        name: "fold and put away laundry",   cat: "laundry",  pts: 25, tiers: [10, 15, 22],  tierDays: [0, 2, 5]),
        Chore(id: "collect-laundry",     name: "collect dirty laundry",       cat: "laundry",  pts: 8,  tiers: [3, 5, 8],     tierDays: [0, 2, 4]),
        Chore(id: "vacuum-living-room",  name: "vacuum living room",          cat: "floors",   pts: 25, tiers: [10, 14, 20],  tierDays: [0, 3, 7]),
        Chore(id: "pick-up-clutter",     name: "pick up common area clutter", cat: "floors",   pts: 12, tiers: [5, 9, 15],    tierDays: [0, 2, 4]),
        Chore(id: "wipe-dining-table",   name: "wipe dining table",           cat: "floors",   pts: 10, tiers: [4, 6, 8],     tierDays: [0, 1, 3]),
        Chore(id: "dog-poop",            name: "pick up dog poop",            cat: "outdoor",  pts: 15, tiers: [5, 10, 18],   tierDays: [0, 1, 3]),
        Chore(id: "take-out-trash",      name: "take out trash/recycling",    cat: "outdoor",  pts: 10, tiers: [4, 4, 6],     tierDays: [0, 3, 7]),
        Chore(id: "water-plants",        name: "water plants",                cat: "outdoor",  pts: 10, tiers: [4, 4, 8],     tierDays: [0, 3, 7]),
        Chore(id: "make-bed",            name: "make bed",                    cat: "room",     pts: 8,  tiers: [3, 3, 5],     tierDays: [0, 2, 4]),
        Chore(id: "pick-up-room",        name: "pick up room floor",          cat: "room",     pts: 12, tiers: [5, 8, 15],    tierDays: [0, 2, 4]),
        Chore(id: "put-away-clothes",    name: "put away clean clothes",      cat: "room",     pts: 12, tiers: [5, 8, 12],    tierDays: [0, 2, 5]),
    ]
}
