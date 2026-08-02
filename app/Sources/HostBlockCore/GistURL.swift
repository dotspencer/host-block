import Foundation

public enum GistURL {
    /// If `urlString` is a GitHub Gist *page* URL (gist.github.com/user/id), returns the
    /// `/raw` form that serves the file contents; otherwise returns it unchanged.
    /// Already-raw links (gist.githubusercontent.com, or a path already ending in /raw)
    /// and non-gist URLs pass through untouched. For multi-file gists, /raw serves the
    /// first file, so users wanting a specific file should paste that file's Raw link.
    public static func rawified(_ urlString: String) -> String {
        guard var components = URLComponents(string: urlString),
              components.host?.lowercased() == "gist.github.com" else { return urlString }

        // A file anchor (#file-list-txt) or query has no meaning for /raw; drop them.
        components.fragment = nil
        components.query = nil

        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }

        // Only rewrite a plain gist path: /{user}/{id} or /{id}. Anything deeper
        // (an explicit /raw, a revision, a file path) is left as the user gave it.
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard (1...2).contains(parts.count) else { return urlString }

        components.path = path + "/raw"
        return components.string ?? urlString
    }
}
