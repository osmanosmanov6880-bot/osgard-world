import { readFileSync, statSync } from 'node:fs'
import { resolve, join } from 'node:path'
import { createHash } from 'node:crypto'

/**
 * No network or dynamic assets. Audit exactly the NASA-derived, same-origin
 * Earth imagery shipped with the reviewed release. Hard failure on tampering.
 */
const files = [
  ['earth-day-4096.jpg', 4096, 2048, '72b93d9af3c889617c1022d9541a57ce7e826aa2', 943204],
  ['earth-day-2048.jpg', 2048, 1024, '7ba17362d3ba4d515705bcbf839a5b65052e5d34', 265361],
  ['earth-night-2048.jpg', 2048, 1024, '4dcedcc464b9046fc1c40d9ed648784d3bfc7890', 133814],
  ['earth-clouds-2048.jpg', 2048, 1024, '86d8b2d16dbafbcb1aa5cd996cbab2b0afc9606b', 829367],
]

function jpegDimensions(bytes) {
  if (bytes[0] !== 0xff || bytes[1] !== 0xd8) throw Error('Not a JPEG')
  let i = 2
  while (i < bytes.length - 9) {
    if (bytes[i] !== 0xff) throw Error('Corrupt JPEG marker sequence')
    while (bytes[i] === 0xff) i++
    const marker = bytes[i++]
    if (marker === 0xd9 || marker === 0xda) break
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue
    const size = bytes.readUInt16BE(i)
    if (size < 2 || i + size > bytes.length) throw Error('Corrupt JPEG segment size')
    if ([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].includes(marker)) {
      return { width: bytes.readUInt16BE(i + 5), height: bytes.readUInt16BE(i + 3) }
    }
    i += size
  }
  throw Error('JPEG SOF header missing')
}

const root = resolve(process.argv[2] || 'public')
let total = 0
const outcomes = []
for (const [name, width, height, expectedHash, exactBytes] of files) {
  const path = join(root, 'brand', 'nasa', name)
  const bytes = readFileSync(path)
  const actual = jpegDimensions(bytes)
  const sha = createHash('sha1').update(Buffer.from('blob ' + bytes.length + '\0')).update(bytes).digest('hex')
  if (sha !== expectedHash) throw Error(name + ': file differs from reviewed NASA-origin copy')
  if (actual.width !== width || actual.height !== height) {
    throw Error(name + ': unexpected dimensions ' + JSON.stringify(actual))
  }
  if (bytes.length !== exactBytes || statSync(path).size !== exactBytes) throw Error(name + ': unexpected byte count')
  total += bytes.length
  outcomes.push({ file: name, width, height, bytes: bytes.length, integrity: 'verified' })
}
if (total > 2_600_000) throw Error('NASA imagery budget exceeded 2.6MB')
console.log(JSON.stringify({ status: 'pass', assets: outcomes, totalBytes: total, note: 'Static Earth image assets; no live weather or satellite streaming' }, null, 2))
