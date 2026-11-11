class_name Synth
extends RefCounted
## Makes every sound in the game from scratch, in code, so there are no audio
## files to license: soft squeezes, sugar ticks, wooden taps, a tier's
## thunk, a spatula's scrape, little chimes and a quiet seaside wash.
##
## Each recipe returns mono samples (-1..1) at its own rate; `to_stream`
## turns them into an AudioStreamWAV (16-bit), looping if asked. Recipes are
## deterministic (fixed seeds), so a sound is the same every launch.
##
## Sounds are kept soft on purpose: gentle attacks, low-passed noise, nothing
## harsh above ~8 kHz except the tiniest sugar ticks.

const RATE: int = 44100
## Loops of filtered noise do not need the top octave.
const LOOP_RATE: int = 22050


# --- Building blocks -------------------------------------------------------------

## White noise from a fixed seed.
static func noise(count: int, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		out[i] = rng.randf() * 2.0 - 1.0
	return out


## One-pole low-pass, cutoff in Hz (constant).
static func lowpass(x: PackedFloat32Array, cutoff: float, rate: int) -> PackedFloat32Array:
	var a: float = 1.0 - exp(-TAU * cutoff / float(rate))
	var y: float = 0.0
	var out := PackedFloat32Array()
	out.resize(x.size())
	for i in range(x.size()):
		y += a * (x[i] - y)
		out[i] = y
	return out


## One-pole high-pass, cutoff in Hz.
static func highpass(x: PackedFloat32Array, cutoff: float, rate: int) -> PackedFloat32Array:
	var low: PackedFloat32Array = lowpass(x, cutoff, rate)
	var out := PackedFloat32Array()
	out.resize(x.size())
	for i in range(x.size()):
		out[i] = x[i] - low[i]
	return out


## A band of noise between two cutoffs (two low-passes for a softer slope).
static func band(x: PackedFloat32Array, low_cut: float, high_cut: float, rate: int) -> PackedFloat32Array:
	return highpass(lowpass(lowpass(x, high_cut, rate), high_cut, rate), low_cut, rate)


## A band whose centre sweeps from `from_hz` to `to_hz` over the sound.
static func sweep_band(x: PackedFloat32Array, from_hz: float, to_hz: float, width: float, rate: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(x.size())
	var lo: float = 0.0
	var lo2: float = 0.0
	var hi_state: float = 0.0
	var count: int = x.size()
	for i in range(count):
		var t: float = float(i) / float(maxi(count - 1, 1))
		var centre: float = from_hz * pow(to_hz / from_hz, t)
		var a_hi: float = 1.0 - exp(-TAU * centre * (1.0 + width) / float(rate))
		var a_lo: float = 1.0 - exp(-TAU * centre / (1.0 + width) / float(rate))
		lo += a_hi * (x[i] - lo)
		lo2 += a_hi * (lo - lo2)
		hi_state += a_lo * (lo2 - hi_state)
		out[i] = lo2 - hi_state
	return out


## A sine whose pitch glides from `from_hz` to `to_hz` (exponentially),
## with an exponential decay of `decay` seconds.
static func tone(count: int, from_hz: float, to_hz: float, decay: float, rate: int, phase: float = 0.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	var p: float = phase
	for i in range(count):
		var t: float = float(i) / float(rate)
		var f: float = from_hz * pow(to_hz / from_hz, float(i) / float(maxi(count - 1, 1)))
		p += TAU * f / float(rate)
		out[i] = sin(p) * exp(-t / decay)
	return out


## Multiplies by an attack-then-exponential-decay envelope.
static func envelope(x: PackedFloat32Array, attack: float, decay: float, rate: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(x.size())
	for i in range(x.size()):
		var t: float = float(i) / float(rate)
		var a: float = smoothstep(0.0, maxf(attack, 0.0001), t)
		out[i] = x[i] * a * exp(-maxf(t - attack, 0.0) / decay)
	return out


## Multiplies by a smooth swell: up over `attack`, held, down over `release`.
static func swell(x: PackedFloat32Array, attack: float, release: float, rate: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(x.size())
	var length: float = float(x.size()) / float(rate)
	for i in range(x.size()):
		var t: float = float(i) / float(rate)
		out[i] = x[i] * smoothstep(0.0, attack, t) * smoothstep(0.0, release, length - t)
	return out


static func mix(a: PackedFloat32Array, b: PackedFloat32Array, gain_b: float = 1.0, offset: int = 0) -> PackedFloat32Array:
	var out: PackedFloat32Array = a.duplicate()
	if out.size() < b.size() + offset:
		out.resize(b.size() + offset)
	for i in range(b.size()):
		out[i + offset] += b[i] * gain_b
	return out


static func scale(x: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(x.size())
	for i in range(x.size()):
		out[i] = x[i] * gain
	return out


## Scales so the loudest sample is `peak`.
static func normalize(x: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top: float = 0.0
	for v in x:
		top = maxf(top, absf(v))
	return scale(x, peak / top) if top > 0.0 else x


## Makes a seamless loop: the last `fade` seconds are blended into the start
## and dropped, so the end flows straight back into the beginning.
static func make_loop(x: PackedFloat32Array, fade: float, rate: int) -> PackedFloat32Array:
	var n: int = mini(int(fade * float(rate)), x.size() / 3)
	var body: int = x.size() - n
	var out: PackedFloat32Array = x.slice(0, body)
	for i in range(n):
		var t: float = float(i) / float(n)
		# Equal-power crossfade.
		out[i] = x[i] * sin(t * PI * 0.5) + x[body + i] * cos(t * PI * 0.5)
	return out


## Short soft clicks (a few samples), to give taps and ticks their edge.
static func click(count: int, cutoff: float, decay: float, rate: int, seed_value: int) -> PackedFloat32Array:
	return envelope(lowpass(noise(count, seed_value), cutoff, rate), 0.0005, decay, rate)


static func samples(seconds: float, rate: int) -> int:
	return maxi(int(seconds * float(rate)), 1)


## 16-bit mono AudioStreamWAV from samples.
static func to_stream(x: PackedFloat32Array, rate: int, looping: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(x.size() * 2)
	for i in range(x.size()):
		data.encode_s16(i * 2, int(clampf(x[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = x.size()
	return stream


# --- Recipes ----------------------------------------------------------------------

## The soft pop of a button: a tiny falling blip.
static func tap() -> PackedFloat32Array:
	var n: int = samples(0.07, RATE)
	var body: PackedFloat32Array = tone(n, 900.0, 640.0, 0.022, RATE)
	return normalize(mix(body, click(samples(0.004, RATE), 6000.0, 0.0015, RATE, 3), 0.4), 0.5)


## Picking up a different tool: a hollow wooden tok.
static func tok() -> PackedFloat32Array:
	var n: int = samples(0.14, RATE)
	var a: PackedFloat32Array = tone(n, 430.0, 400.0, 0.04, RATE)
	var b: PackedFloat32Array = tone(n, 1080.0, 1040.0, 0.018, RATE)
	return normalize(mix(mix(a, b, 0.45), click(samples(0.006, RATE), 3000.0, 0.002, RATE, 5), 0.5), 0.55)


## Frosting squeezed through a nozzle: a soft, wet hiss with little
## bubbles, looped. Its volume and pitch follow how much is flowing.
static func squeeze_loop() -> PackedFloat32Array:
	var rate: int = LOOP_RATE
	var n: int = samples(2.2, rate)
	var hiss: PackedFloat32Array = band(noise(n, 11), 180.0, 1100.0, rate)
	# A slow, uneven wobble, as the bag is squeezed by hand.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var wobble := PackedFloat32Array()
	wobble.resize(n)
	var w: float = 0.0
	var goal: float = 0.0
	for i in range(n):
		if i % (rate / 12) == 0:
			goal = rng.randf_range(-1.0, 1.0)
		w += (goal - w) * 0.0015
		wobble[i] = 0.75 + 0.25 * w
	for i in range(n):
		hiss[i] *= wobble[i]
	# Little bubbles of air popping through the cream.
	for k in range(14):
		var at: int = rng.randi_range(0, n - samples(0.05, rate))
		var bubble: PackedFloat32Array = tone(samples(0.05, rate), rng.randf_range(260.0, 520.0), rng.randf_range(180.0, 300.0), 0.012, rate)
		hiss = mix(hiss, bubble, rng.randf_range(0.25, 0.5), at)
	return normalize(make_loop(hiss, 0.25, rate), 0.6)


## The first squish when a squeeze starts.
static func squish() -> PackedFloat32Array:
	var n: int = samples(0.16, RATE)
	var burst: PackedFloat32Array = envelope(lowpass(noise(n, 21), 900.0, RATE), 0.012, 0.05, RATE)
	var thump: PackedFloat32Array = tone(n, 190.0, 120.0, 0.04, RATE)
	return normalize(mix(burst, thump, 0.6), 0.55)


## Letting go: a small plip as the frosting breaks off.
static func plip() -> PackedFloat32Array:
	var n: int = samples(0.11, RATE)
	return normalize(mix(tone(n, 560.0, 380.0, 0.03, RATE), click(samples(0.005, RATE), 2500.0, 0.002, RATE, 23), 0.3), 0.45)


## One sprinkle landing: a tiny bright tick (several variants).
static func tick(variant: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + variant
	var n: int = samples(0.03, RATE)
	var ping: PackedFloat32Array = tone(n, rng.randf_range(2600.0, 4200.0), rng.randf_range(2400.0, 3800.0), 0.006, RATE, rng.randf() * TAU)
	var grain: PackedFloat32Array = envelope(highpass(noise(n, 200 + variant), 3500.0, RATE), 0.0003, 0.003, RATE)
	return normalize(mix(ping, grain, 0.6), 0.5)


## A pearl, dragée or candle set down: a glassy little tock.
static func tock(variant: int) -> PackedFloat32Array:
	var base: float = [1750.0, 2050.0, 2400.0][variant % 3]
	var n: int = samples(0.08, RATE)
	var a: PackedFloat32Array = tone(n, base, base * 0.98, 0.018, RATE)
	var b: PackedFloat32Array = tone(n, base * 2.71, base * 2.68, 0.008, RATE)
	return normalize(mix(mix(a, b, 0.3), click(samples(0.003, RATE), 7000.0, 0.001, RATE, 31 + variant), 0.5), 0.5)


## Something soft set down (fondant, a flower, fruit): a muffled pat.
static func pat(variant: int) -> PackedFloat32Array:
	var n: int = samples(0.1, RATE)
	var body: PackedFloat32Array = envelope(lowpass(noise(n, 41 + variant), 1100.0 + 200.0 * float(variant), RATE), 0.003, 0.025, RATE)
	var thump: PackedFloat32Array = tone(n, 240.0 + 30.0 * float(variant), 170.0, 0.03, RATE)
	return normalize(mix(body, thump, 0.5), 0.5)


## A ribbon drawn round the cake: a soft satin swish.
static func swish() -> PackedFloat32Array:
	var n: int = samples(0.5, RATE)
	return normalize(swell(sweep_band(noise(n, 51), 900.0, 2600.0, 0.6, RATE), 0.18, 0.3, RATE), 0.45)


## Ganache poured over the edge: a slow, glossy glug.
static func pour() -> PackedFloat32Array:
	var n: int = samples(0.7, RATE)
	var flow: PackedFloat32Array = swell(lowpass(lowpass(noise(n, 61), 500.0, RATE), 500.0, RATE), 0.12, 0.4, RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 62
	for k in range(4):
		var at: int = int(float(n) * (0.12 + 0.18 * float(k)))
		flow = mix(flow, tone(samples(0.09, RATE), rng.randf_range(150.0, 230.0), rng.randf_range(100.0, 140.0), 0.03, RATE), 0.5, at)
	return normalize(flow, 0.5)


## A tier landing on the stack: a deep, soft thunk.
static func thunk() -> PackedFloat32Array:
	var n: int = samples(0.45, RATE)
	var low: PackedFloat32Array = tone(n, 92.0, 54.0, 0.14, RATE)
	var body: PackedFloat32Array = tone(n, 170.0, 140.0, 0.05, RATE)
	var cushion: PackedFloat32Array = envelope(lowpass(noise(n, 71), 320.0, RATE), 0.004, 0.06, RATE)
	return normalize(mix(mix(low, body, 0.4), cushion, 0.7), 0.75)


## Frosting spread over a tier: a long, smooth swoosh.
static func coat_swoosh() -> PackedFloat32Array:
	var n: int = samples(1.0, RATE)
	return normalize(swell(sweep_band(noise(n, 81), 1600.0, 600.0, 0.8, RATE), 0.25, 0.55, RATE), 0.5)


## A scraper gliding round the coat, looped (volume follows its speed).
static func scrape_loop() -> PackedFloat32Array:
	var rate: int = LOOP_RATE
	var n: int = samples(1.6, rate)
	var grain: PackedFloat32Array = band(noise(n, 91), 900.0, 3200.0, rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = 92
	var g: float = 0.0
	for i in range(n):
		if i % 300 == 0:
			g = rng.randf_range(0.6, 1.0)
		grain[i] *= g
	return normalize(make_loop(lowpass(grain, 4000.0, rate), 0.2, rate), 0.45)


## A gentle two-note sparkle (a coat polished to silk).
static func chime() -> PackedFloat32Array:
	var n: int = samples(1.5, RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var partials: Array = [[1046.5, 1.0, 0.7], [1568.0, 0.7, 0.55], [2093.0, 0.4, 0.4], [3136.0, 0.18, 0.25]]
	for p: Array in partials:
		out = mix(out, tone(n, float(p[0]), float(p[0]) * 1.002, float(p[2]), RATE), float(p[1]))
	var second: PackedFloat32Array = PackedFloat32Array()
	second.resize(n)
	for p: Array in partials:
		second = mix(second, tone(n, float(p[0]) * 1.335, float(p[0]) * 1.337, float(p[2]) * 0.9, RATE), float(p[1]) * 0.8)
	out = mix(out, second, 1.0, samples(0.12, RATE))
	return normalize(envelope(out, 0.004, 0.9, RATE), 0.45)


## Undo (falling) and redo (rising): a short airy whoosh.
static func whoosh(rising: bool) -> PackedFloat32Array:
	var n: int = samples(0.3, RATE)
	var from_hz: float = 700.0 if rising else 2400.0
	var to_hz: float = 2400.0 if rising else 700.0
	return normalize(swell(sweep_band(noise(n, 101 if rising else 102), from_hz, to_hz, 0.7, RATE), 0.08, 0.18, RATE), 0.38)


## A soft dusting brush whisked over the cake, looped.
static func brush_loop() -> PackedFloat32Array:
	var rate: int = RATE
	var n: int = samples(1.4, rate)
	var air: PackedFloat32Array = band(noise(n, 111), 2500.0, 9000.0, rate)
	for i in range(n):
		var t: float = float(i) / float(rate)
		air[i] *= 0.65 + 0.35 * sin(t * TAU * 2.5) * sin(t * TAU * 0.7 + 1.0)
	return normalize(make_loop(air, 0.2, rate), 0.35)


## One glint of lustre dust: a high, faint, shimmering ping.
static func twinkle(variant: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 120 + variant
	var n: int = samples(0.35, RATE)
	var f: float = rng.randf_range(3600.0, 5600.0)
	var a: PackedFloat32Array = tone(n, f, f * 1.001, 0.09, RATE)
	var b: PackedFloat32Array = tone(n, f * 1.5, f * 1.502, 0.05, RATE)
	return normalize(envelope(mix(a, b, 0.4), 0.002, 0.12, RATE), 0.3)


## The turntable's bearing: a low, soft rumble, looped (follows its speed).
static func spin_loop() -> PackedFloat32Array:
	var rate: int = LOOP_RATE
	var n: int = samples(2.0, rate)
	var rumble: PackedFloat32Array = lowpass(lowpass(noise(n, 131), 180.0, rate), 180.0, rate)
	var hum: PackedFloat32Array = tone(n, 58.0, 58.0, 1000.0, rate)
	return normalize(make_loop(mix(rumble, hum, 0.05), 0.3, rate), 0.5)


## Waves on the beach outside the window: slow swells of soft surf, looped.
static func waves_loop() -> PackedFloat32Array:
	var rate: int = LOOP_RATE
	var n: int = samples(12.0, rate)
	var deep: PackedFloat32Array = lowpass(lowpass(noise(n, 141), 420.0, rate), 420.0, rate)
	var foam: PackedFloat32Array = band(noise(n, 142), 900.0, 3500.0, rate)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t: float = float(i) / float(rate)
		# Two waves in each loop, each a slow rise and a long hiss back down.
		var phase: float = fposmod(t / 6.0, 1.0)
		var rise: float = smoothstep(0.0, 0.35, phase) * (1.0 - smoothstep(0.35, 1.0, phase))
		var crest: float = exp(-pow((phase - 0.38) / 0.12, 2.0))
		out[i] = deep[i] * (0.35 + 0.65 * rise) + foam[i] * crest * 0.35
	return normalize(make_loop(out, 1.5, rate), 0.6)
