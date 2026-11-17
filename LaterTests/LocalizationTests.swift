import Foundation
import Testing
@testable import Later_再度

/// 言語(日本語 / English):キーの 抜け・招待文・国名
struct LocalizationTests {
    private func table(_ lang: String, _ name: String = "Localizable") -> [String: String] {
        guard let path = Bundle.main.path(forResource: name, ofType: "strings", inDirectory: nil, forLocalization: lang),
              let dict = NSDictionary(contentsOfFile: path) as? [String: String] else { return [:] }
        return dict
    }

    @Test func 日本語と英語の両方にキーがある() {
        let en = table("en"), ja = table("ja")
        #expect(!en.isEmpty)
        #expect(Set(en.keys) == Set(ja.keys))
        for (key, value) in ja { #expect(!value.isEmpty, "ja が 空:\(key)") }
    }

    @Test func 許可の文も両方ある() {
        let en = table("en", "InfoPlist"), ja = table("ja", "InfoPlist")
        for key in ["NSCameraUsageDescription", "NSLocationWhenInUseUsageDescription", "NSMicrophoneUsageDescription",
                    "NSPhotoLibraryAddUsageDescription", "NSPhotoLibraryUsageDescription", "NSAppleMusicUsageDescription"] {
            #expect(en[key]?.isEmpty == false, "en:\(key)")
            #expect(ja[key]?.isEmpty == false, "ja:\(key)")
        }
    }

    @Test func 招待文は日本語のまま_英語の人だけ英語() {
        let url = URL(string: "lattag://join?shareUrl=https://www.icloud.com/share/abc")!
        #expect(InviteConfig.shareMessage(groupName: "部活", url: url, english: false)
                == "「部活」に招待されました。Lattag で、昨日をひらきあいましょう。\nlattag://join?shareUrl=https://www.icloud.com/share/abc")
        #expect(InviteConfig.shareMessage(groupName: "club", url: url, english: true)
                == "You're invited to \"club\". Open yesterday together on Lattag.\nlattag://join?shareUrl=https://www.icloud.com/share/abc")
    }

    @Test func 国名はLocaleから() {
        #expect(MondoGeo.latinCountryName("JP") == "Japan")
        #expect(MondoGeo.latinCountryName("US") == "USA")
        #expect(MondoGeo.latinCountryName("BT") == "Bhutan")
        #expect(MondoGeo.localCountryName("ZZ-unknown", fallback: "どこか") == "どこか")
    }
}
