# Third-party notices for the OpenDictate keyboard

The keyboard and the app's warm microphone follow the design of Hex's iOS
keyboard. `ContainingAppOpener.swift` is taken from Hex unchanged except for
formatting; `KeyboardShared/KeyboardBridge.swift` and
`App/Dictation/WarmMicrophone.swift` are written for OpenDictate after Hex's
`KeyboardBridge.swift` and `AudioBackend.swift`, and
`KeyboardShared/Autocorrect.swift` after Hex's `AutocorrectEngine.swift`.

`emoji.txt` lists the emoji of Unicode's emoji-test.txt 18.0 by category,
taken from Hex's `emoji-index-de.txt`; Unicode's data is under the Unicode
License v3 in `LICENSE-Unicode.txt`.

Source: https://github.com/anomalyco/hex (folder `ios/`, commit
`339a5caa56a22223d126ba0a98b944f66123bbc2`)

```text
MIT License

Copyright (c) 2026 Christopher Langton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Wortschatz Leipzig

`wortschatz-de.txt` and `wortschatz-de-pairs.txt` are trimmed by
`scripts/wortschatz.py` from the corpus `deu-de_web_2021_1M` of the Leipzig
Corpora Collection (Universität Leipzig, https://wortschatz.uni-leipzig.de),
downloaded on 25 November 2026 from
https://downloads.wortschatz-leipzig.de/corpora/deu-de_web_2021_1M.tar.gz
(SHA-256 `d04ad49440131fa9b8cf96d097513142f44f3cc3c4b4fef5b69841827bb63324`).
The corpora are licensed under Creative Commons Attribution (CC BY), see
https://wortschatz.uni-leipzig.de/en/usage.

D. Goldhahn, T. Eckart & U. Quasthoff: Building Large Monolingual Dictionaries
at the Leipzig Corpora Collection: From 100 to 200 Languages. In: Proceedings
of the 8th International Language Resources and Evaluation (LREC 2012), 2012.
