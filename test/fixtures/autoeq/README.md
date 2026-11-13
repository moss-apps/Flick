# Independent response reference

`response_reference.json` contains **synthetic test filters**, not correction
presets for a particular headphone. Values were calculated by executing the
unmodified `biquad_coefficients` methods of AutoEq's `Peaking`, `LowShelf` and
`HighShelf`, followed by `PEQFilter.fr`, with NumPy float64. The per-profile
preamp was then added once. They are not generated from Flick's Dart/Rust math.

Source: [AutoEq autoeq/peq.py](https://github.com/jaakkopasanen/AutoEq/blob/7ae0f56d53074872b028649617a22bbb4232feb7/autoeq/peq.py),
MIT, Copyright (c) 2018-2022 Jaakko Pasanen.
Source SHA-256: `74f84e43b01c00d1acad1345a42ba38644c7fddb279a16ec86a8043a8e47e5b2`.
Expected values are rounded to nine decimal places.

Extraction used Python's `ast` to execute only those four methods (no optimizer,
SciPy, network or package installation). For each sample rate, set `f` to the
listed frequencies, `fs`/`_fs` to the sample rate and `fc`/`gain`/`q` to each
listed filter's settings. Sum their `fr` vectors and add `preampDb`.
Normal tests read the checked-in JSON and require no Python or network.

Dart checks the graph/fixed-band response calculation. Rust processes settled
sine waves through the real chain, including preamp, and compares measured RMS
gain with this same independent reference at 44.1/48/96/192 kHz. The Rust tolerance
allows float32 coefficient/filter-state precision; this is not hardware proof.
