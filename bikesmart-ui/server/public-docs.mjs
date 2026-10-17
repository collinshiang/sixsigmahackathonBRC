// Explicit public assets only: synthetic research data and documentation.
// Maintenance reports, journals, authentication and fleet bundles stay private.
import {readFile,stat} from 'node:fs/promises'
import path from 'node:path'
import {fileURLToPath} from 'node:url'
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..')
const guides=['README.md','01_PROJECT_PURPOSE_AND_USERS.md','02_TOOL_COMPONENTS_AND_FUNCTIONS.md','03_CITY_ONBOARDING_AND_INPUT_REQUIREMENTS.md','04_TEST_DATASETS_AND_DEMONSTRATIONS.md','05_STATISTICAL_FOUNDATIONS_AND_FORMULAS.md','06_JUDGING_RUBRIC_ALIGNMENT.md']
export const publicFiles=new Map(guides.map(name=>[`downloads/documentation/${name}`,`documentation/${name}`]))
for(const name of ['README.md','CITY_INPUT_REQUIREMENTS.md'])publicFiles.set(`downloads/data/${name}`,`data/${name}`)
for(const city of ['jersey_city','milwaukee','tampa']){
 for(const suffix of ['csv.gz','rds'])publicFiles.set(`downloads/data/${city}.${suffix}`,`data/${city}.${suffix}`)
 for(const type of ['stations','distances','zoning'])publicFiles.set(`downloads/data/${type}/${city}.csv`,`data/${type}/${city}.csv`)
}
export async function publicDocsMiddleware(req,res,next){
 let pathname
 try{pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname).replace(/^\//,'')}catch{return next()}
 if(!pathname.startsWith('downloads/'))return next()
 const source=publicFiles.get(pathname)
 if(!source||!['GET','HEAD'].includes(req.method)){res.statusCode=404;res.end('Not found');return}
 try{
  const filename=path.join(root,source),info=await stat(filename)
  res.setHeader('Content-Type',source.endsWith('.gz')?'application/gzip':source.endsWith('.md')?'text/plain; charset=utf-8':'application/octet-stream')
  res.setHeader('Content-Length',info.size)
  res.setHeader('Content-Disposition',`attachment; filename="${path.basename(source)}"`)
  res.setHeader('X-Content-Type-Options','nosniff')
  res.end(req.method==='HEAD'?undefined:await readFile(filename))
 }catch{res.statusCode=404;res.end('Download unavailable')}
}
export function publicDocsPlugin(){return{
 name:'bikesmart-public-documentation',
 configureServer(server){server.middlewares.use(publicDocsMiddleware)},
 async generateBundle(){for(const [fileName,source]of publicFiles)this.emitFile({type:'asset',fileName,source:await readFile(path.join(root,source))})},
}}
