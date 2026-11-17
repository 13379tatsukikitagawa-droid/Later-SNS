#!/usr/bin/env python3
"""モックの 見本画像 と シミュレータの スクリーンショット を 並べて 比べる。

使い方:
  xcrun simctl io booted screenshot /tmp/sim.png
  python3 Design/MockReference/tools/compare.py Design/MockReference/screens/D01_profile.png /tmp/sim.png /tmp/cmp_D01.png

出力(1枚の 画像): 左=モック / まんなか=実機 / 右=重ね合わせ(実機を 50%)+ 差分が 大きい 所を 赤で 表示
画像の 下に「ずれ量」(0〜100、小さいほど 近い)を 書く。
※ 画面幅が 390pt でない 機種でも、横幅を 390pt に そろえて 比べる(縦は 上 揃え)。
"""
import sys
from PIL import Image, ImageChops, ImageDraw

def norm(p, w=780):
    im = Image.open(p).convert('RGB')
    h = round(im.height * w / im.width)
    return im.resize((w, h), Image.LANCZOS)

def main(mock, sim, out):
    a, b = norm(mock), norm(sim)
    H = max(a.height, b.height)
    pad = lambda im: (lambda c: (c.paste(im, (0, 0)), c)[1])(Image.new('RGB', (im.width, H), 'white'))
    a, b = pad(a), pad(b)
    blend = Image.blend(a, b, .5)
    diff = ImageChops.difference(a, b).convert('L')
    mask = diff.point(lambda v: 255 if v > 60 else 0)
    red = Image.new('RGB', a.size, (255, 0, 0))
    over = Image.composite(red, blend, mask.point(lambda v: 110 if v else 0))
    score = round(sum(diff.histogram()[i]*i for i in range(256)) / (diff.width * diff.height) / 2.55, 1)
    W = a.width
    canvas = Image.new('RGB', (W * 3 + 40, H + 60), 'white')
    for i, im in enumerate([a, b, over]):
        canvas.paste(im, (i * (W + 20), 0))
    d = ImageDraw.Draw(canvas)
    d.text((10, H + 15), f'MOCK  |  DEVICE  |  OVERLAY(red = diff)   score {score} (0 = same)', fill='black')
    canvas.save(out)
    print(f'score {score}  -> {out}')

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print(__doc__); sys.exit(1)
    main(*sys.argv[1:])
