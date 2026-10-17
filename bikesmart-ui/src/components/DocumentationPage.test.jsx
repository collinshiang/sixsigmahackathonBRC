import React,{useState} from 'react'
import {describe,it,expect,vi} from 'vitest'
import {render,screen,fireEvent,cleanup,within} from '@testing-library/react'
import {afterEach} from 'vitest'
vi.mock('./OptimizerHome',()=>({default:function Planner(){const [dock,setDock]=useState('');return <label>Saved rider choice<input value={dock} onChange={e=>setDock(e.target.value)}/></label>}}))
vi.mock('../services/maintenance',()=>({maintenanceRequest:vi.fn().mockResolvedValue({authenticated:false})}))
import App from '../App'
import DocumentationPage from './DocumentationPage'
afterEach(cleanup)
describe('public BikeSmart documentation',()=>{
 it('preserves the rider planner while opening and closing documentation without login',async()=>{
  render(<App/>);
  fireEvent.change(screen.getByLabelText('Saved rider choice'),{target:{value:'Water & Wisconsin'}})
  fireEvent.click(screen.getByRole('button',{name:'Documentation'}))
  expect(await screen.findByRole('heading',{name:/Understand your ride/})).toBeVisible()
  expect(screen.queryByLabelText('Password')).not.toBeInTheDocument()
  fireEvent.click(screen.getByRole('button',{name:'Back to your ride'}))
  expect(screen.getByLabelText('Saved rider choice')).toHaveValue('Water & Wisconsin')
 })
 it('provides six guide sections, synthetic disclosures, original data downloads and occupancy policy',()=>{
  render(<DocumentationPage onBack={()=>{}}/>);
  const nav=screen.getByRole('navigation',{name:'Documentation contents'})
  expect(within(nav).getAllByRole('link').filter(a=>a.hash)).toHaveLength(6)
  expect(screen.getByText('All bike activity and zoning are synthetic.')).toBeVisible()
  expect(screen.getByText(/Projections, eligibility, road-distance ranks and occupancy-based discounts are calculated in R/)).toBeVisible()
  for(const city of ['jersey_city','milwaukee','tampa']){
   for(const suffix of ['csv.gz','rds'])expect(document.querySelector(`a[href="/downloads/data/${city}.${suffix}"]`)).toHaveAttribute('download')
  }
  expect(screen.getAllByText('Download full project guide')).toHaveLength(6)
  expect(screen.getByRole('table')).toHaveTextContent('25% to below 50%10%')
  expect(screen.getByText(/not automatically applied to the rider's exported inventory/)).toBeVisible()
 })
})
