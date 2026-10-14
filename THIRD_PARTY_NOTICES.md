# Third-party notices

OpenDictate's architecture and initial recording-to-paste flow were inspired by
and adapted from [VoiceScribe](https://github.com/eddmann/VoiceScribe). VoiceScribe
is licensed under the MIT License:

> MIT License
>
> Copyright (c) 2026 Edd Mann
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

The Geist, Geist Mono and Geist Pixel fonts in `design/fonts/` are
Copyright 2024 The Geist Project Authors
(https://github.com/vercel/geist-font) and licensed under the SIL Open Font
License 1.1; the full license is in [`design/fonts/OFL.txt`](design/fonts/OFL.txt).
The macOS app bundle ships these font files unchanged with that license in
`Contents/Resources/Fonts/`.

The iPhone app links [FluidAudio](https://github.com/FluidInference/FluidAudio)
0.15.5, Copyright FluidInference, licensed under the Apache License 2.0
(https://www.apache.org/licenses/LICENSE-2.0). Its trial recognition
"Parakeet" downloads NVIDIA's
[Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)
model, Copyright NVIDIA Corporation, licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), in the Core ML
conversion by FluidInference
([FluidInference/parakeet-tdt-0.6b-v3-coreml](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml)).
The model is not part of this repository or the app bundle.

FluidAudio includes fastcluster (in its `FastClusterWrapper` target), which the
iPhone app links with it under this license:

> Copyright:
>   * Until package version 1.1.23: © 2011 Daniel Müllner <https://danifold.net>
>   * All changes from version 1.1.24 on: © Google Inc. <https://www.google.com>
> All rights reserved.
>
> Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
>
>   * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
>   * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
>
> THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The Windows app links [NAudio](https://github.com/naudio/NAudio) 3.1.0
(`NAudio.Wasapi`, referenced in `windows/OpenDictate.Windows`), Copyright Mark
Heath, licensed under the MIT License
(https://github.com/naudio/NAudio/blob/master/license.txt). Per the NuGet
package metadata (nuspec) of `NAudio.Wasapi` 3.1.0 for .NET 9 and later, it
brings `NAudio.Core` 3.1.0 (same author and license) and that brings
`System.Numerics.Tensors` 9.0.0 (Copyright .NET Foundation and Contributors,
MIT License). Check these transitive versions again when NAudio is updated.

The Linux binary links these Rust crates, grouped by the license each declares
in its manifest. Every crate's license text comes with its source in the Cargo
registry. The list holds only crates compiled into the binary (no dev, build or
proc-macro dependencies); regenerate it with `python3 scripts/third-party-rust.py`
after a change to `linux/Cargo.lock`, and check it with `--check`.

<!-- third-party-rust:begin -->

- **Apache-2.0:** cpal 0.18.2, hound 3.5.1

- **Apache-2.0 AND ISC:** ring 0.17.14

- **Apache-2.0 OR ISC OR MIT:** rustls 0.23.45

- **Apache-2.0 OR MIT:** cmov 0.5.4, const-oid 0.10.2, ctutils 0.4.3, idna_adapter 1.2.2, utf8_iter 1.0.4, zeroize 1.9.0

- **Apache-2.0/MIT:** alsa 0.11.0

- **BSD-3-Clause:** subtle 2.6.1

- **CDLA-Permissive-2.0:** webpki-roots 0.26.11, webpki-roots 1.0.9

- **ISC:** rustls-webpki 0.103.15, untrusted 0.9.0

- **MIT:** alsa-sys 0.4.0, zmij 1.0.23

- **MIT OR Apache-2.0:** base64 0.22.1, bitflags 2.13.2, block-buffer 0.12.1, cfg-if 1.0.5, cpufeatures 0.3.1, crypto-common 0.2.2, dasp_sample 0.11.0, digest 0.11.3, form_urlencoded 1.2.2, getrandom 0.2.17, hex 0.4.3, hmac 0.13.0, hybrid-array 0.4.15, idna 1.1.0, itoa 1.0.18, libc 0.2.190, log 0.4.34, once_cell 1.21.4, percent-encoding 2.3.2, rustls-pki-types 1.15.1, serde 1.0.229, serde_core 1.0.229, serde_json 1.0.151, sha2 0.11.0, smallvec 1.16.1, stable_deref_trait 1.2.1, typenum 1.20.1, ureq 2.12.1, url 2.5.8

- **Unicode-3.0:** icu_collections 2.3.0, icu_locale_core 2.3.0, icu_normalizer 2.3.0, icu_normalizer_data 2.3.0, icu_properties 2.3.0, icu_properties_data 2.3.0, icu_provider 2.3.1, litemap 0.8.3, potential_utf 0.1.6, tinystr 0.8.4, writeable 0.6.4, yoke 0.8.3, zerofrom 0.1.8, zerotrie 0.2.5, zerovec 0.11.8

- **Unlicense OR MIT:** memchr 2.8.3

<!-- third-party-rust:end -->
