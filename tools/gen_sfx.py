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

def taunt():
    # 挑釁：前段是粗啞的「嘰哩咕嚕」罵聲（鋸齒波＋低通、每個音節音高亂跳），
    # 後段接一個上揚的雙音「叮叮！」提示敵人被激怒
    dur = 0.62
    out, phase, lp = [], 0.0, 0.0
    syllables = [(0.00, 0.07, 150), (0.08, 0.06, 185), (0.15, 0.07, 135), (0.23, 0.10, 200)]
    for i in range(int(SR * dur)):
        t = i / SR
        s = 0.0
        for start, length, f in syllables:
            ts = t - start
            if 0 <= ts < length:
                env = math.sin(math.pi * ts / length)
                freq = f * (1 + 0.15 * math.sin(2 * math.pi * 30 * ts))
                phase += freq / SR
                saw = 2 * (phase % 1.0) - 1
                lp += 0.18 * (saw - lp)
                s += lp * env * 1.2
        for start, f in [(0.36, 988), (0.45, 1319)]:
            tb = t - start
            if tb >= 0:
                s += 0.45 * math.sin(2 * math.pi * f * tb) * math.exp(-18 * tb) * (1 if tb > 0.003 else tb / 0.003)
        out.append(s)
    return out

def block_clang():
    # 格擋成功：盾牌金屬「鏘～」——不整數倍的金屬泛音（各自衰減速度不同，留一點餘音）＋開頭撞擊雜訊
    dur = 0.5
    partials = [(520, 1.0, 9), (520 * 2.63, 0.7, 13), (520 * 4.4, 0.45, 20), (520 * 6.8, 0.3, 28)]
    out, lp = [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        s = sum(a * math.exp(-d * t) * math.sin(2 * math.pi * f * t) for f, a, d in partials)
        noise = random.random() * 2 - 1
        lp += 0.5 * (noise - lp)
        s += (noise - lp) * math.exp(-120 * t) * 1.5
        s += math.sin(2 * math.pi * 110 * t) * math.exp(-30 * t) * 0.6
        out.append(s)
    return out

def player_hurt():
    # 玩家被擊中：低頻悶「咚」＋黏糊的「啪」（帶通雜訊中心頻率往下掉，像被史萊姆拍到）＋短促低吼
    dur = 0.28
    out, lp1, lp2, phase, phase_g, lpg = [], 0.0, 0.0, 0.0, 0.0, 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        f = 50 + 70 * math.exp(-25 * t)
        phase += 2 * math.pi * f / SR
        s = math.sin(phase) * math.exp(-16 * t) * 1.1
        noise = random.random() * 2 - 1
        a1 = 0.35 * math.exp(-8 * t) + 0.05
        lp1 += a1 * (noise - lp1)
        lp2 += 0.04 * (noise - lp2)
        s += (lp1 - lp2) * math.exp(-22 * t) * 1.3
        fg = 170 - 60 * min(t / 0.2, 1)
        phase_g += fg / SR
        saw = 2 * (phase_g % 1.0) - 1
        lpg += 0.12 * (saw - lpg)
        s += lpg * math.exp(-12 * t) * 0.5 * min(t / 0.01, 1)
        out.append(s)
    return out

def counter_hit():
    # 反擊成功：短「咻」（高頻雜訊快速增強）→ 清亮斬擊（高頻泛音）＋低頻重擊＋閃光「叮」
    dur = 0.55
    swoosh = 0.06
    out, lp = [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        noise = random.random() * 2 - 1
        lp += 0.3 * (noise - lp)
        s = 0.0
        if t < swoosh:
            k = t / swoosh
            s += (noise - lp) * k * k * 0.9
        else:
            tb = t - swoosh
            s += (noise - lp) * math.exp(-40 * tb) * 1.0
            s += 0.6 * math.sin(2 * math.pi * 1800 * tb) * math.exp(-14 * tb)
            s += 0.4 * math.sin(2 * math.pi * 2750 * tb) * math.exp(-18 * tb)
            s += math.sin(2 * math.pi * (80 - 30 * min(tb / 0.2, 1)) * tb) * math.exp(-12 * tb) * 1.0
            s += 0.35 * math.sin(2 * math.pi * 2637 * tb) * math.exp(-5 * tb) * (0.6 + 0.4 * math.sin(2 * math.pi * 12 * tb))
        out.append(s)
    return out

def shield_bash():
    # 盾擊命中：厚重的「砰」——低頻重擊＋盾面金屬短促共鳴（衰減比格擋快，不拖餘音）＋撞擊雜訊
    dur = 0.3
    out, lp, phase = [], 0.0, 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        f = 70 + 120 * math.exp(-35 * t)
        phase += 2 * math.pi * f / SR
        s = math.sin(phase) * math.exp(-14 * t) * 1.3
        for fr, a, d in [(380, 0.5, 25), (380 * 2.7, 0.35, 35), (380 * 4.9, 0.2, 50)]:
            s += a * math.sin(2 * math.pi * fr * t) * math.exp(-d * t)
        noise = random.random() * 2 - 1
        lp += 0.3 * (noise - lp)
        s += lp * math.exp(-45 * t) * 1.2
        out.append(s)
    return out

def bash_crash():
    # 被擊飛的怪撞到牆/撞到怪：沉重撞擊「咚」＋碎石般的顆粒雜訊（隨機脈衝）拖尾
    dur = 0.45
    out, lp, phase = [], 0.0, 0.0
    grains = sorted(random.uniform(0.02, 0.3) for _ in range(14))
    for i in range(int(SR * dur)):
        t = i / SR
        f = 45 + 80 * math.exp(-20 * t)
        phase += 2 * math.pi * f / SR
        s = math.sin(phase) * math.exp(-10 * t) * 1.4
        noise = random.random() * 2 - 1
        lp += 0.2 * (noise - lp)
        s += lp * math.exp(-18 * t) * 1.0
        for g in grains:
            tg = t - g
            if 0 <= tg < 0.02:
                s += (random.random() * 2 - 1) * math.exp(-200 * tg) * 0.5
        out.append(s)
    return out

out_dir = sys.argv[1]
for name, fn in [("reflect_open", shield_open), ("reflect_absorb", absorb), ("reflect_release", release), ("reflect_hit", hit), ("enemy_hit", enemy_hit), ("banner_plant", banner_plant), ("taunt", taunt), ("block_clang", block_clang), ("player_hurt", player_hurt), ("counter_hit", counter_hit), ("shield_bash", shield_bash), ("bash_crash", bash_crash)]:
    path = os.path.join(out_dir, name + ".wav")
    write(path, fn())
    print("wrote", path)
