import SwiftUI

struct CSVSetupView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar-like header
            HStack {
                TextField("Deck Name", text: Binding(
                    get: { appState.currentDeckName },
                    set: { appState.updateCurrentDeckName($0) }
                ))
                .font(.title2.bold())
                .textFieldStyle(.plain)
                .frame(width: 250)
                
                Spacer()
                
                Button(action: addRow) {
                    Label("Add Row", systemImage: "plus")
                }
                
                Button("Save & Study") {
                    appState.saveCSV()
                    appState.generateCards()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            if appState.rawCSVData != nil {
                VStack(spacing: 0) {
                    // Column Mapping Section
                    HStack(spacing: 20) {
                        Text("Map Columns:")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Picker("Term", selection: $appState.selectedTermColumnIndex) {
                            ForEach(appState.rawCSVData!.headers.indices, id: \.self) { index in
                                Text(safeHeader(at: index)).tag(index)
                            }
                        }
                        .frame(width: 150)
                        
                        Image(systemName: "arrow.right")
                        
                        Picker("Definition", selection: $appState.selectedDefinitionColumnIndex) {
                            ForEach(appState.rawCSVData!.headers.indices, id: \.self) { index in
                                Text(safeHeader(at: index)).tag(index)
                            }
                        }
                        .frame(width: 150)
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    Divider()
                    
                    // Main Data Table
                    List {
                        // Header Row
                        HStack {
                            ForEach(appState.rawCSVData!.headers.indices, id: \.self) { colIndex in
                                CustomTextField(text: Binding(
                                    get: { safeHeader(at: colIndex) },
                                    set: { newValue in
                                        if appState.rawCSVData!.headers.indices.contains(colIndex) {
                                            appState.rawCSVData!.headers[colIndex] = newValue
                                        }
                                    }
                                ))
                                .frame(maxWidth: .infinity)
                                .padding(4)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .contextMenu {
                                    Button("Delete Column", role: .destructive) {
                                        deleteColumn(at: colIndex)
                                    }
                                }
                            }
                        }
                        
                        // Data Rows
                        ForEach(appState.rawCSVData!.rows.indices, id: \.self) { rowIndex in
                            HStack {
                                ForEach(appState.rawCSVData!.rows[rowIndex].indices, id: \.self) { colIndex in
                                    CustomTextField(text: Binding(
                                        get: { 
                                            if appState.rawCSVData!.rows[rowIndex].indices.contains(colIndex) {
                                                return appState.rawCSVData!.rows[rowIndex][colIndex]
                                            }
                                            return ""
                                        },
                                        set: { 
                                            if appState.rawCSVData!.rows[rowIndex].indices.contains(colIndex) {
                                                appState.rawCSVData!.rows[rowIndex][colIndex] = $0 
                                            }
                                        }
                                    ))
                                    .frame(maxWidth: .infinity)
                                    .padding(4)
                                    .background(Color(nsColor: .textBackgroundColor))
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .onDelete { indices in
                            appState.rawCSVData!.rows.remove(atOffsets: indices)
                        }
                    }
                    .listStyle(.inset)
                }
            } else {
                Text("No Data Loaded")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    func safeHeader(at index: Int) -> String {
        if let headers = appState.rawCSVData?.headers, headers.indices.contains(index) {
            return headers[index]
        }
        return ""
    }
    
    func addRow() {
        guard appState.rawCSVData != nil else { return }
        let emptyRow = Array(repeating: "", count: appState.rawCSVData!.headers.count)
        appState.rawCSVData!.rows.append(emptyRow)
    }
    
    func deleteColumn(at index: Int) {
        guard appState.rawCSVData != nil else { return }
        guard appState.rawCSVData!.headers.indices.contains(index) else { return }
        
        appState.rawCSVData!.headers.remove(at: index)
        for i in 0..<appState.rawCSVData!.rows.count {
            if appState.rawCSVData!.rows[i].indices.contains(index) {
                appState.rawCSVData!.rows[i].remove(at: index)
            }
        }
        
        // Adjust selected indices if necessary
        if appState.selectedTermColumnIndex == index {
            appState.selectedTermColumnIndex = 0
        } else if appState.selectedTermColumnIndex > index {
            appState.selectedTermColumnIndex -= 1
        }
        
        if appState.selectedDefinitionColumnIndex == index {
            appState.selectedDefinitionColumnIndex = 0
        } else if appState.selectedDefinitionColumnIndex > index {
            appState.selectedDefinitionColumnIndex -= 1
        }
    }
}

struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> ClickableTextField {
        let tf = ClickableTextField()
        tf.focusRingType = .none
        tf.isBordered = false
        tf.drawsBackground = true
        tf.backgroundColor = .clear
        tf.delegate = context.coordinator
        return tf
    }
    
    func updateNSView(_ nsView: ClickableTextField, context: Context) {
        nsView.stringValue = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomTextField
        
        init(_ parent: CustomTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
    }
}

class ClickableTextField: NSTextField {
    override func mouseDown(with event: NSEvent) {
        if let window = self.window {
            window.makeFirstResponder(self)
            
            // Let the standard event processing happen (handles selection within text)
            super.mouseDown(with: event)
            
            // If the click didn't set a specific range (e.g. clicking far right), 
            // ensure we are at the end of the text.
            if let editor = self.currentEditor() {
                // Heuristic: If we are at the start and the click was likely intended for "editing",
                // move to end. A more robust way would be comparing event location, 
                // but for now, let's just ensure we don't get stuck at the start 
                // if the user clicks the empty space.
                
                // Actually, simplest behavior requested: "invoke cursor after the word".
                // If I just always move to end when gaining focus via click:
                if editor.selectedRange.location == 0 && editor.selectedRange.length == 0 && !self.stringValue.isEmpty {
                     editor.moveToEndOfDocument(nil)
                }
            }
        } else {
            super.mouseDown(with: event)
        }
    }
}