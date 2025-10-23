import Foundation

/// Helper to manually set API keys in UserDefaults
/// Call this once from your app initialization if Info.plist keys aren't working
struct APIKeySetup {
    static func setupKeys() {
        // Set ESV API Key
        UserDefaults.standard.set("7e257562b014476156b8973fde5249b201e840fd", forKey: "ESV_API_KEY")
        
        print("✅ API Keys set in UserDefaults")
        print("ESV Key: \(UserDefaults.standard.string(forKey: "ESV_API_KEY") ?? "NOT SET")")
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
