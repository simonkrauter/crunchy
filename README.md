# Crunchy

![Github Actions](https://github.com/guzba/crunchy/workflows/Github%20Actions/badge.svg)

`nimble install crunchy`

[API reference](https://nimdocs.com/guzba/crunchy)

## About

Crunchy provides pure Nim implementations of common hashes and data integrity checks (cyclic redundancy checks and checksums). These implementations are intended to be high-performance, including amd64 and arm64 SIMD implementations or using instruction set intrinsics.

Function | Scalar | SIMD: | amd64 | arm64
---       | ---   | ---   | ---   | ---:
SHA-256   | ✅   |       |  ✅   | ⛔
CRC-32    | ✅   |       |  ✅   | ✅
CRC-32C   | ⛔   |       |  ✅   | ⛔
Adler-32  | ✅   |       |  ✅   | ✅

Crunchy is a new repo so keep an eye on releases for more functions and SIMD optimization.

## Examples

Runnable examples using Crunchy can be found in the [examples/](https://github.com/guzba/crunchy/blob/master/examples) folder.

Here is a basic example that prints the hex-encoded SHA-256 of a string:

```nim
import crunchy

let data = "The quick brown fox jumps over the lazy dog"
echo sha256(data).toHex()
```

Or calculating the CRC-32 of a string:

```nim
import crunchy

let data = "The quick brown fox jumps over the lazy dog"
echo crc32(data)
```

Now, lets say you want to compute the CRC-32 of a file. Many approaches are possible, but lets look at these two:

First, the easy way. Just read the file into memory and compute:
```nim
import crunchy

let data = readFile("tests/data/zlib.rfc")
echo crc32(data)
```

Alternatively, to avoid copying the file, memory-map the file and compute instead:
```nim
import crunchy, std/memfiles

var memFile = memfiles.open("tests/data/zlib.rfc")
echo crc32(memFile.mem, memFile.size)
memFile.close()
```

Memory-mapping the file is great if the file is very large or you want to avoid copying a large file's contents. This uses Crunchy's pointer + len API.

## Testing

`nimble test`
