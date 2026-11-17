import SwiftUI
import PhotosUI
import UIKit

// P25(v81):アイコン = プロフィール写真。写真を えらぶ シート(丸の プレビュー ・ 大きさ ・ 撮る / ライブラリ / 消す ・ 最近の 写真 ・ これに する)。見本:F11 F12。
// 保存:丸く 切って 512 × 512 ・ JPEG 0.8(= `UserProfile.profileImageData`。今までの 保存 と 同じ 流れ)。写真が 無い 時は 名前の 1文字 + 色。

struct IconPickerV81Sheet: View {
    var name: String
    var current: UIImage?
    var recent: [(id: String, image: UIImage?, label: String?)]
    /// nil = 写真を 消す(1文字 + 色に もどる)
    var onSave: (Data?) -> Void
    var onClose: () -> Void

    @State private var preview: UIImage?
    @State private var zoom: Double = 1
    @State private var picked: PhotosPickerItem?
    @State private var showsCamera = false
    @State private var selected: String?
    @State private var removed = false

    init(name: String, current: UIImage?, recent: [(id: String, image: UIImage?, label: String?)], onSave: @escaping (Data?) -> Void, onClose: @escaping () -> Void) {
        self.name = name; self.current = current; self.recent = recent; self.onSave = onSave; self.onClose = onClose
        _preview = State(initialValue: current)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(.white.opacity(0.25)).frame(width: 40, height: 5).padding(.top, 10)
            HStack {
                Text("アイコン").font(LF.inter(900, 22)).foregroundStyle(.white)
                Spacer()
                Button { Haptics.play(.tick); onClose() } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(.white).frame(width: 40, height: 40).background(.white.opacity(0.12), in: Circle()) }.buttonStyle(.plain)
            }.padding(.horizontal, 18).padding(.top, 16)
            previewCircle.padding(.top, 18)
            HStack(spacing: 12) {
                Text("小").font(LF.inter(700, 12)).foregroundStyle(.white.opacity(0.45))
                Slider(value: $zoom, in: 1...2).tint(HV.lime)
                Text("大").font(LF.inter(700, 12)).foregroundStyle(.white.opacity(0.45))
            }.padding(.horizontal, 28).padding(.top, 12)
            HStack(spacing: 8) {
                actionButton("camera", "写真を 撮る", red: false) { showsCamera = true }
                PhotosPicker(selection: $picked, matching: .images, photoLibrary: .shared()) { actionLabel("photo", "ライブラリ", red: false) }
                actionButton("trash", "写真を 消す", red: true) { Haptics.play(.warn); preview = nil; removed = true; selected = nil }
            }.padding(.horizontal, 16).padding(.top, 16)
            Text("最近の 写真").font(LF.inter(700, 13)).foregroundStyle(.white.opacity(0.45)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.top, 18)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(recent.prefix(8), id: \.id) { r in
                    Button { Haptics.play(.sel); withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { preview = r.image; selected = r.id; removed = false; zoom = 1 } } label: {
                        ZStack(alignment: .bottomLeading) {
                            Color(hex: "2A2326")
                            if let im = r.image { Image(uiImage: im).resizable().scaledToFill() }
                            if let l = r.label { Text(l).font(LF.inter(800, 10)).foregroundStyle(.white).padding(6) }
                        }.aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(HV.lime, lineWidth: selected == r.id ? 3 : 0))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 16).padding(.top, 8)
            Spacer(minLength: 8)
            Button { Haptics.play(.success); onSave(removed ? nil : Self.circleData(preview, zoom: zoom)); onClose() } label: {
                Text("これに する").font(LF.inter(800, 18)).foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 54).background(HV.lime, in: Capsule())
            }.buttonStyle(HVPress(scale: 0.98)).padding(.horizontal, 16).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(hex: "141516"))
        .environment(\.colorScheme, .dark)
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task { if let d = try? await item.loadTransferable(type: Data.self), let im = UIImage(data: d) { await MainActor.run { preview = im; selected = nil; removed = false; zoom = 1; Haptics.play(.sel) } } }
        }
        .fullScreenCover(isPresented: $showsCamera) { IconCamera { im in showsCamera = false; if let im { preview = im; selected = nil; removed = false; zoom = 1 } }.ignoresSafeArea() }
    }

    private var previewCircle: some View {
        ZStack {
            Circle().fill(Color.black).frame(width: 188, height: 188)
            Group {
                if let preview { Image(uiImage: preview).resizable().scaledToFill().scaleEffect(zoom) }
                else { Circle().fill(LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay(Text(String(name.prefix(1))).font(LF.inter(900, 72)).foregroundStyle(.white)) }
            }.frame(width: 182, height: 182).clipShape(Circle())
            Circle().strokeBorder(HV.lime, lineWidth: 2).frame(width: 196, height: 196)
        }.frame(width: 200, height: 200)
    }

    private func actionButton(_ icon: String, _ t: String, red: Bool, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.click); a() } label: { actionLabel(icon, t, red: red) }.buttonStyle(HVPress(scale: 0.96))
    }
    private func actionLabel(_ icon: String, _ t: String, red: Bool) -> some View {
        VStack(spacing: 8) { Image(systemName: icon).font(.system(size: 20, weight: .semibold)); Text(t).font(LF.inter(800, 14)) }
            .foregroundStyle(red ? Color(hex: "FF6B6B") : .white).frame(maxWidth: .infinity).frame(height: 64).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// 丸く 切って 512 × 512(JPEG 0.8)
    static func circleData(_ img: UIImage?, zoom: Double) -> Data? {
        guard let img else { return nil }
        let size = CGSize(width: 512, height: 512)
        let r = UIGraphicsImageRenderer(size: size)
        let out = r.image { _ in
            let s = max(size.width / img.size.width, size.height / img.size.height) * CGFloat(zoom)
            let w = img.size.width * s, h = img.size.height * s
            img.draw(in: CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h))
        }
        return out.jpegData(compressionQuality: 0.8)
    }
}

/// 内カメラで その場で 撮る
private struct IconCamera: UIViewControllerRepresentable {
    var done: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        if p.sourceType == .camera { p.cameraDevice = .front }
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(done: done) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { done(info[.originalImage] as? UIImage) }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}
