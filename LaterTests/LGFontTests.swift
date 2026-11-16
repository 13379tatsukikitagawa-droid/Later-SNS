import Testing
import UIKit
@testable import Later_再度

@MainActor
struct LGFontTests {
    @Test func sixFamiliesResolveByName() {
        #expect(LGFont.missingFonts().isEmpty, "未登録: \(LGFont.missingFonts())")
    }

    @Test func brandNames() {
        #expect(Brand.name == "Lattag")
        #expect(Brand.isOurScheme(URL(string: "lattag://join?shareUrl=https://www.icloud.com/share/x")!))
        #expect(Brand.isOurScheme(URL(string: "later://join?shareUrl=https://www.icloud.com/share/x")!))
        #expect(!Brand.isOurScheme(URL(string: "https://example.com")!))
    }
}
