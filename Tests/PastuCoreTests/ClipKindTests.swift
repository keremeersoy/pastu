import Testing
@testable import PastuCore

@Suite struct ClipKindTests {
    @Test(arguments: [
        "https://example.com",
        "http://example.com/path?q=1&r=2#frag",
        "https://developer.apple.com/documentation/appkit/nspanel",
        "  https://example.com  ",          // surrounding whitespace is ignored
        "https://example.com\n",            // trailing newline from a copy
        "HTTPS://EXAMPLE.COM/Path",
        "http://localhost:3000",
        "http://192.168.1.1:8080/admin",
        "mailto:user@example.com",
        "mailto:user@example.com?subject=Hi",
        "mailto:user@example.com?cc=other@example.com", // the query may contain @
    ])
    func detectsLinks(_ text: String) {
        #expect(ClipKind.detect(text) == .link)
    }

    @Test(arguments: [
        "",
        "   ",
        "hello world",
        "example.com",                        // no scheme: not conservative enough
        "www.example.com",
        "https://",                           // no host
        "http:// example.com",
        "https://example.com is a nice site", // a sentence containing a link
        "see https://example.com",
        "https://example.com\nhttps://example.org", // two lines
        "https://a.com https://b.com",
        "ftp://example.com/file",             // only http, https, mailto
        "file:///etc/passwd",
        "javascript:alert(1)",
        "mailto:",
        "mailto:not-an-address",
        "mailto:@example.com",
        "mailto:?subject=a@b",                // nothing before the query
        "mailto:user @example.com",          // whitespace inside
        "foo@example.com",                    // bare address, no mailto:
        "func f() { let u = \"https://x.com\" }",
        "https:/example.com",
        "https//example.com",
    ])
    func everythingElseIsText(_ text: String) {
        #expect(ClipKind.detect(text) == .text)
    }

    @Test func veryLongSingleLineIsNotALink() {
        #expect(ClipKind.detect("https://example.com/" + String(repeating: "a", count: 5000)) == .text)
    }

    @Test func filterMapsToKinds() {
        #expect(ClipFilter.all.kind == nil)
        #expect(ClipFilter.text.kind == .text)
        #expect(ClipFilter.links.kind == .link)
    }

    @Test func filterCyclesThroughAllTextLinksAndWraps() {
        #expect(ClipFilter.all.next == .text)
        #expect(ClipFilter.text.next == .links)
        #expect(ClipFilter.links.next == .all)
    }
}
