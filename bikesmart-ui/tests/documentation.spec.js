import {test,expect} from '@playwright/test'
import {readFile} from 'node:fs/promises'
import {createHash} from 'node:crypto'
const hash=data=>createHash('sha256').update(data).digest('hex')
test('public documentation preserves rider selection and offers original synthetic downloads',async({page,request})=>{
 const errors=[];page.on('pageerror',error=>errors.push(error.message))
 await page.goto('/')
 await page.getByRole('button',{name:'Rent a Bike',exact:true}).click()
 await page.getByRole('button',{name:'Find pickup docks',exact:true}).click()
 const dock=await page.locator('.optimizer-card').first().getAttribute('data-dock')
 await page.locator('.optimizer-card').first().click()
 await page.getByRole('button',{name:'Documentation',exact:true}).click()
 await expect(page.getByRole('heading',{name:/Understand your ride/})).toBeVisible()
 await expect(page.getByRole('navigation',{name:'Documentation contents'})).toBeVisible()
 await page.getByRole('link',{name:/Synthetic data & downloads/}).click()
 await expect(page.getByText('All bike activity and zoning are synthetic.')).toBeVisible()
 const downloading=page.waitForEvent('download');await page.getByRole('link',{name:'R data frame (.rds)'}).first().click()
 const download=await downloading
 expect(download.suggestedFilename()).toBe('jersey_city.rds')
 expect(hash(await readFile(await download.path()))).toBe(hash(await readFile(new URL('../../data/jersey_city.rds',import.meta.url))))
 await page.getByRole('link',{name:/Statistical foundations/}).click()
 await expect(page.getByRole('heading',{name:'1. Arrival-time dock projection'})).toBeVisible()
 await page.screenshot({path:test.info().outputPath('documentation-desktop.png'),fullPage:true})
 await page.getByRole('button',{name:'Back to your ride'}).click()
 await expect(page.locator('.optimizer-card.selected')).toHaveAttribute('data-dock',dock)
 expect((await request.get('/api/maintenance/report?city=jersey_city')).status()).toBe(401)
 expect((await request.get('/downloads/server/data/maintenance.json')).status()).toBe(404)
 expect(errors).toEqual([])
})
test('documentation is readable on mobile and full guides download publicly',async({page,request})=>{
 await page.setViewportSize({width:390,height:844});await page.goto('/')
 await page.getByRole('button',{name:'Documentation',exact:true}).click()
 await expect(page.getByRole('heading',{name:/Understand your ride/})).toBeVisible()
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth)).toBe(true)
 const guides=page.getByRole('link',{name:'Download full project guide',exact:true})
 await expect(guides).toHaveCount(6)
 for(const guide of await guides.all()){
  const result=await request.get(await guide.getAttribute('href'))
  expect(result.ok()).toBe(true);expect(await result.text()).toContain('**Current demonstration:** BikeSmart')
 }
 await page.getByRole('link',{name:/Synthetic data & downloads/}).click()
 await page.screenshot({path:test.info().outputPath('documentation-mobile.png'),fullPage:true})
})
