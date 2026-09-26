# 程式合成的遊戲音效（純標準函式庫）。重新產生全部：python tools/gen_sfx.py assets/audio/sfx
import math, random, struct, sys, wave, os

SR = 44100
random.seed(7)

def env_adsr(t, dur, attack, release):
    if t < attack:
        return t / attack
    if t > dur - release:
        return max(0.0, (dur - t) / release)
    return 1.0

def write(path, samples):
    peak = max(abs(s) for s in samples) or 1.0
    gain = 0.8 / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))

def shield_open():
    # 低往高滑的「嗡～」＋高頻閃爍，魔法屏障展開感
    dur = 0.5
    out, phase, phase2 = [], 0.0, 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        k = t / dur
        f = 220 + 440 * (k ** 0.6)
        f *= 1 + 0.01 * math.sin(2 * math.pi * 7 * t)
        phase += 2 * math.pi * f / SR
        phase2 += 2 * math.pi * 1760 / SR
        body = math.sin(phase) + 0.5 * math.sin(2 * phase) + 0.25 * math.sin(3 * phase)
        shimmer = 0.25 * math.sin(phase2) * (0.5 + 0.5 * math.sin(2 * math.pi * 18 * t)) * k
        out.append((body * 0.6 + shimmer) * env_adsr(t, dur, 0.04, 0.25))
    return out

def absorb():
    # 清脆的「叮」：不整數倍的泛音（像敲玻璃/水晶）快速衰減＋開頭一點點擊
    dur = 0.3
    partials = [(1320, 1.0, 14), (1320 * 2.76, 0.5, 22), (1320 * 5.4, 0.25, 35)]
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        s = sum(a * math.exp(-d * t) * math.sin(2 * math.pi * f * t) for f, a, d in partials)
        if t < 0.004:
            s += (random.random() * 2 - 1) * 0.6 * (1 - t / 0.004)
        out.append(s)
    return out

def release():
    # 前段：上升的「咻」（雜訊濾波截止頻率往上＋音高上滑）；後段：爆開＋低頻衝擊
    dur = 0.75
    rise = 0.28
    out, lp, phase = [], 0.0, 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        s = 0.0
        if t < rise:
            k = t / rise
            cutoff = 400 + 5000 * k * k
            a = 1 - math.exp(-2 * math.pi * cutoff / SR)
            lp += a * ((random.random() * 2 - 1) - lp)
            f = 300 + 900 * k * k
            phase += 2 * math.pi * f / SR
            s += (lp * 0.8 + math.sin(phase) * 0.35) * k
        else:
            tb = t - rise
            noise = random.random() * 2 - 1
            lp += 0.35 * (noise - lp)
            s += lp * math.exp(-9 * tb) * 1.0
            s += math.sin(2 * math.pi * (90 - 30 * min(tb / 0.3, 1)) * tb) * math.exp(-7 * tb) * 1.2
            s += 0.3 * math.sin(2 * math.pi * 1320 * tb) * math.exp(-10 * tb)
        out.append(s)
    return out

def hit():
    # 光球命中：音高下墜的短音＋帶通雜訊「啪」
    dur = 0.22
    out, lp1, lp2, phase = [], 0.0, 0.0, 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        f = 880 * math.exp(-6 * t)
        phase += 2 * math.pi * f / SR
        noise = random.random() * 2 - 1
        lp1 += 0.45 * (noise - lp1)
        lp2 += 0.08 * (noise - lp2)
        band = lp1 - lp2
        s = math.sin(phase) * math.exp(-14 * t) * 0.7 + band * math.exp(-25 * t) * 1.2
        out.append(s)
    return out

def enemy_hit():
    # 敵人被擊中：低頻「咚」（音高快速下墜）＋開頭短促的帶通雜訊「啪」，偏厚實的打擊感
    dur = 0.2
    out, lp1, lp2, phase = [], 0.0, 0.0, 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        f = 60 + 110 * math.exp(-30 * t)
        phase += 2 * math.pi * f / SR
        thump = math.sin(phase) * math.exp(-18 * t)
        noise = random.random() * 2 - 1
        lp1 += 0.6 * (noise - lp1)
        lp2 += 0.12 * (noise - lp2)
        crack = (lp1 - lp2) * math.exp(-60 * t) * 1.4
        click = math.sin(2 * math.pi * 900 * t) * math.exp(-80 * t) * 0.3
        out.append(thump + crack + click)
    return out

def banner_plant():
    # 插旗：木桿插地的低頻「咚」＋一點碎石雜訊，接著布料被風吹開的兩下「啪啦」
    dur = 0.55
    out, lp, lp_b, phase = [], 0.0, 0.0, 0.0
    flaps = [(0.12, 1.0), (0.24, 0.6)]
    for i in range(int(SR * dur)):
        t = i / SR
        f = 55 + 90 * math.exp(-25 * t)
        phase += 2 * math.pi * f / SR
        s = math.sin(phase) * math.exp(-14 * t) * 1.2
        noise = random.random() * 2 - 1
        lp += 0.25 * (noise - lp)
        s += lp * math.exp(-35 * t) * 0.8
        lp_b += 0.5 * (noise - lp_b)
        for start, amp in flaps:
            tf = t - start
            if 0 <= tf < 0.12:
                # 布料：快速起音、帶一點抖動的高頻雜訊
                env = (tf / 0.01 if tf < 0.01 else math.exp(-30 * (tf - 0.01)))
                flutter = 0.6 + 0.4 * math.sin(2 * math.pi * 45 * tf)
                s += (noise - lp_b * 0.5) * env * flutter * 0.35 * amp
        out.append(s)
    return out

out_dir = sys.argv[1]
for name, fn in [("reflect_open", shield_open), ("reflect_absorb", absorb), ("reflect_release", release), ("reflect_hit", hit), ("enemy_hit", enemy_hit), ("banner_plant", banner_plant)]:
    path = os.path.join(out_dir, name + ".wav")
    write(path, fn())
    print("wrote", path)
