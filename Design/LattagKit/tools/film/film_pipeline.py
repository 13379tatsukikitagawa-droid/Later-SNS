"""Lattag の フィルムの 質感(v107)── LUT と 見本を 作る スクリプト
   実機(Core Image)と 同じ 順番で 処理する。ここの 数字が 正解。

   写真(チェキ):  縮小 1440 → 解像感を 少し 落とす → LUT(色) → にじみ(bloom) → ビネット → 粒子 → JPEG
   動画(iPhone 8):LUT(色) → うすい シャープ → 粒子(こまごとに ずらす) → H.264 1080p30

   使い方: python3 film_pipeline.py <出力フォルダ> [写真...]
"""
import sys, os, struct
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, map_coordinates

N = 33  # LUT の 大きさ(33×33×33)

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def rgb2hsv(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = a.max(-1); mn = a.min(-1); d = mx - mn
    h = np.zeros_like(mx); m = d > 1e-6
    rc = (mx == r) & m; gc = (mx == g) & m & ~rc; bc = m & ~rc & ~gc
    h[rc] = ((g - b)[rc] / d[rc]) % 6; h[gc] = (b - r)[gc] / d[gc] + 2; h[bc] = (r - g)[bc] / d[bc] + 4
    return h * 60.0, np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0), mx

def hsv2rgb(h, s, v):
    h = (h % 360) / 60.0; i = np.floor(h).astype(int) % 6; f = h - np.floor(h)
    p = v * (1 - s); q = v * (1 - f * s); t = v * (1 - (1 - f) * s)
    out = np.zeros(h.shape + (3,), np.float32)
    for k, (a, b, c) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
        m = i == k; out[m, 0] = a[m]; out[m, 1] = b[m]; out[m, 2] = c[m]
    return out

# ---------------- 色だけの 変換(LUT に 焼く) ----------------
def cheki_color(a):
    """Instax mini 風。ISO800 ・ 昼光 ・ 彩度 高め ・ コントラスト やや 強め ・ 明るい所は クリーム色に とぶ ・ 暗部は 少し 浮いて 青緑"""
    a = np.clip(a, 0, 1) ** 0.90                       # 少し 明るく(チェキは ふわっと 明るい)
    a = 0.5 + (a - 0.5) * 1.10                          # コントラスト やや 強め
    a = np.clip(a, 0, 1)
    out = np.empty_like(a)
    cream = (0.985, 0.970, 0.925); lift = (0.045, 0.050, 0.068)
    for c in range(3):
        x = a[..., c]
        x = np.where(x > .68, .68 + (x - .68) * (1 - .50 * smoothstep(.68, 1.0, x)), x)  # 白の 肩(とび方が やわらかい)
        x = x / (0.68 + 0.32 * 0.75) * cream[c]                                          # いちばん 明るい 所 = クリーム
        x = lift[c] + x * (1 - lift[c])                                                  # 黒は 少し 浮く(真っ黒に しない)
        out[..., c] = x
    a = np.clip(out, 0, 1)
    mid = 4 * a.mean(-1) * (1 - a.mean(-1))
    a[..., 0] += .015 * mid; a[..., 2] += .009 * mid; a[..., 1] -= .015 * mid       # 中間に ほんの少し マゼンタ
    lum = a.mean(-1)
    sh = (1 - smoothstep(0.0, 0.42, lum))[..., None]; hi = smoothstep(0.58, 1.0, lum)[..., None]
    a = a + sh * np.array([-0.010, 0.010, 0.024]) + hi * np.array([0.022, 0.010, -0.026])  # 影 = 青緑 ・ 明るい所 = 暖色
    a = np.clip(a, 0, 1)
    h, s, v = rgb2hsv(a)
    gm = np.exp(-((h - 120) / 38) ** 2); bm = np.exp(-((h - 230) / 35) ** 2)
    h = h - 8.0 * gm - 6.0 * bm                                                         # 緑 → 黄緑 ・ 青 → 青緑
    wm = np.exp(-((((h + 180) % 360) - 180 - 25) / 30) ** 2)
    s = np.clip(s * 1.15 * (1 - .10 * gm) * (1 + .10 * wm), 0, 1)                      # 彩度 高め(赤〜橙を 少し 濃く)
    return np.clip(hsv2rgb(h, s, v), 0, 1)

def retro8_color(a):
    """iPhone 8(2017)の 動画 風。HDR 動画 なし → 明るい所は ストンと とぶ ・ 影は 締まる ・ 少し 暖かい ・ 色は はっきり"""
    a = np.clip(a, 0, 1).copy()
    a[..., 0] *= 1.035; a[..., 2] *= 0.955                                              # 白の バランス 少し 暖かく
    a = np.clip(a, 0, 1)
    x = a
    x = np.clip((x - 0.025) / (1 - 0.025), 0, 1)                                         # 黒を 締める(浮かせない)
    x = x + 0.10 * np.sin(np.pi * (x - 0.5)) * (0.5 - np.abs(x - 0.5)) * 2              # S字(中間の コントラスト)
    x = np.where(x > 0.90, 0.90 + (x - 0.90) * 1.6, x)                                   # 明るい所は 早く とぶ(HDR なし)
    a = np.clip(x, 0, 1)
    h, s, v = rgb2hsv(a)
    gm = np.exp(-((h - 120) / 40) ** 2); rm = np.exp(-((((h + 180) % 360) - 180 - 10) / 28) ** 2); bm = np.exp(-((h - 215) / 30) ** 2)
    h = h - 4.0 * gm
    s = np.clip(s * 1.08 * (1 + .06 * rm) * (1 + .05 * bm), 0, 1)
    return np.clip(hsv2rgb(h, s, v), 0, 1)

def make_lut(fn):
    g = np.linspace(0, 1, N, dtype=np.float32)
    b, gg, r = np.meshgrid(g, g, g, indexing='ij')   # CIColorCube の 順番:r が いちばん 速く 変わる
    rgb = np.stack([r, gg, b], -1).reshape(-1, 1, 3)
    out = fn(rgb).reshape(-1, 3).astype(np.float32)
    return out

def save_lut(out, base, title):
    rgba = np.concatenate([out, np.ones((out.shape[0], 1), np.float32)], 1)
    rgba.astype('<f4').tofile(base + '.bin')                      # CIColorCube の cubeData(float32 RGBA ・ 33^3)
    with open(base + '.cube', 'w') as f:
        f.write(f'TITLE "{title}"\nLUT_3D_SIZE {N}\nDOMAIN_MIN 0 0 0\nDOMAIN_MAX 1 1 1\n')
        for v in out: f.write(f'{v[0]:.6f} {v[1]:.6f} {v[2]:.6f}\n')

def apply_lut(a, lut):
    """3次元 補間(CIColorCube と 同じ)"""
    L = lut.reshape(N, N, N, 3)  # [b][g][r]
    p = np.clip(a, 0, 1) * (N - 1)
    coords = [p[..., 2].ravel(), p[..., 1].ravel(), p[..., 0].ravel()]
    out = np.stack([map_coordinates(L[..., c], coords, order=1, mode='nearest') for c in range(3)], -1)
    return out.reshape(a.shape)

# ---------------- 粒子の タイル(1回 だけ 作って アプリに 入れる) ----------------
def make_grain(path, size=512, seed=7):
    rng = np.random.default_rng(seed)
    n = gaussian_filter(rng.standard_normal((size, size)).astype(np.float32), 0.6, mode='wrap')
    n = n / (n.std() + 1e-6)
    img = np.clip(0.5 + n * 0.18, 0, 1)                            # まん中 0.5(ソフトライトで 何も 変わらない 灰色)
    Image.fromarray((img * 255 + .5).astype(np.uint8), 'L').save(path)
    return img

def soft_light(base, blend):
    # CISoftLightBlendMode と 同じ 式(W3C)
    d = np.where(base <= .25, ((16 * base - 12) * base + 4) * base, np.sqrt(base))
    return np.where(blend <= .5, base - (1 - 2 * blend) * base * (1 - base), base + (2 * blend - 1) * (d - base))

# ---------------- 写真:チェキ(実機と 同じ 順番) ----------------
P = dict(long_edge=1440, soften=0.86, bloom_radius=8.0, bloom_intensity=0.22, vig_intensity=0.42, vig_radius=1.15, grain_alpha=0.55)

def cheki_photo(img, lut, grain, seed=1):
    w0, h0 = img.size
    s = P['long_edge'] / max(w0, h0)
    W, H = max(1, round(w0 * s)), max(1, round(h0 * s))
    # 1) 縮小 → 解像感を 少し 落とす(チェキは 約 12本/mm ・ 62mm × 12 × 2 ≒ 1500px)
    lo = img.resize((round(W * P['soften']), round(H * P['soften'])), Image.LANCZOS).resize((W, H), Image.BICUBIC)
    a = np.asarray(lo).astype(np.float32) / 255
    # 2) 色(LUT)
    a = apply_lut(a, lut)
    # 3) にじみ(CIBloom:ぼかした 物を 明るい 所に 足す)
    r = P['bloom_radius'] * W / 1440
    bl = np.stack([gaussian_filter(a[..., c], r) for c in range(3)], -1)
    a = np.clip(a + P['bloom_intensity'] * bl * smoothstep(0.55, 1.0, bl.max(-1))[..., None], 0, 1)
    # 4) ビネット(CIVignette)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2) / np.sqrt(2)
    a = a * (1 - P['vig_intensity'] * smoothstep(0.35, P['vig_radius'], d) ** 1.5)[..., None]
    # 5) 粒子(タイルを ならべて ソフトライト ・ ずらす 量は 写真ごとに)
    rng = np.random.default_rng(seed); ox, oy = rng.integers(0, grain.shape[0], 2)
    g = np.tile(np.roll(np.roll(grain, ox, 1), oy, 0), (H // grain.shape[0] + 1, W // grain.shape[1] + 1))[:H, :W]
    g = 0.5 + (g - 0.5) * P['grain_alpha']
    a = soft_light(np.clip(a, 0, 1), g[..., None])
    return Image.fromarray((np.clip(a, 0, 1) * 255 + .5).astype(np.uint8))

# ---------------- 動画の 1こま:iPhone 8 風 ----------------
V = dict(sharp=0.35, grain_alpha=0.30)
def retro8_frame(img, lut, grain, frame=0):
    a = np.asarray(img.convert('RGB')).astype(np.float32) / 255
    a = apply_lut(a, lut)
    # うすい シャープ(CISharpenLuminance ・ 古い 処理の 少し かたい 輪郭)
    y = a.mean(-1); bl = gaussian_filter(y, 1.2)
    a = np.clip(a + V['sharp'] * (y - bl)[..., None], 0, 1)
    H, W = y.shape; rng = np.random.default_rng(frame); ox, oy = rng.integers(0, grain.shape[0], 2)
    g = np.tile(np.roll(np.roll(grain, ox, 1), oy, 0), (H // grain.shape[0] + 1, W // grain.shape[1] + 1))[:H, :W]
    a = soft_light(a, (0.5 + (g - 0.5) * V['grain_alpha'])[..., None])
    return Image.fromarray((np.clip(a, 0, 1) * 255 + .5).astype(np.uint8))

def chart(W=720, H=960):
    """テスト用の 色見本(実機の Unit テストで 同じ 絵を 通して くらべる)"""
    a = np.zeros((H, W, 3), np.float32)
    x = np.linspace(0, 1, W)[None, :]
    a[:120] = x[..., None].repeat(120, 0)                                  # 灰色の 階段
    cols = [(.8, .2, .2), (.9, .55, .2), (.95, .85, .3), (.3, .7, .3), (.2, .6, .8), (.3, .3, .8), (.8, .3, .7), (.85, .7, .6), (.55, .45, .4), (.1, .1, .1), (.5, .5, .5), (.95, .95, .95)]
    for i, c in enumerate(cols):
        r, k = divmod(i, 4); a[140 + r * 180:300 + r * 180, 20 + k * 175:175 + k * 175] = c
    return Image.fromarray((a * 255).astype(np.uint8))

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    lc = make_lut(cheki_color); save_lut(lc, os.path.join(out, 'cheki_v2_lut33'), 'Lattag Cheki v2')
    lr = make_lut(retro8_color); save_lut(lr, os.path.join(out, 'retro8_lut33'), 'Lattag Retro8')
    gr = make_grain(os.path.join(out, 'grain_512.png'))
    c = chart(); c.save(os.path.join(out, 'chart_in.png'))
    Image.fromarray((apply_lut(np.asarray(c).astype(np.float32) / 255, lc) * 255 + .5).astype(np.uint8)).save(os.path.join(out, 'chart_cheki_lut_only.png'))
    Image.fromarray((apply_lut(np.asarray(c).astype(np.float32) / 255, lr) * 255 + .5).astype(np.uint8)).save(os.path.join(out, 'chart_retro8_lut_only.png'))
    for i, f in enumerate(sys.argv[2:]):
        im = Image.open(f).convert('RGB'); b = os.path.splitext(os.path.basename(f))[0]
        cheki_photo(im, lc, gr, seed=i + 1).save(os.path.join(out, f'{b}_cheki.jpg'), quality=88)
        retro8_frame(im, lr, gr, frame=i).save(os.path.join(out, f'{b}_retro8.jpg'), quality=88)
    print('ok')
