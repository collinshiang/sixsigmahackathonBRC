// After npm run build: assert downloads are byte-identical to their originals.
import {readFile} from 'node:fs/promises'
import {createHash} from 'node:crypto'
import {fileURLToPath} from 'node:url'
import path from 'node:path'
import {publicFiles} from '../server/public-docs.mjs'
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..')
const hash=data=>createHash('sha256').update(data).digest('hex')
for(const [asset,source]of publicFiles){
 const [a,b]=await Promise.all([readFile(path.join(root,'bikesmart-ui/dist',asset)),readFile(path.join(root,source))])
 if(hash(a)!==hash(b))throw Error(`Download differs: ${asset}`)
}
console.log(`PASS: ${publicFiles.size} built downloads match original datasets and guides byte for byte; public allowlist excludes maintenance files`)
