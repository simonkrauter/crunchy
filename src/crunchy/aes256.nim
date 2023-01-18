import std/bitops, std/endians

const
  Rcon = [0x0'u8, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36]
  SBox = [
    [0x63'u8, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76],
    [0xca'u8, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0],
    [0xb7'u8, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15],
    [0x04'u8, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75],
    [0x09'u8, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84],
    [0x53'u8, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf],
    [0xd0'u8, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8],
    [0x51'u8, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2],
    [0xcd'u8, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73],
    [0x60'u8, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb],
    [0xe0'u8, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79],
    [0xe7'u8, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08],
    [0xba'u8, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a],
    [0x70'u8, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e],
    [0xe1'u8, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf],
    [0x8c'u8, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16]
  ]

proc subWord(value: uint32): uint32 =
  var a = cast[array[4, uint8]](value)
  for i in 0 ..< 4:
    a[i] = SBox[(a[i] and 0xf0) shr 4][(a[i] and 0x0f)]
  cast[uint32](a)

proc rotWord(value: uint32): uint32 {.inline.} =
  rotateRightBits(value, 8)

proc keyExpansion(key: array[32, uint8]): array[60, uint32] =
  for i in 0 ..< 8:
    copyMem(result[i].addr, key[i * 4].unsafeAddr, 4)

  for i in 8 ..< 60:
    var tmp: uint32
    if i mod 8 == 0:
      tmp = subWord(rotWord(result[i - 1])) xor Rcon[i div 8]
    elif i mod 8 == 4:
      tmp = subWord(result[i - 1])
    else:
      tmp = result[i - 1]
    result[i] = result[i - 8] xor tmp

proc addRoundKey(
  state: var array[4, uint32],
  keys: array[60, uint32],
  keyOffset: int
) =
  var
    s = cast[array[4, array[4, uint8]]](state)
    k: array[4, array[4, uint8]]
  copyMem(k[0].addr, keys[keyOffset].unsafeAddr, 16)
  for i in 0 ..< 4:
    for j in 0 ..< 4:
      s[i][j] = s[i][j] xor k[j][i]
  copyMem(state[0].addr, s[0].addr, 16)

proc subBytes(state: var array[4, uint32]) =
  var s: array[4, array[4, uint8]]
  copyMem(s[0].addr, state[0].addr, 16)
  for i in 0 ..< 4:
    for j in 0 ..< 4:
      s[i][j] = SBox[(s[i][j] and 0xf0) shr 4][(s[i][j] and 0x0f)]
  copyMem(state[0].addr, s[0].addr, 16)

proc shiftRows(state: var array[4, uint32]) {.inline.} =
  state[1] = rotateRightBits(state[1], 8)
  state[2] = rotateRightBits(state[2], 16)
  state[3] = rotateRightBits(state[3], 24)

proc gf(a, b: uint8): uint8 =
  var
    a = a
    b = b
  for i in 0 ..< 8:
    if (b and 1) != 0:
      result = result xor a
    let highBitSet = (a and 0x80) != 0
    a  = a shl 1
    if highBitSet:
      a = a xor 0x1b
    b = b shr 1

proc mixColumns*(state: var array[4, uint32]) =
  let s = cast[array[4, array[4, uint8]]](state)
  var tmp: array[4, array[4, uint8]]
  for c in 0 ..< 4:
    tmp[0][c] = gf(0x02, s[0][c]) xor gf(0x03, s[1][c]) xor s[2][c] xor s[3][c]
    tmp[1][c] = s[0][c] xor gf(0x02, s[1][c]) xor gf(0x03, s[2][c]) xor s[3][c]
    tmp[2][c] = s[0][c] xor s[1][c] xor gf(0x02, s[2][c]) xor gf(0x03, s[3][c])
    tmp[3][c] = gf(0x03, s[0][c]) xor s[1][c] xor s[2][c] xor gf(0x02, s[3][c])
  state = cast[array[4, uint32]](tmp)

proc aes256EncryptBlock(
  roundKeys: array[60, uint32],
  src: pointer
): array[16, uint8] =
  var rowMajor: array[4, array[4, uint8]]
  copyMem(rowMajor[0].addr, src, 16)

  var columnMajor: array[4, array[4, uint8]]
  for c in 0 ..< 4:
    columnMajor[c][0] = rowMajor[0][c]
    columnMajor[c][1] = rowMajor[1][c]
    columnMajor[c][2] = rowMajor[2][c]
    columnMajor[c][3] = rowMajor[3][c]

  var state = cast[array[4, uint32]](columnMajor)

  addRoundKey(state, roundKeys, 0)

  for round in 1 ..< 14:
    subBytes(state)
    shiftRows(state)
    mixColumns(state)
    addRoundKey(state, roundKeys, round * 4)

  subBytes(state)
  shiftRows(state)
  addRoundKey(state, roundKeys, 56)

  for c in 0 ..< 4:
    var word: array[4, uint8]
    word[0] = cast[array[4, array[4, uint8]]](state)[0][c]
    word[1] = cast[array[4, array[4, uint8]]](state)[1][c]
    word[2] = cast[array[4, array[4, uint8]]](state)[2][c]
    word[3] = cast[array[4, array[4, uint8]]](state)[3][c]
    copyMem(result[c * 4].addr, word.addr, 4)

proc aes256gcmEncrypt*(
  key: array[32, uint8],
  iv: array[12, uint8],
  plaintext: string
): string =
  result.setLen(plaintext.len)

  let roundKeys = keyExpansion(key)

  var something: array[4, uint32]
  copyMem(something[0].addr, iv[0].unsafeAddr, 12)

  var counter = 2.uint32
  bigEndian32(something[3].addr, counter.addr)

  var pos: int
  while pos + 16 <= plaintext.len:
    let tmp = aes256EncryptBlock(roundKeys, something[0].addr)

    for i in 0 ..< 16:
      result[pos + i] = (plaintext[pos + i].uint8 xor tmp[i]).char

    pos += 16
    inc counter
    bigEndian32(something[3].addr, counter.addr)

  # Handle a partial block if one remains

  if pos < plaintext.len:
    let tmp = aes256EncryptBlock(roundKeys, something[0].addr)

    for i in 0 ..< plaintext.len - pos:
      result[pos + i] = (plaintext[pos + i].uint8 xor tmp[i]).char
