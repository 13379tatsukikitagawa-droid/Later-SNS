import SwiftUI

// v89 C:今日の お題(毎日 かわる ・ その日は みんな 同じ)。index = (その年の 何日目 + 年 × 7) % 31(モックの q8Today)
enum DailyQuestion {
    static let ja = ["今日は、どんな日?", "今日の いちばんは?", "いま、なに してる?", "今日の 空は、どんな色?", "今日の 気分を ひとことで", "今日、ちょっと うれしかったこと", "いま、だれと いる?", "今日の 帰り道は?", "今日の ごはん、なに?", "今日、なにを 見つけた?", "今日の BGM は?", "いまの 机の 上は?", "今日、笑ったこと", "今日の 推しポイント", "いま いる場所の すきな所", "今日の「エモい」", "今日の「なんで?」", "今日 がんばったこと", "今日の おやつは?", "いまの 手元", "今日の くつ", "窓の 外は、どんな景色?", "今日の ちいさな 発見", "今日、言いたいことは?", "今日の 天気を ひとことで", "今日の 色は?", "今日の「はじめて」", "いま ほしいもの", "今日の あなたを 1枚で", "明日の 自分へ", "今日の「ちょうどいい」"]
    static let en = ["What's today like?", "Best part of today?", "What are you up to?", "What color is the sky?", "Your mood in a word", "Something that made you smile", "Who are you with?", "How was the walk home?", "What's for dinner?", "What did you find today?", "Today's BGM?", "What's on your desk?", "What made you laugh?", "Today's favorite thing", "Your favorite spot here", "Today's “feels”", "Today's “why?”", "What did you work on?", "Today's snack?", "What's in your hands?", "Today's shoes", "What's outside the window?", "A tiny discovery", "What do you want to say?", "Today's weather in a word", "Today's color?", "Today's “first”", "What do you want right now?", "You, in one shot", "A note to tomorrow's you", "Today's “just right”"]

    static func text(for date: Date = Date(), english: Bool = AppLanguage.isEnglish) -> String {
        let cal = Calendar.current
        let day = cal.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = cal.component(.year, from: date)
        let list = english ? en : ja
        return list[(day + year * 7) % list.count]
    }
}
