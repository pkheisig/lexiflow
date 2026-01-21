import SwiftUI
import Combine
import UniformTypeIdentifiers
import Carbon

struct RecentDeck: Codable, Identifiable, Equatable {
    var id: String { path }
    let path: String
    var name: String
    let lastOpened: Date
}

class AppState: ObservableObject {
    @Published var csvPath: String = "" {
        didSet {
            UserDefaults.standard.set(csvPath, forKey: "csvPath")
            if !csvPath.isEmpty {
                addToRecentDecks(path: csvPath)
                loadCards()
            }
        }
    }
    
    @Published var recentDecks: [RecentDeck] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(recentDecks) {
                UserDefaults.standard.set(data, forKey: "recentDecks")
            }
        }
    }
    
    @Published var currentDeckName: String = ""
    
    enum SidebarSelection: Hashable {
        case flashcards
        case list
    }
    
    @Published var sidebarSelection: SidebarSelection = .flashcards
    @Published var studyingFavorites: Bool = false
    @Published var savedDeckPath: String = ""
    @Published var savedAllCards: [Card] = []
    @Published var savedListModeCards: [Card] = []
    
    // Data State
    @Published var rawCSVData: CSVData? {
        didSet {
            if !isLoading {
                isDirty = true
            }
        }
    }
    @Published var isDirty: Bool = false
    @Published var allCards: [Card] = []
    @Published var activeCards: [Card] = []
    @Published var currentIndex: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // List Mode State
    @Published var listModeCards: [Card] = []
    @Published var originalListOrder: [Card] = []  // Stores original order for reset
    @Published var deckCardOrders: [String: [String]] = [:] {  // Persists shuffled order per deck path (stores card keys)
        didSet {
            if let data = try? JSONEncoder().encode(deckCardOrders) {
                UserDefaults.standard.set(data, forKey: "deckCardOrders")
            }
        }
    }
    @Published var revealedCardIDs: Set<UUID> = []
    @Published var starredCardKeys: Set<String> = [] {  // Uses term+definition as stable key
        didSet {
            UserDefaults.standard.set(Array(starredCardKeys), forKey: "starredCardKeys")
        }
    }
    @Published var starredCards: [Card] = [] {  // Stores actual card data for favorites
        didSet {
            let data = starredCards.map { ["term": $0.term, "definition": $0.definition] }
            UserDefaults.standard.set(data, forKey: "starredCards")
        }
    }
    @Published var searchQuery: String = ""
    
    // Setup State
    @Published var isSetupMode: Bool = false
    @Published var selectedTermColumnIndex: Int = 0
    @Published var selectedDefinitionColumnIndex: Int = 1
    
    // Settings
    @Published var isTermFirst: Bool = true
    @Published var isTypingMode: Bool = false
    @Published var showSettings: Bool = false
    @Published var showKeyboardHelp: Bool = false
    
    // Delete Confirmation
    @Published var showDeleteConfirmation: Bool = false
    @Published var deckToDelete: String = ""
    
    // Session State
    @Published var isFlipped: Bool = false
    @Published var userTypingInput: String = "" 
    @Published var isCorrect: Bool = false
    
    // Theme State
    @Published var themeName: String = "Blue" {
        didSet {
            UserDefaults.standard.set(themeName, forKey: "themeName")
        }
    }
    
    init() {
        self.themeName = UserDefaults.standard.string(forKey: "themeName") ?? "Blue"
        
        if let data = UserDefaults.standard.data(forKey: "recentDecks"),
           let decks = try? JSONDecoder().decode([RecentDeck].self, from: data) {
            self.recentDecks = decks
        }
        
        if let keys = UserDefaults.standard.array(forKey: "starredCardKeys") as? [String] {
            self.starredCardKeys = Set(keys)
        }
        
        if let cardsData = UserDefaults.standard.array(forKey: "starredCards") as? [[String: String]] {
            self.starredCards = cardsData.compactMap {
                guard let term = $0["term"], let def = $0["definition"] else { return nil }
                return Card(term: term, definition: def)
            }
        }
        
        if let data = UserDefaults.standard.data(forKey: "deckCardOrders"),
           let orders = try? JSONDecoder().decode([String: [String]].self, from: data) {
            self.deckCardOrders = orders
        }
    }
    
    func addToRecentDecks(path: String) {
        let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        
        if let existingIndex = recentDecks.firstIndex(where: { $0.path == path }) {
            // Existing deck - update in place, don't move
            var deck = recentDecks[existingIndex]
            recentDecks[existingIndex] = RecentDeck(path: deck.path, name: deck.name, lastOpened: Date())
            currentDeckName = deck.name
        } else {
            // New deck - insert at top
            recentDecks.insert(RecentDeck(path: path, name: name, lastOpened: Date()), at: 0)
            if recentDecks.count > 10 {
                recentDecks = Array(recentDecks.prefix(10))
            }
            currentDeckName = name
        }
    }
    
    func updateCurrentDeckName(_ newName: String) {
        currentDeckName = newName
        if let index = recentDecks.firstIndex(where: { $0.path == csvPath }) {
            recentDecks[index].name = newName
        }
    }
    
    func deleteDeck(path: String) {
        recentDecks.removeAll { $0.path == path }
        if csvPath == path {
            resetToEmpty()
        }
    }
    
    var themeColor: Color {
        switch themeName {
        case "Blue": return .blue
        case "Purple": return .purple
        case "Pink": return .pink
        case "Orange": return .orange
        case "Green": return .green
        case "Teal": return .teal
        case "Indigo": return .indigo
        default: return .blue
        }
    }
    
    var themeGradient: LinearGradient {
        let start: Color
        let end: Color
        switch themeName {
        case "Blue": (start, end) = (.blue, .purple)
        case "Purple": (start, end) = (.purple, .indigo)
        case "Pink": (start, end) = (.pink, .orange)
        case "Orange": (start, end) = (.orange, .red)
        case "Green": (start, end) = (.mint, .green)
        case "Teal": (start, end) = (.cyan, .teal)
        case "Indigo": (start, end) = (.indigo, .purple)
        default: (start, end) = (.blue, .purple)
        }
        return LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    func resetToEmpty() {
        self.csvPath = ""
        self.currentDeckName = ""
        rawCSVData = nil
        allCards = []
        activeCards = []
        listModeCards = []
        isSetupMode = false
        studyingFavorites = false
    }
    
    func loadFavorites() {
        if starredCards.isEmpty { return }
        
        // Save current deck state (only if not already in favorites)
        if !studyingFavorites && !csvPath.isEmpty {
            savedDeckPath = csvPath
            savedAllCards = allCards
            savedListModeCards = listModeCards
        }
        
        studyingFavorites = true
        currentDeckName = "Favorites"
        allCards = starredCards
        activeCards = starredCards
        listModeCards = starredCards
        revealedCardIDs = []  // Clear reveals for fresh session
        currentIndex = 0
        isFlipped = false
    }
    
    func exitFavorites() {
        studyingFavorites = false
        if !savedDeckPath.isEmpty {
            csvPath = savedDeckPath
            allCards = savedAllCards
            listModeCards = savedListModeCards
            activeCards = savedAllCards
            revealedCardIDs = []  // Clear reveals when returning to original deck
            savedDeckPath = ""
            savedAllCards = []
            savedListModeCards = []
            if let deck = recentDecks.first(where: { $0.path == csvPath }) {
                currentDeckName = deck.name
            }
        }
    }
    
    func loadCards() {
        guard !csvPath.isEmpty else { return }
        addToRecentDecks(path: csvPath) // Ensure it's in recent and name is synced
        let url = URL(fileURLWithPath: csvPath)
        let data = CSVParser.parse(url: url)
        handleLoadedData(data)
    }
    
    func saveCSV() {
        guard let data = rawCSVData, !csvPath.isEmpty else { return }
        var csvString = data.headers.joined(separator: ",") + "\n"
        for row in data.rows {
            csvString += row.joined(separator: ",") + "\n"
        }
        do {
            try csvString.write(to: URL(fileURLWithPath: csvPath), atomically: true, encoding: .utf8)
            isDirty = false
        } catch {
            errorMessage = "Failed to save CSV: \(error.localizedDescription)"
        }
    }
    
    func handleLoadedData(_ data: CSVData) {
        if data.headers.isEmpty {
            errorMessage = "No data found in CSV."
            return
        }
        self.rawCSVData = data
        self.isDirty = false
        self.errorMessage = nil
        if let termIdx = data.headers.firstIndex(where: { $0.lowercased().contains("term") }) {
            self.selectedTermColumnIndex = termIdx
        } else {
            self.selectedTermColumnIndex = 0
        }
        if let defIdx = data.headers.firstIndex(where: { $0.lowercased().contains("definition") }) {
            self.selectedDefinitionColumnIndex = defIdx
        } else {
            self.selectedDefinitionColumnIndex = data.headers.count > 1 ? 1 : 0
        }
        self.generateCards()
    }
    
    func generateCards() {
        guard let data = rawCSVData else { return }
        var newCards: [Card] = []
        for row in data.rows {
            let termIdx = selectedTermColumnIndex
            let defIdx = selectedDefinitionColumnIndex
            if row.indices.contains(termIdx) && row.indices.contains(defIdx) {
                let term = row[termIdx]
                let def = row[defIdx]
                if !term.isEmpty && !def.isEmpty {
                     newCards.append(Card(term: term, definition: def))
                }
            }
        }
        self.allCards = newCards
        self.originalListOrder = newCards
        
        // Apply saved order if exists
        if let savedOrder = deckCardOrders[csvPath], !savedOrder.isEmpty {
            let cardsByKey = Dictionary(uniqueKeysWithValues: newCards.map { (cardKey($0), $0) })
            var orderedCards: [Card] = []
            for key in savedOrder {
                if let card = cardsByKey[key] {
                    orderedCards.append(card)
                }
            }
            // Add any new cards not in saved order
            for card in newCards where !savedOrder.contains(cardKey(card)) {
                orderedCards.append(card)
            }
            self.listModeCards = orderedCards
            self.activeCards = orderedCards
        } else {
            self.listModeCards = newCards
            self.activeCards = newCards
        }
        
        self.isSetupMode = false
        self.currentIndex = 0
        self.resetCardState()
    }
    
    func shuffleCards() {
        activeCards.shuffle()
        currentIndex = 0
        resetCardState()
    }
    
    func shuffleListMode() {
        listModeCards.shuffle()
        activeCards = listModeCards
        currentIndex = 0
        deckCardOrders[csvPath] = listModeCards.map { cardKey($0) }
    }
    
    func resetListOrder() {
        listModeCards = originalListOrder.map { orig in
            listModeCards.first { $0.term == orig.term && $0.definition == orig.definition } ?? orig
        }
        activeCards = listModeCards
        currentIndex = 0
        deckCardOrders.removeValue(forKey: csvPath)
    }
    
    func resetListMode() {
        withAnimation {
            revealedCardIDs = []
        }
    }
    
    func toggleReveal(cardID: UUID) {
        if revealedCardIDs.contains(cardID) {
            revealedCardIDs.remove(cardID)
        } else {
            revealedCardIDs.insert(cardID)
        }
    }
    
    func toggleStar(cardID: UUID) {
        guard let card = listModeCards.first(where: { $0.id == cardID }) ?? allCards.first(where: { $0.id == cardID }) else { return }
        let key = cardKey(card)
        if starredCardKeys.contains(key) {
            starredCardKeys.remove(key)
            starredCards.removeAll { cardKey($0) == key }
        } else {
            starredCardKeys.insert(key)
            // Store a new Card with fresh ID
            starredCards.append(Card(term: card.term, definition: card.definition))
        }
    }
    
    func cardKey(_ card: Card) -> String {
        "\(card.term)|\(card.definition)"
    }
    
    func isStarred(_ card: Card) -> Bool {
        starredCardKeys.contains(cardKey(card))
    }
    
    func revealAllCards() {
        withAnimation {
            for card in listModeCards {
                revealedCardIDs.insert(card.id)
            }
        }
    }
    
    var filteredListCards: [Card] {
        if searchQuery.isEmpty {
            return listModeCards
        }
        return listModeCards.filter {
            $0.term.localizedCaseInsensitiveContains(searchQuery) ||
            $0.definition.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    func confirmDeleteDeck(path: String) {
        deckToDelete = path
        showDeleteConfirmation = true
    }
    
    func executeDeleteDeck() {
        deleteDeck(path: deckToDelete)
        deckToDelete = ""
        showDeleteConfirmation = false
    }
    
    func restartSession() {
        activeCards = listModeCards
        revealedCardIDs = []
        currentIndex = 0
        resetCardState()
    }
    
    func resetCardState() {
        isFlipped = false
        userTypingInput = ""
        isCorrect = false
    }
    
    func nextCard() {
        if currentIndex < activeCards.count - 1 {
            currentIndex += 1
            resetCardState()
        } else {
            restartSession()
        }
    }
    
    func previousCard() {
        if currentIndex > 0 {
            currentIndex -= 1
            resetCardState()
        }
    }
    
    var currentCard: Card? {
        if activeCards.indices.contains(currentIndex) {
            return activeCards[currentIndex]
        }
        return nil
    }
    
    func checkAnswer() {
        guard let card = currentCard else { return }
        let target = isTermFirst ? card.definition : card.term
        if userTypingInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target.lowercased() {
            isCorrect = true
        } else {
            isCorrect = false
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                DispatchQueue.main.async { self.processDroppedFile(url: url) }
            }
            return true
        }
        return false
    }
    
    func processDroppedFile(url: URL) {
        let ext = url.pathExtension.lowercased()
        if ext == "csv" || ext == "txt" {
            // Copy to Documents
            let fileManager = FileManager.default
            guard let docURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let destURL = docURL.appendingPathComponent(url.lastPathComponent)
            
            do {
                if fileManager.fileExists(atPath: destURL.path) {
                    try fileManager.removeItem(at: destURL)
                }
                try fileManager.copyItem(at: url, to: destURL)
                self.csvPath = destURL.path
                // Trigger setup mode for new imports
                self.isSetupMode = true
            } catch {
                self.errorMessage = "Failed to import file: \(error.localizedDescription)"
            }
        } else {
            self.errorMessage = "Unsupported file type: \(ext). Please use CSV."
        }
    }
}