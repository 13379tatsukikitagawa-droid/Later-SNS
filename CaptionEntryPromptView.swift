import SwiftUI

/// 撮影直後に表示するキャプション入力画面。写真そのものはここでも一切表示しない
/// (現像中は撮影者本人にも見せない、というアプリの前提を守るため)。
struct CaptionEntryPromptView: View {
    let onSubmit: (String?) -> Void

    @State private var captionText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBlack.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("撮影しました")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("写真は解禁時刻まで、あなた自身にも表示されません")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    TextField("一言(任意)", text: $captionText)
                        .textFieldStyle(CustomTextFieldStyle())
                        .padding(.horizontal, 32)
                        .focused($isFocused)

                    Button {
                        onSubmit(captionText)
                    } label: {
                        Text("現像に出す")
                            .font(.headline)
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brandGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("スキップ") {
                        onSubmit(nil)
                    }
                    .foregroundStyle(Color.brandGreen)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}
