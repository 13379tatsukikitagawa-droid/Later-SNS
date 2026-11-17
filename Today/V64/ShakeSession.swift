import SwiftUI
import CoreMotion
import MultipeerConnectivity

/// P12-D(v68):Shake の 本物の しくみ(Cloud Functions なし)。
/// ふった ことを `CMMotionManager`(50Hz)で 知る → `MultipeerConnectivity`(サービス `lattag-shake`)で ちかくの 端末と つながる →
/// ふったら すぐ 相手に 送る → うけとった 側が **自分の 時計で** 2秒 以内かを 決める → 確認カードで OK → 今ある 友だち申請の しくみで 送る。
/// ユーザー ID は **ふって 見つけた あとの 通信(暗号化)で だけ** 送る。広告に 出す のは 1回きりの 合言葉 だけ。
/// モードを とじたら **必ず** センサーと 通信を 止める(`stop()`)。
@MainActor @Observable
final class ShakeSession: NSObject {
    private(set) var phase: ShakeV68Phase = .idle
    private(set) var peer: ShakeV68Peer?
    private(set) var candidateCount = 0
    /// ローカルネットワークを ことわられた / 開始できない(→「QR で つながる」を 大きく 出す)
    private(set) var permissionProblem = false

    /// 画面に 出す 一言(トースト)
    var onToast: (String) -> Void = { _ in }
    /// つながった(友だちの 一覧を 読みなおす)
    var onConnected: () -> Void = {}

    static let serviceType = "lattag-shake"

    // 自分の ことがら
    @ObservationIgnored private var myName = ""
    @ObservationIgnored private var myRecordName = ""
    @ObservationIgnored private var myUsername = ""
    @ObservationIgnored private var myThumb: Data?
    @ObservationIgnored private var myTags: [String] = []
    @ObservationIgnored private var friends: Set<String> = []
    @ObservationIgnored private var blocked: Set<String> = []
    @ObservationIgnored private var declined: Set<String> = []

    // センサー ・ 通信
    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var detector = ShakeDetector()
    @ObservationIgnored private var peerID: MCPeerID?
    @ObservationIgnored private var session: MCSession?
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    @ObservationIgnored private let nonce = (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    @ObservationIgnored private var invited: Set<MCPeerID> = []

    // ふった ことの 記録(どれも 自分の 時計)
    @ObservationIgnored private var lastShake: Date?
    @ObservationIgnored private var heard: [(peer: ShakeV68Peer, id: String, at: Date)] = []
    @ObservationIgnored private var candidates: [(peer: ShakeV68Peer, id: String)] = []
    @ObservationIgnored private var iPressed = false
    @ObservationIgnored private var theyPressed = false
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var running = false

    // MARK: 開始 / 停止

    func start(myName: String, myRecordName: String, myUsername: String = "", myThumb: Data?, myTags: [String] = [],
               friends: Set<String>, blocked: Set<String>) {
        guard !running else { return }
        running = true
        self.myName = myName; self.myRecordName = myRecordName; self.myUsername = myUsername; self.myThumb = myThumb; self.myTags = myTags
        self.friends = friends; self.blocked = blocked
        phase = .idle; peer = nil; permissionProblem = false
        Task { declined = await FriendRequests.declinedByMe() }

        let id = MCPeerID(displayName: String(UUID().uuidString.prefix(8)))
        peerID = id
        let s = MCSession(peer: id, securityIdentity: nil, encryptionPreference: .required)
        s.delegate = self; session = s
        let adv = MCNearbyServiceAdvertiser(peer: id, discoveryInfo: ["n": nonce], serviceType: Self.serviceType)
        adv.delegate = self; adv.startAdvertisingPeer(); advertiser = adv
        let br = MCNearbyServiceBrowser(peer: id, serviceType: Self.serviceType)
        br.delegate = self; br.startBrowsingForPeers(); browser = br

        detector.reset()
        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 1.0 / 50
            motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let a = data?.acceleration else { return }
                let g = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
                if self.detector.feed(time: ProcessInfo.processInfo.systemUptime, g: g) { self.didShake() }
            }
        }
    }

    /// モードを とじたら 必ず 呼ぶ(センサー ・ 広告 ・ 検索 ・ 通信を ぜんぶ 止める)
    func stop() {
        running = false
        timeoutTask?.cancel(); timeoutTask = nil
        motion.stopAccelerometerUpdates()
        advertiser?.stopAdvertisingPeer(); advertiser = nil
        browser?.stopBrowsingForPeers(); browser = nil
        session?.disconnect(); session = nil
        invited.removeAll(); heard.removeAll(); candidates.removeAll()
        lastShake = nil; iPressed = false; theyPressed = false
        phase = .idle; peer = nil
    }

    /// DEBUG / 手動:ふった ことに する
    func simulateShake() { didShake() }

    // MARK: ふった

    private func didShake() {
        guard running, phase == .idle || phase == .none else { return }
        var history = (UserDefaults.standard.array(forKey: "shake.history.v1") as? [Date]) ?? []
        let now = Date()
        guard ShakeV68Rules.canShake(history: history, now: now) else { Haptics.play(.warn); onToast("ふりすぎです。すこし まって から"); return }
        history = ShakeV68Rules.pruned(history, now: now) + [now]
        UserDefaults.standard.set(history, forKey: "shake.history.v1")

        lastShake = now
        phase = .seek
        sendShake()            // ふったら すぐ 相手に 送る(相手が 自分の 時計で 判定する)
        evaluate()             // さきに 相手の「ふった」が 届いて いたら ここで ペアに なる
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(ShakeV68Rules.seekTimeout * 1e9))
            guard !Task.isCancelled, phase == .seek else { return }
            phase = .none
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if !Task.isCancelled, phase == .none { phase = .idle }
        }
    }

    private func sendShake() {
        var msg: [String: Any] = ["t": "shake", "id": myRecordName, "name": myName, "user": myUsername, "tags": myTags]
        if let myThumb { msg["thumb"] = myThumb.base64EncodedString() }
        send(msg)
    }

    private func send(_ payload: [String: Any]) {
        guard let session, !session.connectedPeers.isEmpty, let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    // MARK: ペアの 判定(うけとった 側の 時計で)

    private func received(_ payload: [String: Any]) {
        guard running, let t = payload["t"] as? String else { return }
        switch t {
        case "shake":
            guard let id = payload["id"] as? String, let name = payload["name"] as? String else { return }
            var thumb: UIImage?
            if let b = payload["thumb"] as? String, let d = Data(base64Encoded: b) { thumb = UIImage(data: d) }
            let p = ShakeV68Peer(name: name, handle: payload["user"] as? String ?? "", photo: thumb, tags: payload["tags"] as? [String] ?? [])
            heard.removeAll { $0.id == id }
            heard.append((p, id, Date()))
            evaluate()
        case "ok":
            guard let id = payload["id"] as? String, id == currentID else { return }
            theyPressed = true
            if iPressed { finish() }
        case "no":
            if (payload["id"] as? String) == currentID { Haptics.play(.soft); resetToIdle() }
        default: break
        }
    }

    private var currentID: String? { candidates.first?.id }

    private func evaluate() {
        guard phase == .seek, let mine = lastShake else { return }
        var found: [(peer: ShakeV68Peer, id: String)] = []
        for h in heard where ShakeV68Rules.isPair(myShake: mine, receivedAt: h.at) {
            switch ShakeV68Rules.verdict(for: h.id, me: myRecordName, friends: friends, blocked: blocked, declined: declined, cancelled: ShakeExclusions.cancelled) {
            case .show: found.append((h.peer, h.id))
            case .alreadyFriend: onToast("もう 友だち です")
            case .hidden: break
            }
        }
        guard !found.isEmpty else { return }
        timeoutTask?.cancel()
        candidates = Array(found.prefix(ShakeV68Rules.maxCandidates))
        candidateCount = candidates.count
        peer = candidates.first?.peer
        iPressed = false; theyPressed = false
        phase = .found
    }

    // MARK: 確認(ふたりとも「つながる」)

    func pick(_ index: Int) {
        guard phase == .found, candidates.indices.contains(index) else { return }
        candidates.swapAt(0, index); peer = candidates.first?.peer
    }

    /// 「つながる」を 押した:今ある 申請の しくみで 送り、相手にも 知らせる
    func connect() {
        guard phase == .found, let target = candidates.first else { return }
        iPressed = true
        phase = .wait
        send(["t": "ok", "id": myRecordName])
        Task { _ = await FriendRequests.send(to: target.id, toName: target.peer.name, myName: myName, myUsername: myUsername) }
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(ShakeV68Rules.confirmWindow * 1e9))
            guard !Task.isCancelled, phase == .wait else { return }
            onToast("時間切れ。ふつうの 申請として のこります")
            resetToIdle()
        }
        if theyPressed { finish() }
    }

    func notThem() { send(["t": "no", "id": myRecordName]); Haptics.play(.soft); resetToIdle() }

    private func finish() {
        guard phase == .wait || phase == .found else { return }
        timeoutTask?.cancel()
        phase = .done
        let name = myName
        Task { @MainActor in
            // 相手の 申請が とどく まで 少し 待って、重なった 申請を 成立させる
            for _ in 0..<5 {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if !(await FriendRequests.settleCrossed(myName: name, blocked: blocked)).isEmpty { onConnected(); return }
            }
            onConnected()
        }
    }

    private func resetToIdle() {
        timeoutTask?.cancel()
        candidates.removeAll(); candidateCount = 0; peer = nil; heard.removeAll(); lastShake = nil
        iPressed = false; theyPressed = false
        phase = .idle
    }
}

// MARK: - MultipeerConnectivity

extension ShakeSession: MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {}
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        Task { @MainActor in self.received(obj) }
    }
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in invitationHandler(self.running, self.session) }
    }
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in self.permissionProblem = true }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let theirs = info?["n"] ?? ""
        Task { @MainActor in
            guard self.running, let session = self.session, !self.invited.contains(peerID), !theirs.isEmpty else { return }
            // 合言葉が 小さい 方だけ 招待する(二重に つながらない)
            guard ShakeV68Rules.shouldInvite(myNonce: self.nonce, theirNonce: theirs) else { return }
            self.invited.insert(peerID)
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 20)
        }
    }
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) { Task { @MainActor in self.invited.remove(peerID) } }
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) { Task { @MainActor in self.permissionProblem = true } }
}
