"""Later 動画のルック「RETRO-8」(iPhone 8 の頃のビデオ風)  --  numpy / PIL / ffmpeg
写真の「チェキ」とは別の質感:
  チェキ = ふわっと・やわらかい・クリーム色
  動画   = パキッと・ざらざら・ちょっと安っぽい 2017年のスマホビデオ
共通点(世界観):暖かい色、白飛び、暗い所のにじみ、橙の日付スタンプ
"""
import numpy as np, subprocess, sys, os, math
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter, zoom as ndzoom

# ---------- パラメータ(Swift / Metal にそのまま渡せる値) ----------
V = dict(
    W=360, H=480, FPS=30,
    res_scale=0.80,          # 一度 80% に落として戻す(解像感)
    sharpen_sigma=1.0, sharpen_amt=0.85,   # iPhone8 の 'かけすぎシャープ' (ふちに白いふち)
    gamma=0.93, contrast=1.08, sat=1.10,
    lift=(0.030, 0.032, 0.040),            # 黒は少しだけ持ち上げ
    hi_gain=1.07, hi_clip=1.0,             # 白は、飛ばす
    warm=(1.035, 1.0, 0.955),              # 全体を暖色に
    luma_noise=0.020, luma_noise_dark=0.030,
    chroma_blotch=0.030, chroma_cell=7,    # 暗い所の 色のまだら
    ghost=0.14,                            # 暗い所の 残像(時間方向ノイズ除去のあと)
    band_levels=44, band_below=0.34,       # 暗い所の 段々(バンディング)
    ae_amp=0.045, ae_period=3.3,           # 露出が ゆっくり息をする
    rs_k=0.9,                              # ローリングシャッターのかたむき
    vig=0.16,
    stamp=True,
    crf=31, maxrate='1100k',
)

def srgb_gamma(a, g): return np.clip(a, 0, 1) ** g

def seven(ch):
    return {'0':'abcdef','1':'bc','2':'abdeg','3':'abcdg','4':'bcfg','5':'acdfg','6':'acdefg','7':'abc','8':'abcdefg','9':'abcdfg'}.get(ch, '')

def stamp_layer(text, W, H, scale=1.0):
    """右下の橙の 7セグ日付スタンプ('26 11 05)。グロー付き RGBA(float)"""
    S = 3
    lay = Image.new('L', (W * S, H * S), 0)
    d = ImageDraw.Draw(lay)
    dw, dh, t = 8 * scale * S, 15 * scale * S, 2.0 * scale * S
    gap = 4.0 * scale * S
    total = sum((dw * 0.55 + gap) if c in " '" else (dw + gap) for c in text)
    x = W * S - 18 * S - total
    y = H * S - 22 * S - dh
    for c in text:
        if c == "'":
            d.polygon([(x + 3 * S, y), (x + 5 * S, y), (x + 3.4 * S, y + 6 * S), (x + 2 * S, y + 6 * S)], fill=255); x += dw * 0.55 + gap; continue
        if c == ' ':
            x += dw * 0.55 + gap; continue
        def hseg(sy):
            yy = y + sy * dh
            d.polygon([(x + t * .7, yy), (x + t * 1.1, yy - t / 2), (x + dw - t * 1.1, yy - t / 2), (x + dw - t * .7, yy), (x + dw - t * 1.1, yy + t / 2), (x + t * 1.1, yy + t / 2)], fill=255)
        def vseg(sx, sy):
            xx = x + sx * dw; y0 = y + sy * dh + t * .7; y1 = y + (sy + .5) * dh - t * .7
            d.polygon([(xx, y0), (xx + t / 2, y0 + t / 2), (xx + t / 2, y1 - t / 2), (xx, y1), (xx - t / 2, y1 - t / 2), (xx - t / 2, y0 + t / 2)], fill=255)
        m = {'a': lambda: hseg(0), 'g': lambda: hseg(.5), 'd': lambda: hseg(1), 'f': lambda: vseg(0, 0), 'b': lambda: vseg(1, 0), 'e': lambda: vseg(0, .5), 'c': lambda: vseg(1, .5)}
        for k in seven(c): m[k]()
        x += dw + gap
    lay = lay.resize((W, H), Image.LANCZOS)
    core = np.asarray(lay).astype(np.float32) / 255
    glow = gaussian_filter(core, 2.2) * 0.9 + gaussian_filter(core, 6) * 0.5
    return core, np.clip(glow, 0, 1)

def make_path(T, fps, seed, amp=5.0, push=0.10, pan=(0, 0)):
    rng = np.random.default_rng(seed)
    n = int(T * fps)
    ts = np.arange(n) / fps
    def wob(a):
        ph = rng.uniform(0, 6.28, 4); fr = np.array([.55, 1.3, 2.7, 5.1]) * rng.uniform(.8, 1.2)
        w = np.array([1, .6, .35, .18])
        return a * sum(w[i] * np.sin(ts * fr[i] * 2 * math.pi / 3 + ph[i]) for i in range(4)) / 2.1
    dx = wob(amp) + pan[0] * ts / T; dy = wob(amp * .8) + pan[1] * ts / T
    rot = wob(0.35)
    z = 1.0 + push * (ts / T)
    return ts, dx, dy, rot, z

def render(src_path, out_mp4, T=6.0, seed=3, flash=False, rain=False, clean=False, date="'26 11 05", pan=(0, 0), push=.10, amp=5.0):
    P = V
    W, H = P['W'], P['H']
    src = Image.open(src_path).convert('RGB')
    sw, sh = src.size
    big = src.resize((int(sw * 1.5), int(sh * 1.5)), Image.LANCZOS)
    bw, bh = big.size
    ts, dx, dy, rot, zz = make_path(T, P['FPS'], seed, amp=amp, push=push, pan=pan)
    n = len(ts)
    rng = np.random.default_rng(seed + 100)
    core, glow = stamp_layer(date, W, H)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    ux = (xx - W / 2) / (W / 2); uy = (yy - H / 2) / (H / 2)
    vig = 1 - P['vig'] * np.clip((np.sqrt(ux ** 2 + uy ** 2) - .5) / .9, 0, 1) ** 1.4
    cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(P['FPS']), '-i', '-',
           '-c:v', 'libx264', '-preset', 'slow', '-profile:v', 'main', '-pix_fmt', 'yuv420p', '-an', '-movflags', '+faststart']
    if clean:
        cmd += ['-crf', '20']
    else:
        cmd += ['-crf', str(P['crf']), '-maxrate', P['maxrate'], '-bufsize', '1500k', '-x264-params', 'keyint=30:bframes=0:aq-mode=0:deblock=-2,-2']
    cmd += [out_mp4]
    pr = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    prev = None
    rain_drops = None
    if rain:
        rain_drops = np.stack([rng.uniform(0, W, 140), rng.uniform(0, H, 140), rng.uniform(260, 520, 140), rng.uniform(8, 20, 140)], 1)
    vx_prev = 0
    for i in range(n):
        s = (W / 2) / 1.0
        cw = bw * 0.78 / zz[i]; sc = cw / W
        th = math.radians(rot[i]); c, sn = math.cos(th) * sc, math.sin(th) * sc
        cx = bw / 2 + dx[i] * 1.5 + 0 * 1; cy = bh / 2 + dy[i] * 1.5
        a_ = c; b_ = -sn; d_ = sn; e_ = c
        c0 = cx - (W / 2) * a_ - (H / 2) * b_; f0 = cy - (W / 2) * d_ - (H / 2) * e_
        fr = big.transform((W, H), Image.AFFINE, (a_, b_, c0, d_, e_, f0), resample=Image.BICUBIC)
        a = np.asarray(fr).astype(np.float32) / 255.0
        if clean:
            pr.stdin.write((np.clip(a, 0, 1) * 255 + .5).astype(np.uint8).tobytes()); continue
        # 速度(ローリングシャッター)
        vx = (dx[i] - (dx[i - 1] if i else dx[i])) * P['FPS']
        # 解像感を落とす
        if P['res_scale'] < 1:
            sm = np.stack([ndzoom(a[..., k], P['res_scale'], order=1) for k in range(3)], -1)
            a = np.stack([ndzoom(sm[..., k], (H / sm.shape[0], W / sm.shape[1]), order=1) for k in range(3)], -1)[:H, :W]
        # 夜のフラッシュ
        if flash:
            fl = np.exp(-(ux ** 2 + uy ** 2) / 1.0); a = np.clip(a * (0.6 + 0.8 * fl[..., None]), 0, 1)
        # 雨
        if rain:
            lay = np.zeros((H, W), np.float32)
            for (rx, ry, sp, ln) in rain_drops:
                y0 = (ry + sp * ts[i]) % (H + 40) - 20; x0 = (rx - 40 * ts[i]) % W
                for k in range(int(ln)):
                    px = int(x0 - k * .35); py = int(y0 - k)
                    if 0 <= px < W and 0 <= py < H: lay[py, px] = max(lay[py, px], .5 * (1 - k / ln))
            a = np.clip(a + gaussian_filter(lay, .6)[..., None] * 0.9, 0, 1)
        # 露出の呼吸
        ae = 1 + P['ae_amp'] * math.sin(2 * math.pi * ts[i] / P['ae_period']) + (0.03 if 1.6 < ts[i] < 1.75 else 0)
        a = np.clip(a * ae, 0, 1)
        # シャープ(かけすぎ)
        bl = np.stack([gaussian_filter(a[..., k], P['sharpen_sigma']) for k in range(3)], -1)
        a = np.clip(a + (a - bl) * P['sharpen_amt'], 0, 1.2)
        # 色・トーン
        a = np.clip(a, 0, 1) ** P['gamma']
        a = 0.5 + (a - 0.5) * P['contrast']
        for k in range(3):
            a[..., k] = P['lift'][k] + np.clip(a[..., k], 0, 1.3) * (1 - P['lift'][k])
        a = a * np.array(P['warm'])
        lum = a.mean(-1, keepdims=True)
        a = lum + (a - lum) * P['sat']
        hi = np.clip((lum - 0.65) / 0.35, 0, 1)
        a = a * (1 + (P['hi_gain'] - 1) * hi)
        a = np.clip(a, 0, 1)
        # 暗い所の まだら色ノイズ
        lum = a.mean(-1)
        dk = (1 - np.clip(lum / 0.55, 0, 1))
        cell = P['chroma_cell']
        cn = rng.standard_normal((H // cell + 2, W // cell + 2, 3)).astype(np.float32)
        cn = np.stack([ndzoom(cn[..., k], cell, order=1)[:H, :W] for k in range(3)], -1)
        cn = cn - cn.mean(-1, keepdims=True)
        a = a + cn * P['chroma_blotch'] * dk[..., None]
        # 粒(明るさ)
        gn = rng.standard_normal((H, W)).astype(np.float32)
        gn = gaussian_filter(gn, 0.55); gn /= gn.std()
        a = a + (P['luma_noise'] + P['luma_noise_dark'] * dk)[..., None] * gn[..., None]
        # 残像
        if prev is not None:
            g = P['ghost'] * (0.35 + 0.65 * dk)[..., None]
            a = a * (1 - g) + prev * g
        prev = a.copy()
        # バンディング
        q = P['band_levels']; m = (lum < P['band_below'])[..., None]
        a = np.where(m, np.round(a * q) / q, a)
        # ローリングシャッター(横にかたむく)
        sk = (vx * P['rs_k'] * 0.012) * ((yy[:, 0] / H) - 0.5) * H * 0.5
        idx = np.clip((xx + sk[:, None]).astype(np.int32), 0, W - 1)
        a = np.take_along_axis(a, idx[..., None].repeat(3, 2), axis=1)
        # ビネット
        a = a * vig[..., None]
        # 日付スタンプ(橙)
        if P['stamp']:
            col = np.array([1.0, .54, .16], np.float32)
            a = np.clip(a + glow[..., None] * col * 0.55, 0, 1)
            a = a * (1 - core[..., None] * .92) + core[..., None] * np.array([1.0, .62, .22], np.float32) * .92
        pr.stdin.write((np.clip(a, 0, 1) * 255 + .5).astype(np.uint8).tobytes())
    pr.stdin.close(); pr.wait()

if __name__ == '__main__':
    os.makedirs('vout', exist_ok=True)
    jobs = {
        'street': dict(src='src/street.jpg', T=6.0, seed=3, pan=(18, 0), push=.12),
        'rain': dict(src='src/rain.jpg', T=5.0, seed=8, rain=True, push=.08, amp=6.0),
        'sea': dict(src='src/sea.jpg', T=5.0, seed=21, pan=(-14, 0), push=.06),
    }
    which = sys.argv[1:] or list(jobs)
    for k in which:
        j = dict(jobs[k]); src = j.pop('src')
        render(src, f'vout/{k}.mp4', **j)
        render(src, f'vout/{k}_clean.mp4', clean=True, **{x: y for x, y in j.items() if x not in ('rain',)})
        print(k, os.path.getsize(f'vout/{k}.mp4'))
