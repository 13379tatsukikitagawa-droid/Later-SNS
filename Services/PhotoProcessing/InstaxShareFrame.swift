import UIKit

/// v107 §5:**外に 共有**(共有シート ・ 写真に 保存)の 時 だけ、焼いた 写真に Instax mini の 白い 枠を 1回 合成する。
/// アプリの 中の 表示は 枠が UI なので、写真には 焼かない。動画は 枠なし。
/// 54 × 86mm ・ 絵 46 × 62mm(上 4mm ・ 左右 4mm)・ 色 `#F6F3EA` ・ 日付は 枠の 下に 小さく(Space Mono ・ オレンジ)
enum InstaxShareFrame {
    static let cardMM = CGSize(width: 54, height: 86)
    static let pictureMM = CGRect(x: 4, y: 4, width: 46, height: 62)
    static let paper = UIColor(red: 246 / 255, green: 243 / 255, blue: 234 / 255, alpha: 1)

    /// `width` = 出力の 横の px(縦は 54:86 で きまる)
    static func compose(photo: UIImage, date: Date, width: CGFloat = 1080) -> UIImage {
        let k = width / cardMM.width                      // 1mm あたりの px
        let size = CGSize(width: width, height: (cardMM.height * k).rounded())
        let pic = CGRect(x: pictureMM.minX * k, y: pictureMM.minY * k, width: pictureMM.width * k, height: pictureMM.height * k).integral
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            paper.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            // 絵:枠に 合わせて 中央を 切りぬく(aspect fill)
            ctx.cgContext.saveGState(); ctx.cgContext.clip(to: pic)
            let s = max(pic.width / photo.size.width, pic.height / photo.size.height)
            let w = photo.size.width * s, h = photo.size.height * s
            photo.draw(in: CGRect(x: pic.midX - w / 2, y: pic.midY - h / 2, width: w, height: h))
            ctx.cgContext.restoreGState()
            // 日付(枠の 下)
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "''yy MM dd"
            let font = UIFont.monospacedDigitSystemFont(ofSize: 3.2 * k, weight: .bold)
            let text = NSAttributedString(string: f.string(from: date), attributes: [.font: font, .foregroundColor: UIColor(red: 1, green: 0.48, blue: 0.18, alpha: 1), .kern: 0.6 * k])
            let ts = text.size()
            text.draw(at: CGPoint(x: size.width - 4 * k - ts.width, y: pic.maxY + (size.height - pic.maxY - ts.height) / 2))
        }
    }
}
