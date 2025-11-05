import SwiftUI
import UIKit

struct APIKeyManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKeys: [String: String] = [:]
    @State private var showingKeyInput = false
    @State private var selectedKeyType: APIKeyType?
    @State private var keyInputText = ""
    @State private var showingDeleteAlert = false
    @State private var keyToDelete: APIKeyType?
    
    private let keyTypes: [APIKeyType] = [
        APIKeyType(name: "ESV_API_KEY", displayName: "ESV (Crossway)", description: "English Standard Version from Crossway", isRequired: false),
        APIKeyType(name: "NLT_API_KEY", displayName: "NLT", description: "New Living Translation", isRequired: false),
        APIKeyType(name: "APIBIBLE_API_KEY", displayName: "API.Bible", description: "Alternative NLT source", isRequired: false)
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Manage your Bible translation API keys. These keys enable access to premium translations like ESV and NLT.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } header: {
                    Text("About API Keys")
                }
                
                Section("Available Translations") {
                    ForEach(keyTypes, id: \.name) { keyType in
                        APIKeyRow(
                            keyType: keyType,
                            hasKey: apiKeys[keyType.name] != nil,
                            onEdit: {
                                selectedKeyType = keyType
                                keyInputText = apiKeys[keyType.name] ?? ""
                                showingKeyInput = true
                            },
                            onDelete: {
                                keyToDelete = keyType
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
                
                Section("Instructions") {
                    VStack(alignment: .leading, spacing: 12) {
                        InstructionRow(
                            title: "ESV API Key",
                            instruction: "Visit api.esv.org to register for a free API key"
                        )
                        
                        InstructionRow(
                            title: "NLT API Key",
                            instruction: "Contact Tyndale House Publishers for NLT API access"
                        )
                        
                        InstructionRow(
                            title: "API.Bible Key",
                            instruction: "Register at scripture.api.bible for free access"
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("API Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadAPIKeys()
            }
            .sheet(isPresented: $showingKeyInput) {
                if let keyType = selectedKeyType {
                    APIKeyInputSheet(
                        keyType: keyType,
                        initialValue: keyInputText,
                        onSave: { newKey in
                            saveAPIKey(keyType.name, value: newKey)
                            showingKeyInput = false
                        },
                        onCancel: {
                            showingKeyInput = false
                        }
                    )
                }
            }
            .alert("Delete API Key", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let keyType = keyToDelete {
                        deleteAPIKey(keyType.name)
                    }
                }
            } message: {
                if let keyType = keyToDelete {
                    Text("Are you sure you want to delete the \(keyType.displayName) API key?")
                }
            }
        }
    }
    
    // MARK: - API Key Management
    
    private func loadAPIKeys() {
        for keyType in keyTypes {
            if let key = UserDefaults.standard.string(forKey: keyType.name), !key.isEmpty {
                apiKeys[keyType.name] = key
            }
        }
    }
    
    private func saveAPIKey(_ keyName: String, value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue.isEmpty {
            UserDefaults.standard.removeObject(forKey: keyName)
            apiKeys.removeValue(forKey: keyName)
        } else {
            UserDefaults.standard.set(trimmedValue, forKey: keyName)
            apiKeys[keyName] = trimmedValue
        }
    }
    
    private func deleteAPIKey(_ keyName: String) {
        UserDefaults.standard.removeObject(forKey: keyName)
        apiKeys.removeValue(forKey: keyName)
    }
}

// MARK: - Supporting Views

struct APIKeyRow: View {
    let keyType: APIKeyType
    let hasKey: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(keyType.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(keyType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Status indicator
                Image(systemName: hasKey ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(hasKey ? .green : .gray)
                
                // Action buttons
                Button(hasKey ? "Edit" : "Add") {
                    onEdit()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                if hasKey {
                    Button("Delete") {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct InstructionRow: View {
    let title: String
    let instruction: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(instruction)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct APIKeyInputSheet: View {
    let keyType: APIKeyType
    let initialValue: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var keyText: String
    @FocusState private var isTextFieldFocused: Bool
    
    init(keyType: APIKeyType, initialValue: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.keyType = keyType
        self.initialValue = initialValue
        self.onSave = onSave
        self.onCancel = onCancel
        self._keyText = State(initialValue: initialValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter \(keyType.displayName) API Key")
                        .font(.headline)
                    
                    Text(keyType.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter your API key", text: $keyText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                if !keyText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Key Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(maskedKey(keyText))
                            .font(.caption.monospaced())
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(keyText)
                    }
                    .disabled(keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
    
    private func maskedKey(_ key: String) -> String {
        guard key.count > 8 else { return key }
        let start = String(key.prefix(4))
        let end = String(key.suffix(4))
        let middle = String(repeating: "•", count: max(0, key.count - 8))
        return "\(start)\(middle)\(end)"
    }
}

// MARK: - Models

struct APIKeyType {
    let name: String
    let displayName: String
    let description: String
    let isRequired: Bool
}

// MARK: - Preview

#Preview {
    APIKeyManagementView()
}
