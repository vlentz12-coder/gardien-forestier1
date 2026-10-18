class_name Sfx
## Génère de petits sons synthétiques (en attendant de vrais fichiers audio).

static func tone(f0: float, f1: float, dur: float, wave: String = "sine", vol: float = 0.4) -> AudioStreamWAV:
    var rate := 22050
    var n := int(rate * dur)
    var data := PackedByteArray()
    data.resize(n * 2)
    var phase := 0.0
    for i in n:
        var t := float(i) / n
        var f := lerpf(f0, f1, t)
        phase += TAU * f / rate
        var s := sin(phase)
        if wave == "saw":
            s = fmod(phase / TAU, 1.0) * 2.0 - 1.0
        var env := pow(1.0 - t, 2.0)
        data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = rate
    w.data = data
    return w
