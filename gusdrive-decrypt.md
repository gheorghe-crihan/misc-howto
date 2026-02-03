# Decrypting the gusdrive.cry

Simple XOR encryption, byte swapped.

It's almost obvious from the way the cyphertext is structured. One could count
the symbol frequencies and observe the most frequent ones CR/LF and space.
That is, the text is DOS ASCII Assembly language source file, so
`0xD`, `0xA` and `0x20`.

As the author has mentioned, there should be more than 1400 of CR/LFs.
Even more spaces, about x7 that many, given the frequency of characters in
an x86 assembly source text.
Besides, in the old times, the uppercase characters were most commonly used
for assembly instructions in INTEL syntax. The instruction character set was
somewhat limited and with very pronounced frequency patterns.

One could count the frequencies using the following simple script:

```python
from collections import Counter

text = None
with open("GUSDRIVE.CRY", "rb") as f:
    text = f.read()

freq = Counter(text)

for symbol, count in freq.items():
    print("%02X %d" % (symbol, count))
```

The key: `*-`

We use the following script to decrypt it:
https://github.com/AlexFSmirnov/xor-decrypt/blob/master/xor-decrypt.py

Decrypting:
```sh
$ python3 ./xor-decrypt.py -i "GUSDRIVE.CRY" -o “GUSDRIVE.SWAB” -k "*-" -d
```

Swapping the bytes back:
```sh
$ dd if=GUSDRIVE.SWAB of=GUSDRIVE.ASM conv=swab
```

The original archive here:
https://github.com/gheorghe-crihan/misc-howto/GUSDRV2.ZIP

The decrypted source code here:
https://github.com/gheorghe-crihan/misc-howto/GUSDRIVE.ASM

