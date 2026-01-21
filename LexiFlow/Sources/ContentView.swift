import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject var appState = AppState()
    @State private var showFileImporter = false
    @State private var columnVisibility = NavigationSplitViewVisibility.doubleColumn
    @State private var showUnsavedChangesAlert = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(appState: appState, showFileImporter: $showFileImporter)
        } detail: {
            ZStack {
                // Ambient Background
                AmbientBackground(baseColor: appState.themeColor)
                    .ignoresSafeArea()
                
                // Background click to exit edit mode
                if appState.isSetupMode {
                    Color.black.opacity(0.001)
                        .onTapGesture {
                            if appState.isDirty {
                                showUnsavedChangesAlert = true
                            } else {
                                appState.isSetupMode = false
                            }
                        }
                }
                
                if appState.isLoading {
                    ProgressView("Loading Sheet...")
                        .controlSize(.large)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                } else if let error = appState.errorMessage {
                    VStack(spacing: 15) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .font(.headline)
                    }
                    .padding(30)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                } else if appState.isSetupMode {
                    CSVSetupView(appState: appState)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .shadow(radius: 20)
                        .padding(40)
                } else if appState.allCards.isEmpty {
                    EmptyStateView(showFileImporter: $showFileImporter, appState: appState)
                } else {
                    switch appState.sidebarSelection {
                    case .flashcards:
                        StudySessionView(appState: appState)
                    case .list:
                        CardListView(appState: appState)
                    }
                }
            }
            .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
                Button("Discard", role: .destructive) { appState.isSetupMode = false }
                Button("Save") { 
                    appState.saveCSV()
                    appState.generateCards()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have unsaved changes in your deck. Would you like to save them before exiting?")
            }
            .toolbar {
                if !appState.allCards.isEmpty && !appState.isSetupMode {
                    ToolbarItem(placement: .principal) {
                        Picker("Study Mode", selection: $appState.sidebarSelection) {
                            Text("Flashcards").tag(AppState.SidebarSelection.flashcards)
                            Text("List").tag(AppState.SidebarSelection.list)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }
                
                ToolbarItemGroup(placement: .primaryAction) {
                    if appState.sidebarSelection == .flashcards && !appState.isSetupMode {
                        Button(action: appState.shuffleCards) {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                        .help("Shuffle Cards")
                    }
                    
                    if !appState.allCards.isEmpty {
                        Button(action: { appState.resetToEmpty() }) {
                            Label("Close Deck", systemImage: "xmark.circle")
                        }
                        .help("Close Current Deck")
                    }
                    
                    Button(action: { appState.showKeyboardHelp = true }) {
                        Label("Shortcuts", systemImage: "keyboard")
                    }
                    .help("Keyboard Shortcuts")
                    
                    Button(action: { appState.showSettings = true }) {
                        Label("Settings", systemImage: "gear")
                    }
                    .help("Settings")
                }
            }
            .onDrop(of: [.fileURL, .url], isTargeted: nil) { providers in
                appState.handleDrop(providers: providers)
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                if let urls = try? result.get(), let url = urls.first {
                    appState.processDroppedFile(url: url)
                }
            }
        }
        .tint(appState.themeColor)
        .sheet(isPresented: $appState.showSettings) {
            SettingsView(appState: appState)
        }
        .sheet(isPresented: $appState.showKeyboardHelp) {
            KeyboardHelpView()
        }
        .alert("Delete Deck?", isPresented: $appState.showDeleteConfirmation) {
            Button("Delete", role: .destructive) { appState.executeDeleteDeck() }
            Button("Cancel", role: .cancel) { appState.deckToDelete = "" }
        } message: {
            Text("This will remove the deck from your recent decks. The file will not be deleted from disk.")
        }
    }
}

// Subtle animated background
struct AmbientBackground: View {
    var baseColor: Color
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .fill(baseColor.opacity(0.1))
                        .frame(width: 600, height: 600)
                        .blur(radius: 100)
                        .offset(x: animate ? -100 : 100, y: animate ? -100 : 100)
                    Circle()
                        .fill(baseColor.opacity(0.05))
                        .frame(width: 500, height: 500)
                        .blur(radius: 80)
                        .offset(x: animate ? 200 : -200, y: animate ? 100 : -100)
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 400, height: 400)
                        .blur(radius: 60)
                        .offset(x: animate ? -150 : 150, y: animate ? 200 : -200)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .animation(.easeInOut(duration: 5), value: baseColor)
        .onAppear {
            withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

struct SidebarView: View {
    @ObservedObject var appState: AppState
    @Binding var showFileImporter: Bool
    
    var body: some View {
        List {
            Section {
                Button(action: { showFileImporter = true }) {
                    Label("Load CSV", systemImage: "folder")
                }
                .help("Open a local CSV file")
                .buttonStyle(HoverButtonStyle())
            }
            
            // Favorites Deck Row (always visible)
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Favorites")
                        .fontWeight(appState.studyingFavorites ? .medium : .regular)
                    Spacer()
                    Text("\(appState.starredCardKeys.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.1)))
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !appState.starredCardKeys.isEmpty {
                        appState.loadFavorites()
                    }
                }
                .opacity(appState.starredCardKeys.isEmpty && !appState.studyingFavorites ? 0.5 : 1.0)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(appState.studyingFavorites ? appState.themeColor.opacity(0.15) : Color.clear)
                )
            }
            
            if !appState.recentDecks.isEmpty {
                Section("Decks") {
                    ForEach(appState.recentDecks) { deck in
                        DeckRow(
                            deck: deck,
                            isActive: deck.path == appState.csvPath && !appState.studyingFavorites,
                            cardCount: deck.path == appState.csvPath && !appState.studyingFavorites ? appState.allCards.count : nil,
                            themeColor: appState.themeColor,
                            onTap: {
                                if appState.studyingFavorites {
                                    appState.exitFavorites()
                                }
                                if deck.path != appState.csvPath {
                                    appState.csvPath = deck.path
                                }
                            },
                            onEdit: {
                                if appState.rawCSVData != nil {
                                    appState.isSetupMode = true
                                }
                            },
                            onDelete: {
                                appState.confirmDeleteDeck(path: deck.path)
                            }
                        )
                    }
                }
            } else {
                Section {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundColor(.secondary)
                        Text("No decks yet")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("LexiFlow")
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        #endif
    }
}

struct DeckRow: View {
    let deck: RecentDeck
    let isActive: Bool
    var cardCount: Int?
    let themeColor: Color
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isActive ? "menucard.fill" : "doc.text")
                .foregroundColor(isActive ? themeColor : .secondary)
            
            Text(deck.name)
                .lineLimit(1)
                .fontWeight(isActive ? .medium : .regular)
            
            if let count = cardCount {
                Text("(\(count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isActive {
                Button("Edit") { onEdit() }
                    .buttonStyle(HoverButtonStyle())
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? themeColor.opacity(0.15) : (isHovering ? Color.primary.opacity(0.06) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { hovering in isHovering = hovering }
        .contextMenu {
            Button("Delete Deck", role: .destructive) { onDelete() }
        }
        .help(deck.path)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

struct HoverButtonStyle: ButtonStyle {
    @State private var isHovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
            .background(configuration.isPressed ? Color.primary.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .onHover { hovering in isHovering = hovering }
    }
}

struct StudySessionView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: Double(appState.currentIndex + 1), total: Double(appState.activeCards.count))
                    .tint(appState.themeColor)
                    .frame(maxWidth: 400)
                
                Text("Card \(appState.currentIndex + 1) of \(appState.activeCards.count)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            
            if let card = appState.currentCard {
                VStack {
                    ZStack(alignment: .topTrailing) {
                        FlashcardView(
                            card: card,
                            isFlipped: appState.isFlipped,
                            showTermFirst: appState.isTermFirst,
                            themeGradient: appState.themeGradient
                        ) {
                            if !appState.isTypingMode {
                                appState.isFlipped.toggle()
                            }
                        }
                        
                        // Star button
                        Button(action: { appState.toggleStar(cardID: card.id) }) {
                            Image(systemName: appState.isStarred(card) ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundColor(appState.isStarred(card) ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                        .help("Star this card")
                    }
                    
                    if appState.isTypingMode {
                        TextField("Type answer...", text: $appState.userTypingInput)
                            .textFieldStyle(.plain)
                            .font(.title2)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(appState.isCorrect ? Color.green : Color.clear, lineWidth: 2)
                                    )
                            )
                            .frame(width: 300)
                            .onChange(of: appState.userTypingInput) { _ in
                                appState.checkAnswer()
                            }
                            .padding(.top, 20)
                        
                        if appState.isCorrect {
                            Text("Correct!")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            
            HStack(spacing: 40) {
                Button(action: appState.previousCard) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(appState.themeColor.gradient)
                }
                .disabled(appState.currentIndex == 0)
                .buttonStyle(.plain)
                .opacity(appState.currentIndex == 0 ? 0.3 : 1)
                .keyboardShortcut(.leftArrow, modifiers: [])
                
                Button(action: appState.nextCard) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(appState.themeColor.gradient)
                }
                .disabled(appState.currentIndex == appState.activeCards.count - 1)
                .buttonStyle(.plain)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }
            
            // Typing mode toggle
            Button(action: { appState.isTypingMode.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: appState.isTypingMode ? "keyboard.fill" : "keyboard")
                    Text(appState.isTypingMode ? "Typing: On" : "Typing: Off")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(appState.isTypingMode ? appState.themeColor.opacity(0.15) : Color.primary.opacity(0.05))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .help("Toggle typing mode")
        }
        .padding()
        .background(
            Group {
                // Enter key to flip
                Button("") { 
                    if !appState.isTypingMode {
                        appState.isFlipped.toggle()
                    }
                }
                .keyboardShortcut(.return, modifiers: [])
                .opacity(0)
                
                // Spacebar to flip
                Button("") { 
                    if !appState.isTypingMode {
                        appState.isFlipped.toggle()
                    }
                }
                .keyboardShortcut(.space, modifiers: [])
                .opacity(0)
            }
        )
    }
}

struct CardListView: View {
    @ObservedObject var appState: AppState
    @State private var selection: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar row
            HStack {
                Button(action: { appState.shuffleListMode() }) {
                    Label("Shuffle", systemImage: "shuffle")
                }
                .buttonStyle(HoverButtonStyle())
                
                Button(action: { appState.resetListOrder() }) {
                    Label("Reset Order", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(HoverButtonStyle())
                
                Button(action: { appState.resetListMode() }) {
                    Label("Hide All", systemImage: "eye.slash")
                }
                .buttonStyle(HoverButtonStyle())
                
                Button(action: { appState.revealAllCards() }) {
                    Label("Reveal All", systemImage: "eye")
                }
                .buttonStyle(HoverButtonStyle())
                
                Spacer()
                
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search...", text: $appState.searchQuery)
                        .textFieldStyle(.plain)
                        .frame(width: 120)
                    if !appState.searchQuery.isEmpty {
                        Button(action: { appState.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                
                Picker("", selection: $appState.isTermFirst) {
                    Text("Term → Def").tag(true)
                    Text("Def → Term").tag(false)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            Divider()
            
            List(selection: $selection) {
                ForEach(appState.filteredListCards) { card in
                    HStack(spacing: 0) {
                        // Star button
                        Button(action: { appState.toggleStar(cardID: card.id) }) {
                            Image(systemName: appState.isStarred(card) ? "star.fill" : "star")
                                .foregroundColor(appState.isStarred(card) ? .yellow : .secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                        
                        Text(appState.isTermFirst ? card.term : card.definition)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        Divider()
                        ZStack(alignment: .leading) {
                            Text(appState.isTermFirst ? card.definition : card.term)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .blur(radius: appState.revealedCardIDs.contains(card.id) ? 0 : 8)
                                .opacity(appState.revealedCardIDs.contains(card.id) ? 1 : 0.6)
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation { appState.toggleReveal(cardID: card.id) }
                                    selection = card.id
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    .tag(card.id)
                }
            }
            .listStyle(.inset)
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if appState.sidebarSelection == .list && !appState.isSetupMode {
                        if event.keyCode == 125 { // Down arrow
                            handleDownArrow()
                            return nil // Consume event to prevent native List from also moving
                        } else if event.keyCode == 126 { // Up arrow
                            handleUpArrow()
                            return nil // Consume event to prevent native List from also moving
                        }
                    }
                    return event
                }
            }
        }
        .navigationTitle("Card List")
    }
    
    func handleDownArrow() {
        let cards = appState.filteredListCards
        guard !cards.isEmpty else { return }
        
        if let currentSelection = selection,
           let currentIndex = cards.firstIndex(where: { $0.id == currentSelection }) {
            // Reveal current row and move to next
            withAnimation { appState.revealedCardIDs.insert(currentSelection) }
            let nextIndex = currentIndex + 1
            if nextIndex < cards.count {
                selection = cards[nextIndex].id
            }
        } else {
            // No selection, select first row
            selection = cards.first?.id
        }
    }
    
    func handleUpArrow() {
        let cards = appState.filteredListCards
        guard !cards.isEmpty else { return }
        
        if let currentSelection = selection,
           let currentIndex = cards.firstIndex(where: { $0.id == currentSelection }) {
            // Re-blur current selection
            withAnimation { appState.revealedCardIDs.remove(currentSelection) }
            // Move up
            let prevIndex = currentIndex - 1
            if prevIndex >= 0 {
                selection = cards[prevIndex].id
            }
        } else {
            selection = cards.last?.id
        }
    }
}

struct EmptyStateView: View {
    @Binding var showFileImporter: Bool
    @ObservedObject var appState: AppState
    var body: some View {
        VStack(spacing: 25) {
            ZStack {
                Circle().fill(.ultraThinMaterial).frame(width: 120, height: 120).shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                Image(systemName: "doc.text.viewfinder").font(.system(size: 48)).foregroundStyle(appState.themeGradient)
            }
            VStack(spacing: 8) {
                Text("Ready to Flow?").font(.title2.bold())
                Text("Drop a CSV here\nto create your deck.").multilineTextAlignment(.center).foregroundColor(.secondary)
            }
            Button("Select File") { showFileImporter = true }.buttonStyle(.borderedProminent).tint(appState.themeColor).controlSize(.large).keyboardShortcut("o", modifiers: .command)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let themes = ["Blue", "Purple", "Pink", "Orange", "Green", "Teal", "Indigo"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    HStack(spacing: 12) {
                        ForEach(themes, id: \.self) { theme in
                            Circle()
                                .fill(colorFor(theme))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: appState.themeName == theme ? 3 : 0)
                                        .opacity(0.7)
                                )
                                .shadow(color: colorFor(theme).opacity(0.4), radius: appState.themeName == theme ? 4 : 0)
                                .onTapGesture { appState.themeName = theme }
                                .accessibilityLabel(theme)
                        }
                    }
                    .padding(.vertical, 8)
                }
                Section("Study Options") {
                    Toggle(isOn: $appState.isTermFirst) { 
                        Label("Term First", systemImage: "arrow.left.arrow.right") 
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar { 
                ToolbarItem(placement: .confirmationAction) { 
                    Button("Done") { dismiss() } 
                } 
            }
        }
        .frame(width: 450, height: 220)
    }
    
    func colorFor(_ name: String) -> Color {
        switch name {
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
}

struct KeyboardHelpView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Flashcard Mode") {
                    ShortcutRow(keys: "Space / Enter", action: "Flip card")
                    ShortcutRow(keys: "← →", action: "Previous / Next card")
                }
                Section("List Mode") {
                    ShortcutRow(keys: "↓", action: "Reveal current & move down")
                    ShortcutRow(keys: "↑", action: "Hide current & move up")
                    ShortcutRow(keys: "Click definition", action: "Toggle reveal")
                }
                Section("General") {
                    ShortcutRow(keys: "⌘O", action: "Open file")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Keyboard Shortcuts")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 350, height: 320)
    }
}

struct ShortcutRow: View {
    let keys: String
    let action: String
    
    var body: some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(action)
        }
    }
}