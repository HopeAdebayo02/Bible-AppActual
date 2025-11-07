import Foundation

/// Helper to load API keys from bundled .env files and cache in UserDefaults
/// Call this once from your app initialization
struct APIKeySetup {
    static func setupKeys() {
        if UserDefaults.standard.string(forKey: "ESV_API_KEY") == nil {
            if let esvKey = loadESVKeyFromBundle() {
                UserDefaults.standard.set(esvKey, forKey: "ESV_API_KEY")
                print("✅ ESV API Key loaded from bundle: \(esvKey.prefix(10))...")
            } else {
                print("❌ ESV API Key not found in bundle")
            }
        } else {
            print("✅ ESV API Key already in UserDefaults")
        }
        
        if UserDefaults.standard.string(forKey: "NLT_API_KEY") == nil {
            if let nltKey = loadNLTKeyFromBundle() {
                UserDefaults.standard.set(nltKey, forKey: "NLT_API_KEY")
                print("✅ NLT API Key loaded from bundle: \(nltKey.prefix(10))...")
            } else {
                print("❌ NLT API Key not found in bundle")
            }
        } else {
            print("✅ NLT API Key already in UserDefaults")
        }
    }
    
    private static func loadESVKeyFromBundle() -> String? {
        guard let url = Bundle.main.url(forResource: "ESVAPI", withExtension: "env") else { return nil }
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = raw.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        for line in lines {
            if line.isEmpty { continue }
            if let eq = line.firstIndex(of: "=") {
                let value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                if value.isEmpty == false {
                    return value
                }
            } else {
                let token = line.replacingOccurrences(of: "[^A-Za-z0-9]", with: "", options: .regularExpression)
                if token.count >= 32 {
                    return token
                }
            }
        }
        return nil
    }
    
    private static func loadNLTKeyFromBundle() -> String? {
        guard let url = Bundle.main.url(forResource: "NLTAPI", withExtension: "env") else { return nil }
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = raw.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        for line in lines {
            if line.isEmpty { continue }
            if let eq = line.firstIndex(of: "=") {
                let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                let normalizedKey = key.replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression).uppercased()
                if normalizedKey.contains("NLT") && value.isEmpty == false {
                    return value
                }
            } else {
                let token = line.replacingOccurrences(of: "[^A-Za-z0-9-]", with: "", options: .regularExpression)
                if token.count >= 16 {
                    return token
                }
            }
        }
        return nil
    }
    
    static func verifyKeys() {
        print("🔍 Verifying API Keys...")
        
        // Check ESV
        if let esvKey = UserDefaults.standard.string(forKey: "ESV_API_KEY") {
            print("✅ ESV Key found: \(esvKey.prefix(10))...")
            print("   Full ESV Key: \(esvKey)")
            print("   Key length: \(esvKey.count) characters")
        } else {
            print("❌ ESV Key NOT found")
        }
        
        // Check NLT
        if let nltKey = UserDefaults.standard.string(forKey: "NLT_API_KEY") {
            print("✅ NLT Key found: \(nltKey.prefix(10))...")
        } else {
            print("❌ NLT Key NOT found")
        }
        
        // Check Info.plist
        if let esvPlist = Bundle.main.object(forInfoDictionaryKey: "ESV_API_KEY") as? String {
            print("✅ ESV from Info.plist: \(esvPlist.prefix(10))...")
        } else {
            print("❌ ESV NOT in Info.plist")
        }
        
        if let nltPlist = Bundle.main.object(forInfoDictionaryKey: "NLT_API_KEY") as? String {
            print("✅ NLT from Info.plist: \(nltPlist.prefix(10))...")
        } else {
            print("❌ NLT NOT in Info.plist")
        }
    }
}
