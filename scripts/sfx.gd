class_name Sfx
extends RefCounted
## Procedurally generated sound effects (no external audio files needed).
## Replace with real .wav/.ogg files later by loading them in player.gd.

const RATE := 22050


static func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


static func gunshot() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		lp += 0.3 * (noise - lp)
		lp2 += 0.05 * (noise - lp2)
		var crack := noise * exp(-t * 70.0)
		var body := lp * exp(-t * 10.0) * 1.4
		var tail := lp2 * exp(-t * 4.0) * 2.5
		var thump := sin(TAU * 62.0 * t) * exp(-t * 20.0)
		s[i] = (crack * 0.7 + body + tail + thump * 0.9) * 0.75
	return _make(s)


## Short metallic click. Used for empty trigger, magazine and bolt sounds.
static func metal(freqs: Array, length: float, decay: float, noise_amt: float, seed_val: int, delay := 0.0) -> AudioStreamWAV:
	var n := int(RATE * (length + delay))
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var start := int(RATE * delay)
	for i in range(start, n):
		var t := float(i - start) / RATE
		var v := rng.randf_range(-1.0, 1.0) * noise_amt
		for f in freqs:
			v += sin(TAU * float(f) * t) * 0.35
		s[i] = v * exp(-t * decay) * 0.8
	return _make(s)


static func mag_out() -> AudioStreamWAV:
	return _concat([metal([1800.0, 2600.0], 0.06, 70.0, 0.6, 3), metal([900.0, 1400.0], 0.12, 35.0, 0.4, 4, 0.05)])


static func mag_in() -> AudioStreamWAV:
	return _concat([metal([700.0, 1100.0], 0.05, 60.0, 0.5, 5), metal([2200.0, 3100.0], 0.1, 55.0, 0.8, 6, 0.06)])


static func bolt() -> AudioStreamWAV:
	return _concat([metal([1500.0, 2100.0], 0.08, 50.0, 0.7, 7), metal([1900.0, 2700.0, 3500.0], 0.15, 40.0, 0.9, 8, 0.12)])


static func empty_click() -> AudioStreamWAV:
	return metal([3000.0, 4200.0], 0.05, 120.0, 0.5, 9)


static func footstep(seed_val: int) -> AudioStreamWAV:
	var n := int(RATE * 0.16)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += 0.12 * (rng.randf_range(-1.0, 1.0) - lp)
		s[i] = lp * 3.0 * exp(-t * 28.0) * minf(1.0, t * 400.0)
	return _make(s)


static func land() -> AudioStreamWAV:
	var n := int(RATE * 0.3)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += 0.08 * (rng.randf_range(-1.0, 1.0) - lp)
		s[i] = (lp * 4.0 + sin(TAU * 55.0 * t) * 0.6) * exp(-t * 16.0)
	return _make(s)


static func jump() -> AudioStreamWAV:
	var n := int(RATE * 0.2)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += 0.2 * (rng.randf_range(-1.0, 1.0) - lp)
		s[i] = lp * 2.0 * exp(-t * 22.0)
	return _make(s)


static func impact() -> AudioStreamWAV:
	return metal([800.0, 1300.0], 0.12, 45.0, 1.0, 41)


static func _concat(parts: Array) -> AudioStreamWAV:
	# Mix several streams together (they already contain their own delays).
	var longest := 0
	for p in parts:
		longest = maxi(longest, (p as AudioStreamWAV).data.size())
	var out := PackedFloat32Array()
	out.resize(longest / 2)
	for p in parts:
		var d: PackedByteArray = (p as AudioStreamWAV).data
		for i in d.size() / 2:
			out[i] += d.decode_s16(i * 2) / 32767.0
	return _make(out)
