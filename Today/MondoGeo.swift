import Foundation

// v19 Mondo の地球儀:光の場所(国 + 都道府県・州の中心)と、地球儀の点。
// Mondo の写真は「国」と「都道府県・州」しか持たない(元の座標は送らない)。
// 光は、その中心に置く。表にない都道府県・州は、国の中心から少しずらして置く(同じ国の光が1点に重ならないように)。

struct GeoPoint: Equatable, Sendable {
    let lat: Double
    let lon: Double
}

/// 地球儀の光1つ(きのう撮られた場所)
struct MondoLight: Identifiable, Equatable {
    /// "JP|東京都"
    let id: String
    /// チップ・カードの名前(都道府県・州。なければ国)
    let name: String
    /// 照準の下に出す英字(TOKYO)
    let latinName: String
    let countryCode: String
    let countryName: String
    let point: GeoPoint
    let count: Int
    /// 多い順に3つまで
    let tags: [String]
    /// その場所の写真(表示の順)
    let entryIDs: [String]

    /// 「JAPAN ・ 35.7°N 139.7°E」
    var coordinateText: String {
        let ns = point.lat >= 0 ? "N" : "S", ew = point.lon >= 0 ? "E" : "W"
        return String(format: "%@ ・ %.1f°%@ %.1f°%@", countryName.uppercased(), abs(point.lat), ns, abs(point.lon), ew)
    }
}

enum MondoGeo {
    // MARK: 光をまとめる

    /// その日の Mondo を、場所ごとの光にまとめる(多い順)
    static func lights(from entries: [MondoEntry]) -> [MondoLight] {
        var groups: [String: [MondoEntry]] = [:]
        var order: [String] = []
        for entry in entries {
            guard let place = entry.place else { continue }
            let key = "\(place.countryCode.uppercased())|\(place.region ?? "")"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(entry)
        }
        let made: [MondoLight] = order.compactMap { key in
            guard let list = groups[key], let place = list.first?.place,
                  let point = point(countryCode: place.countryCode, region: place.region) else { return nil }
            var tagCounts: [String: Int] = [:]
            for entry in list { for tag in entry.tags { tagCounts[tag, default: 0] += 1 } }
            let tags = tagCounts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(3).map(\.key)
            let region = place.region.flatMap { $0.isEmpty ? nil : $0 }
            return MondoLight(
                id: key,
                name: region ?? place.countryName,
                latinName: latinName(countryCode: place.countryCode, region: region) ?? (region ?? place.countryName).uppercased(),
                countryCode: place.countryCode.uppercased(),
                countryName: englishCountry[place.countryCode.uppercased()] ?? place.countryName,
                point: point,
                count: list.count,
                tags: tags,
                entryIDs: list.map(\.id)
            )
        }
        return made.sorted { $0.count != $1.count ? $0.count > $1.count : $0.id < $1.id }
    }

    /// 経度で となりの光(東へ)
    static func next(after light: MondoLight, in lights: [MondoLight]) -> MondoLight? {
        let sorted = lights.sorted { $0.point.lon < $1.point.lon }
        guard let index = sorted.firstIndex(where: { $0.id == light.id }), sorted.count > 1 else { return nil }
        return sorted[(index + 1) % sorted.count]
    }

    // MARK: 場所 → 緯度経度

    static func point(countryCode: String, region: String?) -> GeoPoint? {
        let code = countryCode.uppercased()
        if let region, !region.isEmpty, let hit = regionTable[code]?[normalize(region)] {
            return GeoPoint(lat: hit.lat, lon: hit.lon)
        }
        guard let center = countryCenter[code] else { return nil }
        guard let region, !region.isEmpty else { return GeoPoint(lat: center.0, lon: center.1) }
        // 表にない都道府県・州:国の中心から、名前で決まる向きへ少しずらす(毎回同じ場所)
        var hash: UInt64 = 1469598103934665603
        for b in region.utf8 { hash = (hash ^ UInt64(b)) &* 1099511628211 }
        let angle = Double(hash % 360) * .pi / 180
        let distance = 1.0 + Double((hash >> 9) % 100) / 100 * 1.5
        return GeoPoint(lat: center.0 + sin(angle) * distance, lon: center.1 + cos(angle) * distance)
    }

    static func latinName(countryCode: String, region: String?) -> String? {
        let code = countryCode.uppercased()
        if let region, !region.isEmpty, let hit = regionTable[code]?[normalize(region)] { return hit.latin }
        if region == nil || region?.isEmpty == true { return englishCountry[code]?.uppercased() }
        return nil
    }

    /// 「東京都」「Tokyo」「tokyo-to」を同じに扱う
    static func normalize(_ text: String) -> String {
        var s = text.lowercased().folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil)
        for suffix in ["-to", "-fu", "-ken", " prefecture", "-do"] where s.hasSuffix(suffix) && s.count > suffix.count + 1 {
            s = String(s.dropLast(suffix.count))
        }
        if s.count > 2, let last = s.last, "都府県".contains(last) { s = String(s.dropLast()) }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private struct RegionHit { let lat: Double; let lon: Double; let latin: String }

    private static let regionTable: [String: [String: RegionHit]] = {
        var table: [String: [String: RegionHit]] = [:]
        func add(_ code: String, _ rows: [(String, String, Double, Double)]) {
            var map: [String: RegionHit] = [:]
            for (local, latin, lat, lon) in rows {
                let hit = RegionHit(lat: lat, lon: lon, latin: latin.uppercased())
                map[normalize(local)] = hit
                map[normalize(latin)] = hit
            }
            table[code] = map
        }
        add("JP", japan)
        add("US", usa)
        add("KR", korea)
        add("CN", china)
        add("GB", uk)
        add("CA", canada)
        add("AU", australia)
        return table
    }()

    // MARK: 表(中心のおおよその緯度経度)

    private static let japan: [(String, String, Double, Double)] = [
        ("北海道", "Hokkaido", 43.06, 141.35), ("青森県", "Aomori", 40.82, 140.74), ("岩手県", "Iwate", 39.70, 141.15),
        ("宮城県", "Miyagi", 38.27, 140.87), ("秋田県", "Akita", 39.72, 140.10), ("山形県", "Yamagata", 38.24, 140.36),
        ("福島県", "Fukushima", 37.75, 140.47), ("茨城県", "Ibaraki", 36.34, 140.45), ("栃木県", "Tochigi", 36.57, 139.88),
        ("群馬県", "Gunma", 36.39, 139.06), ("埼玉県", "Saitama", 35.86, 139.65), ("千葉県", "Chiba", 35.61, 140.12),
        ("東京都", "Tokyo", 35.68, 139.69), ("神奈川県", "Kanagawa", 35.45, 139.64), ("新潟県", "Niigata", 37.90, 139.02),
        ("富山県", "Toyama", 36.70, 137.21), ("石川県", "Ishikawa", 36.59, 136.63), ("福井県", "Fukui", 36.07, 136.22),
        ("山梨県", "Yamanashi", 35.66, 138.57), ("長野県", "Nagano", 36.65, 138.18), ("岐阜県", "Gifu", 35.39, 136.72),
        ("静岡県", "Shizuoka", 34.98, 138.38), ("愛知県", "Aichi", 35.18, 136.91), ("三重県", "Mie", 34.73, 136.51),
        ("滋賀県", "Shiga", 35.00, 135.87), ("京都府", "Kyoto", 35.02, 135.76), ("大阪府", "Osaka", 34.69, 135.52),
        ("兵庫県", "Hyogo", 34.69, 135.18), ("奈良県", "Nara", 34.69, 135.83), ("和歌山県", "Wakayama", 34.23, 135.17),
        ("鳥取県", "Tottori", 35.50, 134.24), ("島根県", "Shimane", 35.47, 133.05), ("岡山県", "Okayama", 34.66, 133.93),
        ("広島県", "Hiroshima", 34.40, 132.46), ("山口県", "Yamaguchi", 34.19, 131.47), ("徳島県", "Tokushima", 34.07, 134.56),
        ("香川県", "Kagawa", 34.34, 134.04), ("愛媛県", "Ehime", 33.84, 132.77), ("高知県", "Kochi", 33.56, 133.53),
        ("福岡県", "Fukuoka", 33.61, 130.42), ("佐賀県", "Saga", 33.25, 130.30), ("長崎県", "Nagasaki", 32.74, 129.87),
        ("熊本県", "Kumamoto", 32.79, 130.74), ("大分県", "Oita", 33.24, 131.61), ("宮崎県", "Miyazaki", 31.91, 131.42),
        ("鹿児島県", "Kagoshima", 31.56, 130.56), ("沖縄県", "Okinawa", 26.21, 127.68),
    ]

    private static let usa: [(String, String, Double, Double)] = [
        ("AL", "Alabama", 32.8, -86.8), ("AK", "Alaska", 61.2, -149.9), ("AZ", "Arizona", 33.4, -112.1), ("AR", "Arkansas", 34.8, -92.3),
        ("CA", "California", 34.1, -118.2), ("CO", "Colorado", 39.7, -105.0), ("CT", "Connecticut", 41.6, -72.7), ("DE", "Delaware", 39.2, -75.5),
        ("FL", "Florida", 28.5, -81.4), ("GA", "Georgia", 33.7, -84.4), ("HI", "Hawaii", 21.3, -157.9), ("ID", "Idaho", 43.6, -116.2),
        ("IL", "Illinois", 41.9, -87.6), ("IN", "Indiana", 39.8, -86.2), ("IA", "Iowa", 41.6, -93.6), ("KS", "Kansas", 38.5, -97.6),
        ("KY", "Kentucky", 38.2, -85.8), ("LA", "Louisiana", 30.0, -90.1), ("ME", "Maine", 44.3, -69.8), ("MD", "Maryland", 39.3, -76.6),
        ("MA", "Massachusetts", 42.4, -71.1), ("MI", "Michigan", 42.3, -83.0), ("MN", "Minnesota", 45.0, -93.3), ("MS", "Mississippi", 32.3, -90.2),
        ("MO", "Missouri", 38.6, -90.2), ("MT", "Montana", 46.9, -110.4), ("NE", "Nebraska", 41.3, -96.0), ("NV", "Nevada", 36.2, -115.1),
        ("NH", "New Hampshire", 43.2, -71.5), ("NJ", "New Jersey", 40.7, -74.2), ("NM", "New Mexico", 35.1, -106.6), ("NY", "New York", 40.7, -74.0),
        ("NC", "North Carolina", 35.2, -80.8), ("ND", "North Dakota", 46.9, -96.8), ("OH", "Ohio", 40.0, -83.0), ("OK", "Oklahoma", 35.5, -97.5),
        ("OR", "Oregon", 45.5, -122.7), ("PA", "Pennsylvania", 40.0, -75.2), ("RI", "Rhode Island", 41.8, -71.4), ("SC", "South Carolina", 34.0, -81.0),
        ("SD", "South Dakota", 44.4, -100.3), ("TN", "Tennessee", 36.2, -86.8), ("TX", "Texas", 30.3, -97.7), ("UT", "Utah", 40.8, -111.9),
        ("VT", "Vermont", 44.5, -73.2), ("VA", "Virginia", 37.5, -77.4), ("WA", "Washington", 47.6, -122.3), ("WV", "West Virginia", 38.4, -81.6),
        ("WI", "Wisconsin", 43.1, -89.4), ("WY", "Wyoming", 41.1, -104.8), ("DC", "District of Columbia", 38.9, -77.0),
    ]

    private static let korea: [(String, String, Double, Double)] = [
        ("서울특별시", "Seoul", 37.57, 126.98), ("부산광역시", "Busan", 35.18, 129.08), ("인천광역시", "Incheon", 37.46, 126.71),
        ("대구광역시", "Daegu", 35.87, 128.60), ("경기도", "Gyeonggi-do", 37.27, 127.01), ("제주특별자치도", "Jeju", 33.50, 126.53),
        ("ソウル特別市", "Seoul Special City", 37.57, 126.98),
    ]

    private static let china: [(String, String, Double, Double)] = [
        ("北京市", "Beijing", 39.90, 116.40), ("上海市", "Shanghai", 31.23, 121.47), ("广东省", "Guangdong", 23.13, 113.26),
        ("香港", "Hong Kong", 22.32, 114.17), ("四川省", "Sichuan", 30.66, 104.07), ("浙江省", "Zhejiang", 30.27, 120.15),
    ]

    private static let uk: [(String, String, Double, Double)] = [
        ("England", "England", 51.51, -0.13), ("Scotland", "Scotland", 55.95, -3.19), ("Wales", "Wales", 51.48, -3.18),
        ("Northern Ireland", "Northern Ireland", 54.60, -5.93),
    ]

    private static let canada: [(String, String, Double, Double)] = [
        ("ON", "Ontario", 43.65, -79.38), ("QC", "Quebec", 45.50, -73.57), ("BC", "British Columbia", 49.28, -123.12),
        ("AB", "Alberta", 51.05, -114.07),
    ]

    private static let australia: [(String, String, Double, Double)] = [
        ("NSW", "New South Wales", -33.87, 151.21), ("VIC", "Victoria", -37.81, 144.96), ("QLD", "Queensland", -27.47, 153.03),
        ("WA", "Western Australia", -31.95, 115.86), ("SA", "South Australia", -34.93, 138.60),
    ]

    /// 国の中心(人の多い所寄り)
    static let countryCenter: [String: (Double, Double)] = [
        "JP": (35.7, 139.7), "US": (39.8, -98.6), "KR": (37.0, 127.5), "CN": (34.0, 108.0), "TW": (24.0, 121.0), "HK": (22.3, 114.2),
        "TH": (13.8, 100.5), "VN": (16.0, 107.0), "PH": (14.6, 121.0), "ID": (-6.2, 106.8), "MY": (3.1, 101.7), "SG": (1.35, 103.8),
        "IN": (21.0, 78.0), "AU": (-33.9, 151.2), "NZ": (-41.3, 174.8), "GB": (52.5, -1.5), "IE": (53.3, -6.3), "FR": (46.5, 2.5),
        "DE": (51.0, 10.0), "IT": (42.5, 12.5), "ES": (40.4, -3.7), "PT": (38.7, -9.1), "NL": (52.3, 4.9), "BE": (50.8, 4.4),
        "CH": (46.8, 8.2), "AT": (48.2, 16.4), "SE": (59.3, 18.1), "NO": (59.9, 10.8), "DK": (55.7, 12.6), "FI": (60.2, 24.9),
        "IS": (64.1, -21.9), "PL": (52.2, 21.0), "CZ": (50.1, 14.4), "HU": (47.5, 19.0), "GR": (38.0, 23.7), "TR": (41.0, 29.0),
        "RU": (55.8, 37.6), "UA": (50.4, 30.5), "RO": (44.4, 26.1), "IL": (32.1, 34.8), "AE": (25.2, 55.3), "SA": (24.7, 46.7),
        "EG": (30.0, 31.2), "MA": (33.6, -7.6), "ZA": (-26.2, 28.0), "KE": (-1.3, 36.8), "NG": (6.5, 3.4), "CA": (45.4, -75.7),
        "MX": (19.4, -99.1), "BR": (-23.5, -46.6), "AR": (-34.6, -58.4), "CL": (-33.4, -70.6), "PE": (-12.0, -77.0), "CO": (4.7, -74.1),
        "CU": (23.1, -82.4), "PK": (24.9, 67.0), "BD": (23.8, 90.4), "NP": (27.7, 85.3), "LK": (6.9, 79.9), "MN": (47.9, 106.9),
        "KZ": (43.2, 76.9), "QA": (25.3, 51.5), "LU": (49.6, 6.1), "EE": (59.4, 24.8), "LV": (56.9, 24.1), "LT": (54.7, 25.3),
        "HR": (45.8, 16.0), "RS": (44.8, 20.5), "BG": (42.7, 23.3), "SK": (48.1, 17.1), "SI": (46.1, 14.5), "KH": (11.6, 104.9),
        "MM": (16.9, 96.2), "LA": (17.97, 102.6), "MO": (22.2, 113.5), "GU": (13.4, 144.8),
    ]

    /// 英字の国名(カードの「国 ・ 緯度 経度」用)
    static let englishCountry: [String: String] = [
        "JP": "Japan", "US": "USA", "KR": "Korea", "CN": "China", "TW": "Taiwan", "HK": "Hong Kong", "TH": "Thailand", "VN": "Vietnam",
        "PH": "Philippines", "ID": "Indonesia", "MY": "Malaysia", "SG": "Singapore", "IN": "India", "AU": "Australia", "NZ": "New Zealand",
        "GB": "UK", "IE": "Ireland", "FR": "France", "DE": "Germany", "IT": "Italy", "ES": "Spain", "PT": "Portugal", "NL": "Netherlands",
        "BE": "Belgium", "CH": "Switzerland", "AT": "Austria", "SE": "Sweden", "NO": "Norway", "DK": "Denmark", "FI": "Finland",
        "IS": "Iceland", "PL": "Poland", "CZ": "Czechia", "HU": "Hungary", "GR": "Greece", "TR": "Türkiye", "RU": "Russia", "UA": "Ukraine",
        "IL": "Israel", "AE": "UAE", "SA": "Saudi Arabia", "EG": "Egypt", "MA": "Morocco", "ZA": "South Africa", "KE": "Kenya",
        "NG": "Nigeria", "CA": "Canada", "MX": "Mexico", "BR": "Brazil", "AR": "Argentina", "CL": "Chile", "PE": "Peru", "CO": "Colombia",
    ]

    // MARK: 地球儀の点

    /// 陸の点(約2,500)・海の点(約1,900)。緯度経度(度)
    static let land: [GeoPoint] = decode(GlobeDotsData.land)
    static let ocean: [GeoPoint] = decode(GlobeDotsData.ocean)

    static func decode(_ base64: String) -> [GeoPoint] {
        guard let data = Data(base64Encoded: base64) else { return [] }
        let bytes = [UInt8](data)
        var points: [GeoPoint] = []
        points.reserveCapacity(bytes.count / 4)
        var i = 0
        while i + 3 < bytes.count {
            let la = Int16(bitPattern: UInt16(bytes[i]) | UInt16(bytes[i + 1]) << 8)
            let lo = Int16(bitPattern: UInt16(bytes[i + 2]) | UInt16(bytes[i + 3]) << 8)
            points.append(GeoPoint(lat: Double(la) / 10, lon: Double(lo) / 10))
            i += 4
        }
        return points
    }

    /// 2点の角度の距離(度)
    static func angularDistance(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let l1 = a.lat * .pi / 180, l2 = b.lat * .pi / 180, dl = (b.lon - a.lon) * .pi / 180
        let c = sin(l1) * sin(l2) + cos(l1) * cos(l2) * cos(dl)
        return acos(min(1, max(-1, c))) * 180 / .pi
    }
}

/// 地球儀の向き(まん中の緯度・経度)と拡大。正射図法で描く(見本の prj と同じ式)
struct GlobeView2D: Equatable {
    var lon: Double = 130
    var lat: Double = 22
    var zoom: Double = 1

    static let latRange: ClosedRange<Double> = -62...70

    /// 画面上の位置(中心からのずれ)と、手前向きの度合い v(0 以下は裏側)
    func project(_ p: GeoPoint, radius: Double) -> (x: Double, y: Double, v: Double) {
        let l = p.lat * .pi / 180, o = (p.lon - lon) * .pi / 180, l0 = lat * .pi / 180
        let v = sin(l0) * sin(l) + cos(l0) * cos(l) * cos(o)
        let x = radius * cos(l) * sin(o)
        let y = -radius * (cos(l0) * sin(l) - sin(l0) * cos(l) * cos(o))
        return (x, y, v)
    }

    mutating func turn(dLon: Double, dLat: Double) {
        lon = ((lon + dLon + 540).truncatingRemainder(dividingBy: 360)) - 180
        lat = min(Self.latRange.upperBound, max(Self.latRange.lowerBound, lat + dLat))
    }

    var center: GeoPoint { GeoPoint(lat: lat, lon: lon) }
}
