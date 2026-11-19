import SwiftUI

// v98 ② Trip チャット(まだ だれも いない)T19 ・ ③ メンバーの シート T20 で 使う 部品。
// 座席表(4列 × 2段・まんなかに 通路)・ 送ると こう 見える(パスの 形の プレビュー)・ BOARDING の 画面。

struct TripSeatPerson: Identifiable {
    let id: String
    let name: String
    let image: UIImage?
}

/// 飛行機の 座席。入った 人 = 写真の 丸 + 名前(ライムの ふち)・ 空席 = 点線の `+` + `B1`
struct TripSeatMap: View {
    let people: [TripSeatPerson]
    var capacity = 8
    var small = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var seats: Int { max(capacity, 8) }

    var body: some View {
        let rows = (seats + 3) / 4
        ZStack(alignment: .top) {
            Text("FRONT").font(LF.mono(8)).tracking(2.4).foregroundStyle(Color(hex: "4A4A50")).padding(.top, 10)
            VStack(spacing: 8) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 8) {
                        seat(r * 4); seat(r * 4 + 1)
                        Color.clear.frame(width: 22, height: 1)
                        seat(r * 4 + 2); seat(r * 4 + 3)
                    }
                }
            }
            .padding(.top, small ? 28 : 34).padding(.horizontal, small ? 12 : 14).padding(.bottom, small ? 12 : 14)
        }
        .background(UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 18, bottomTrailingRadius: 18, topTrailingRadius: 30, style: .continuous).fill(Color(hex: "121214")))
        .overlay(UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 18, bottomTrailingRadius: 18, topTrailingRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        .onAppear { shown = true }
    }

    private func code(_ i: Int) -> String { "\(Character(UnicodeScalar(65 + i / 4)!))\(i % 4 + 1)" }

    @ViewBuilder private func seat(_ i: Int) -> some View {
        let d: CGFloat = small ? 32 : 38
        let p = i < people.count ? people[i] : nil
        let on = p != nil
        VStack(spacing: 4) {
            ZStack {
                if let p {
                    if let img = p.image {
                        Image(uiImage: img).resizable().scaledToFill().frame(width: d, height: d).clipShape(Circle())
                    } else {
                        Circle().fill(Color(hex: "C8F25A")).frame(width: d, height: d)
                            .overlay(Text(String(p.name.prefix(1))).font(LF.inter(800, d * 0.4)).foregroundStyle(Color(hex: "111111")))
                    }
                } else {
                    Circle().strokeBorder(Color(hex: "C8F25A").opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).frame(width: d, height: d)
                        .overlay(Image(systemName: "plus").font(.system(size: 13, weight: .regular)).foregroundStyle(Color(hex: "C8F25A")))
                }
            }
            Text(p?.name ?? code(i)).font(LF.mono(9.5)).tracking(0.8).lineLimit(1).frame(maxWidth: 60)
                .foregroundStyle(on ? Color(hex: "C8F25A") : Color(hex: "6E6E75"))
        }
        .padding(.top, 8).padding(.bottom, 6).frame(maxWidth: .infinity)
        .background(UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 14, style: .continuous)
            .fill(on ? Color(hex: "C8F25A").opacity(0.1) : Color(hex: "19191C")))
        .overlay(UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 14, style: .continuous)
            .strokeBorder(on ? Color(hex: "C8F25A").opacity(0.5) : .white.opacity(0.06), lineWidth: 1.5))
        .opacity(shown || reduceMotion ? 1 : 0).offset(y: shown || reduceMotion ? 0 : 10)
        .animation(reduceMotion ? nil : .timingCurve(0.2, 0.9, 0.25, 1, duration: 0.4).delay(Double(i / 4) * 0.045 + Double(i % 4) * 0.045), value: shown)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(p.map { "\($0.name) が のって います" } ?? "あいている 席 \(code(i))")
    }
}

/// 「送ると、こう 見える」:メッセージの 吹き出し。リンクの プレビュー = パスの 形
struct TripInvitePreview: View {
    let name: String
    let date: String
    let key: String
    let cover: UIImage?
    let me: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("送ると、こう 見える").font(LF.mono(9.5)).tracking(1.7).foregroundStyle(Color(hex: "6E6E75"))
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Group {
                        if let cover { Image(uiImage: cover).resizable().scaledToFill() }
                        else { Color(hex: "2A2A2E").overlay(HV72HashShape().fill(Color(hex: "C8F25A")).frame(width: 46, height: 46)) }
                    }
                    .frame(width: 92, height: 118).clipped()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TRIP PASS").font(LF.mono(8)).tracking(1.6).foregroundStyle(Color(hex: "8A857B"))
                        Text(name).font(LF.inter(900, 19)).tracking(-0.4).lineLimit(2).minimumScaleFactor(0.7).foregroundStyle(Color(hex: "111111"))
                        Spacer(minLength: 0)
                        Text("\(date)\nKEY \(key.hasPrefix("#") ? key : "#" + key)").font(LF.mono(8.5)).lineSpacing(2).foregroundStyle(Color(hex: "5F5A52"))
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "F4F1EA"))
                    .overlay(alignment: .trailing) {
                        Canvas { c, s in
                            var y: CGFloat = 0, lime = true
                            while y < s.height { c.fill(Path(CGRect(x: 0, y: y, width: s.width, height: min(5, s.height - y))), with: .color(Color(hex: lime ? "C8F25A" : "5E8A12"))); y += 5; lime.toggle() }
                        }.frame(width: 6)
                    }
                }.frame(height: 118)
                Text(TripKeyLink.url(forKey: key).replacingOccurrences(of: "https://", with: ""))
                    .font(LF.inter(600, 11)).foregroundStyle(Color(hex: "C9C9CF")).padding(.horizontal, 12).padding(.vertical, 8)
            }
            .frame(width: 250)
            .background(Color(hex: "2A2A2E"))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, bottomTrailingRadius: 6, topTrailingRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 10, y: 10)
            .frame(maxWidth: .infinity, alignment: .trailing)
            Text("\(me) から Trip の 招待 ✈︎").font(LF.inter(600, 10.5)).foregroundStyle(Color(hex: "6E6E75")).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.top, 4)
    }
}

/// ライムの 大きな 「招待リンクを 送る」
struct TripSendButton: View {
    var sub = "LINE ・ メッセージ ・ AirDrop"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "paperplane").font(.system(size: 21, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("招待リンクを 送る").font(LF.inter(900, 16.5))
                    Text(sub).font(LF.inter(700, 11)).opacity(0.6)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color(hex: "111111")).padding(.horizontal, 20)
            .frame(maxWidth: .infinity).frame(height: 64)
            .background(Capsule().fill(Color(hex: "C8F25A")))
        }
        .buttonStyle(HVPress(scale: 0.98))
    }
}

/// 「QR を 見せる」+ 「#key(コピー)」の 2つ
struct TripTwoButtons: View {
    let key: String
    let onQR: () -> Void
    @State private var copied = false
    var body: some View {
        HStack(spacing: 8) {
            Button { Haptics.play(.tick); onQR() } label: {
                HStack(spacing: 8) { Image(systemName: "qrcode").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color(hex: "C8F25A")); Text("QR を 見せる").font(LF.inter(800, 13.5)) }
                    .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 50)
                    .background(Capsule().fill(Color(hex: "1C1C1F"))).overlay(Capsule().strokeBorder(.white.opacity(0.07), lineWidth: 1))
            }.buttonStyle(HVPress(scale: 0.97))
            Button {
                Haptics.play(.success); UIPasteboard.general.string = key; copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "C8F25A"))
                    Text(key.isEmpty ? "—" : (key.hasPrefix("#") ? key : "#" + key)).font(LF.mono(13.5)).lineLimit(1).minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 50)
                .background(Capsule().fill(Color(hex: "1C1C1F"))).overlay(Capsule().strokeBorder(.white.opacity(0.07), lineWidth: 1))
            }.buttonStyle(HVPress(scale: 0.97)).accessibilityLabel("KEY を コピー")
        }
    }
}

/// T19:だれも いない Trip の チャット(1人)
struct TripBoardingView: View {
    let name: String
    let date: String
    let key: String
    let cover: UIImage?
    let me: String
    let people: [TripSeatPerson]
    let onSend: () -> Void
    let onQR: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("BOARDING ・ \(people.count) / 8").font(LF.mono(10)).tracking(2.2).foregroundStyle(Color(hex: "C8F25A"))
                Text("なかまを のせよう").font(LF.inter(900, 28)).tracking(-0.8).foregroundStyle(.white).padding(.top, -6)
                Text("入ると、ここで 話せる ・ 1日 23枚を みんなで").font(LF.inter(600, 12.5)).foregroundStyle(Color(hex: "8C8C93")).padding(.top, -6)
                TripSeatMap(people: people)
                TripInvitePreview(name: name, date: date, key: key, cover: cover, me: me)
                TripSendButton(action: onSend)
                TripTwoButtons(key: key, onQR: onQR)
                Text("アプリが ない 人も、リンクで パスが 見えて そのまま 入れる")
                    .font(LF.inter(600, 11)).lineSpacing(3).multilineTextAlignment(.center).foregroundStyle(Color(hex: "5D5D63")).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 40)
        }
        .background(Color(hex: "0B0B0C"))
    }
}

extension TripPassData {
    /// 今ある グループから パス(あとで ひらく 時)
    init(group: LaterGroup, key: String, link: String) {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "MMM dd"
        let cal = Calendar.current
        let day = max(1, (cal.dateComponents([.day], from: cal.startOfDay(for: group.creationDate), to: cal.startOfDay(for: Date())).day ?? 0) + 1)
        self.init(name: group.name, sub: "", from: f.string(from: group.creationDate).uppercased(), to: f.string(from: Date()).uppercased(), days: day,
                  key: key, link: link,
                  cover: V64Images.image(key: "tg\(group.id)", data: group.iconImageData, maxPixel: 360),
                  members: group.members.map { V64Images.image(key: "tm\($0.id)", data: $0.profileImageData, maxPixel: 120) },
                  names: group.members.map(\.name))
    }
}
