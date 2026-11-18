// Usage: node native/tools/relay-crypto.mjs
// Writes native/fixtures/relay-crypto.json: fixed inputs and the bytes both apps must produce for
// the encrypted relay (docs/design/encrypted-relay-join.md). Node's own crypto makes the answers, so
// neither app is the reference; DoYourWorkCore's RelayCryptoTests and Android's RelayCryptoTest read it.
//
// The format, version 1:
//   family key   32 random bytes, made on the first phone; household id 16 random bytes.
//   subkeys      HKDF-SHA256(ikm = family key, salt = household id, info = "dyw1 enc" | "dyw1 row"), 32 bytes each.
//   sealed       base64( 0x01 ‖ nonce(12) ‖ AES-256-GCM ciphertext ‖ tag(16) ) under the enc subkey,
//                associated data = household id(16) ‖ kind (utf8) ‖ 0x00 ‖ row id (utf8).
//   state row id base64url, no padding, of HMAC-SHA256(row subkey, state key utf8): 43 characters.
//   join code    "dyw1:" + base64url, no padding, of household id(16) ‖ family key(32) ‖ token(32).
//   token hash   SHA-256(token), sent to the server as bytea; the token itself only to join.
import { createCipheriv, createHmac, createHash, hkdfSync } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const hex = s => Buffer.from(s, 'hex');
const b64url = b => Buffer.from(b).toString('base64url');

const familyKey = hex('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f');
const household = hex('a1b2c3d4e5f60718293a4b5c6d7e8f90');
const token = hex('f0e1d2c3b4a5968778695a4b3c2d1e0f00112233445566778899aabbccddeeff');

const sub = info => Buffer.from(hkdfSync('sha256', familyKey, household, Buffer.from(info, 'utf8'), 32));
const encKey = sub('dyw1 enc');
const rowKey = sub('dyw1 row');

const aad = (kind, rowId) => Buffer.concat([household, Buffer.from(kind, 'utf8'), Buffer.from([0]), Buffer.from(rowId, 'utf8')]);
function seal(kind, rowId, plaintext, nonce) {
  const c = createCipheriv('aes-256-gcm', encKey, nonce);
  c.setAAD(aad(kind, rowId));
  const body = Buffer.concat([c.update(Buffer.from(plaintext, 'utf8')), c.final()]);
  return Buffer.concat([Buffer.from([1]), nonce, body, c.getAuthTag()]).toString('base64');
}

const sealCases = [
  { kind: 'log', rowId: '1731700000000_ab12cd', nonce: '000000000000000000000001',
    plaintext: '{"id":"1731700000000_ab12cd","playerId":"1","playerName":"kid","choreId":"make-bed","choreName":"make bed","points":8,"minutes":5,"status":"pending","timestamp":1731700000000}' },
  { kind: 'state', rowId: '', nonce: 'ffffffffffffffffffffffff', plaintext: '' },
  { kind: 'state', rowId: 'x', nonce: '0102030405060708090a0b0c', plaintext: 'chores in your own words — émoji 🧹' },
].map(c => { c.rowId = c.rowId || b64url(createHmac('sha256', rowKey).update('players').digest()); return { ...c, sealed: seal(c.kind, c.rowId, c.plaintext, hex(c.nonce)) }; });

const rowIdCases = ['players', 'dare|3|2026-11-16', 'family', ''].map(key =>
  ({ key, rowId: b64url(createHmac('sha256', rowKey).update(Buffer.from(key, 'utf8')).digest()) }));

const out = {
  generatedBy: 'native/tools/relay-crypto.mjs',
  familyKey: familyKey.toString('hex'),
  household: household.toString('hex'),
  encKey: encKey.toString('hex'),
  rowKey: rowKey.toString('hex'),
  seal: sealCases,
  stateRowIds: rowIdCases,
  joinCode: {
    token: token.toString('hex'),
    code: 'dyw1:' + b64url(Buffer.concat([household, familyKey, token])),
    tokenHash: createHash('sha256').update(token).digest('hex'),
  },
};
writeFileSync(resolve(root, 'native/fixtures/relay-crypto.json'), JSON.stringify(out, null, 1) + '\n');
console.log('wrote native/fixtures/relay-crypto.json');
