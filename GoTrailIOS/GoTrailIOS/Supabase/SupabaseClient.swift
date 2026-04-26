import Supabase
import Foundation

enum SupabaseManager {
    static let client: SupabaseClient = {
        let rawURL = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String) ?? ""
        let rawKey = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String) ?? ""
        let urlString = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let url = URL(string: urlString),
            urlString.isEmpty == false,
            key.isEmpty == false,
            url.host?.isEmpty == false
        else {
            fatalError("Missing valid SUPABASE_URL or SUPABASE_ANON_KEY in Info.plist/xcconfig.")
        }

        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()
}
