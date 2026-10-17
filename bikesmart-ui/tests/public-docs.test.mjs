import {test} from 'node:test'
import assert from 'node:assert/strict'
import {publicFiles,publicDocsMiddleware} from '../server/public-docs.mjs'
const response=()=>({statusCode:200,headers:{},setHeader(k,v){this.headers[k]=v},end(data){this.data=data}})
test('public allowlist includes guides and synthetic data, excludes operational reports',()=>{
 assert.equal(publicFiles.size,24)
 assert.equal([...publicFiles.values()].some(p=>p.includes('server/')||p.includes('service-log')||p.includes('maintenance.json')),false)
})
test('public route rejects private paths and traversal',async()=>{
 for(const url of ['/downloads/server/data/maintenance.json','/downloads/data/service-log.json','/downloads/%2e%2e%2fserver/api.mjs']){
  const res=response();await publicDocsMiddleware({url,method:'GET'},res,()=>{throw Error('Unexpected next')});assert.equal(res.statusCode,404)
 }
})
test('codebook downloads as an attachment; large movement files support HEAD',async()=>{
 const res=response();await publicDocsMiddleware({url:'/downloads/data/README.md',method:'GET'},res,()=>{})
 assert.ok(res.data.toString().includes('All bikes,'));assert.match(res.headers['Content-Disposition'],/attachment/)
 const head=response();await publicDocsMiddleware({url:'/downloads/data/jersey_city.csv.gz',method:'HEAD'},head,()=>{})
 assert.ok(head.headers['Content-Length']>1000000);assert.equal(head.data,undefined)
})
