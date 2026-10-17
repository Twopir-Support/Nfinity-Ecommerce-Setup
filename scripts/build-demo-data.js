#!/usr/bin/env node
/**
 * NFT demo: writes data/*.json + data/nft-demo-data-plan.json for `sf data import tree`
 * from the NFT_DemoData_* static resources. Dates are offsets from the demo day, so
 * re-run this on (or just before) the day of a client demo:
 *
 *   node scripts/build-demo-data.js              dates from today
 *   node scripts/build-demo-data.js 2026-10-21   dates from a chosen demo day
 */
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const res = (n) => JSON.parse(fs.readFileSync(path.join(root, 'force-app/main/default/staticresources', n + '.json'), 'utf8'));
const out = path.join(root, 'data');
const CHUNK = 200; // sObject Tree API limit per request

const base = process.argv[2] ? new Date(process.argv[2] + 'T00:00:00') : new Date();
base.setHours(0, 0, 0, 0);
const pad = (n) => String(n).padStart(2, '0');
const day = (d) => { if (d == null) return undefined; const x = new Date(base); x.setDate(x.getDate() + d); return `${x.getFullYear()}-${pad(x.getMonth() + 1)}-${pad(x.getDate())}`; };
const stamp = (s) => { if (!s) return undefined; const x = new Date(base); x.setDate(x.getDate() + s.d); x.setHours(+s.t.slice(0, 2), +s.t.slice(3, 5), 0, 0); return x.toISOString(); };
const ref = (prefix, key) => prefix + '_' + String(key).replace(/[^A-Za-z0-9]/g, '_');
const clean = (o) => { Object.keys(o).forEach((k) => o[k] === undefined || o[k] === null ? delete o[k] : 0); return o; };
const rec = (type, referenceId, fields) => clean({ attributes: { type, referenceId }, ...fields });

const cat = res('NFT_DemoData_Catalog');
const orders = res('NFT_DemoData_Orders').orders;
const ful = res('NFT_DemoData_Fulfilment');
const logs = [1, 2, 3].flatMap((i) => res('NFT_DemoData_Logs' + i).logs);
const acc = Object.fromEntries(cat.accounts.map((a) => [a.key, a]));

const sets = [
  ['Product2', cat.products.map((p) => rec('Product2', ref('Prod', p.sku), {
    Name: p.name, ProductCode: p.sku, NFT_SKU__c: p.sku, NFT_Family__c: p.family, NFT_Style__c: p.style,
    NFT_Colour__c: p.colour, NFT_Size__c: p.size, IsActive: true }))],
  ['Account', cat.accounts.map((a) => { const shopify = a.source === 'Shopify'; const c = a.street ? 'US' : undefined; return rec('Account', ref('Acc', a.key), {
    Name: a.name, NFT_Customer_Key__c: a.key, NFT_Customer_Source__c: a.source, NFT_Rewards_Tier__c: a.tier,
    NFT_Shopify_Customer_Id__c: shopify ? a.key : undefined, NFT_Amazon_Buyer_Id__c: shopify ? undefined : a.key, Phone: a.phone,
    ShippingStreet: a.street, ShippingCity: a.city, ShippingState: a.state, ShippingPostalCode: a.zip, ShippingCountry: c,
    BillingStreet: a.street, BillingCity: a.city, BillingState: a.state, BillingPostalCode: a.zip, BillingCountry: c }); })],
  ['Contact', cat.accounts.map((a) => rec('Contact', ref('Con', a.key), {
    AccountId: '@' + ref('Acc', a.key), FirstName: a.first, LastName: a.last, Email: a.email, Phone: a.phone }))],
  ['NFT_Inventory_Balance__c', cat.balances.map((b) => rec('NFT_Inventory_Balance__c', ref('Bal', b.key), {
    Name: `${b.sku} – ${b.loc}`, NFT_Unique_Key__c: b.key, NFT_Product__c: '@' + ref('Prod', b.sku), NFT_Location__c: b.loc,
    NFT_Location_Type__c: b.type, NFT_Qty_On_Hand__c: b.oh, NFT_Qty_Reserved__c: b.res, NFT_Qty_Inbound__c: b.inb,
    NFT_Reorder_Point__c: b.rop, NFT_Last_Updated_At__c: stamp(b.upd) }))],
  ['Order', orders.map((o) => { const a = acc[o.cust]; const c = a.street ? 'US' : undefined; return rec('Order', ref('Ord', o.ext), {
    AccountId: '@' + ref('Acc', o.cust), Status: 'Draft', EffectiveDate: day(o.od.d),
    NFT_External_Order_Id__c: o.ext, NFT_Channel__c: o.ch, NFT_Fulfillment_Provider__c: o.prov, NFT_Fulfillment_Status__c: o.st,
    NFT_Payment_Status__c: o.pay, NFT_Shipping_Method__c: o.ship, NFT_Accounting_Status__c: o.acct, NFT_Received_At__c: stamp(o.od),
    NFT_Confirmed_At__c: stamp(o.conf), NFT_First_Shipped_At__c: stamp(o.fs), NFT_Delivered_At__c: stamp(o.del),
    NFT_Must_Ship_By__c: day(o.sb), NFT_Must_Deliver_By__c: day(o.db),
    ShippingStreet: a.street, ShippingCity: a.city, ShippingState: a.state, ShippingPostalCode: a.zip, ShippingCountry: c }); })],
  ['OrderItem', orders.flatMap((o) => o.lines.map((l) => rec('OrderItem', ref('Line', o.ext + '-' + l.no), {
    OrderId: '@' + ref('Ord', o.ext), Product2Id: '@' + ref('Prod', l.sku), Quantity: l.q, UnitPrice: l.p,
    NFT_Line_No__c: l.no, NFT_Line_Key__c: o.ext + '-' + l.no,
    NFT_Qty_Confirmed__c: l.c, NFT_Qty_Shipped__c: l.s, NFT_Qty_Invoiced__c: l.i }))) ],
  ['NFT_Shipment__c', ful.shipments.map((s) => rec('NFT_Shipment__c', ref('Shp', s.trk), {
    Name: s.name, NFT_Tracking_Number__c: s.trk, NFT_Order__c: '@' + ref('Ord', s.ord), NFT_Account__c: '@' + ref('Acc', s.cust),
    NFT_Provider__c: s.prov, NFT_Carrier__c: s.car, NFT_Sequence__c: s.seq, NFT_Units__c: s.u, NFT_Contents__c: s.cont,
    NFT_Status__c: s.st, NFT_Shipped_At__c: stamp(s.sa), NFT_Expected_Delivery__c: day(s.exp), NFT_Delivered_At__c: stamp(s.da) }))],
  ['NFT_Invoice__c', ful.invoices.map((i) => rec('NFT_Invoice__c', ref('Inv', i.ref), {
    Name: i.name, NFT_Accounting_Seed_Ref__c: i.ref, NFT_Order__c: '@' + ref('Ord', i.ord), NFT_Account__c: '@' + ref('Acc', i.cust),
    NFT_Invoice_Date__c: day(i.d), NFT_Amount__c: i.amt, NFT_Status__c: i.st }))],
  ['NFT_Sync_Log__c', logs.map((l) => rec('NFT_Sync_Log__c', ref('Log', l.id), {
    NFT_External_Event_Id__c: l.id, NFT_Record_Ref__c: l.ref, NFT_System__c: l.sys, NFT_Event__c: l.ev, NFT_Status__c: l.st,
    NFT_Message__c: l.msg, NFT_Logged_At__c: stamp(l.at), NFT_Attempts__c: 1, NFT_Order__c: l.ord ? '@' + ref('Ord', l.ord) : undefined }))],
];

fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out);
const plan = [];
let total = 0;
for (const [sobject, records] of sets) {
  const files = [];
  for (let i = 0; i < records.length; i += CHUNK) {
    const name = records.length > CHUNK ? `${sobject}-${files.length + 1}.json` : `${sobject}.json`;
    fs.writeFileSync(path.join(out, name), JSON.stringify({ records: records.slice(i, i + CHUNK) }, null, 2) + '\n');
    files.push(name);
  }
  plan.push({ sobject, saveRefs: true, resolveRefs: true, files });
  total += records.length;
  console.log(`${sobject.padEnd(26)} ${String(records.length).padStart(5)}  ${files.join(', ')}`);
}
fs.writeFileSync(path.join(out, 'nft-demo-data-plan.json'), JSON.stringify(plan, null, 2) + '\n');
console.log(`${'TOTAL'.padEnd(26)} ${String(total).padStart(5)}  demo day ${day(0)}  ->  data/nft-demo-data-plan.json`);
