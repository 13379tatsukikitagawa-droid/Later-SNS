import Testing
import Foundation
@testable import Later_再度

struct LegalLinkTests {
    @Test func urlsAreHttpsAndMatchSite() {
        let want: [LegalLink: String] = [
            .terms: "/APP-Later2/terms.html",
            .privacy: "/APP-Later2/privacy.html",
        ]
        #expect(LegalLink.allCases.count == 2)
        for l in LegalLink.allCases {
            #expect(l.url.scheme == "https")
            #expect(l.url.host == "13379tatsukikitagawa-droid.github.io")
            #expect(l.url.path == want[l])
            #expect(l.url.query == nil)
        }
    }
}
