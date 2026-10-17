import { createElement } from 'lwc';
import NftOrderLineStatus from 'c/nftOrderLineStatus';
import { getRecord } from 'lightning/uiRecordApi';
import getLines from '@salesforce/apex/NFT_OrderLineController.getLines';

jest.mock('@salesforce/apex/NFT_OrderLineController.getLines', () => {
    const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
    return { default: createApexTestWireAdapter(jest.fn()) };
}, { virtual: true });

const ORDER = { fields: {
    NFT_Pct_Confirmed__c: { value: 100 }, NFT_Pct_Shipped__c: { value: 66.67 }, NFT_Pct_Invoiced__c: { value: 33.33 },
    NFT_Total_Units__c: { value: 3 }, NFT_Units_Confirmed__c: { value: 3 }, NFT_Units_Shipped__c: { value: 2 },
    NFT_Units_Invoiced__c: { value: 1 }, LastModifiedDate: { value: '2026-10-17T10:00:00.000Z' } } };
const LINES = [
    { Id: '802A1', NFT_Line_No__c: '01', Product2Id: '01tA1', Product2: { ProductCode: 'APEX-WHT-07', Name: 'Apex Cheer Shoe – White – 7' },
      Quantity: 2, NFT_Qty_Confirmed__c: 2, NFT_Qty_Shipped__c: 1, NFT_Qty_Invoiced__c: 0, NFT_Line_Status__c: 'Partially Shipped', NFT_Short_Shipped__c: true },
    { Id: '802A2', NFT_Line_No__c: '02', Product2Id: '01tA2', Product2: { ProductCode: 'SHBP-TEA-OS', Name: 'Shimmer Backpack – Teal' },
      Quantity: 1, NFT_Qty_Confirmed__c: 1, NFT_Qty_Shipped__c: 1, NFT_Qty_Invoiced__c: 1, NFT_Line_Status__c: 'Shipped', NFT_Short_Shipped__c: false }
];

const flush = () => Promise.resolve();

describe('c-nft-order-line-status', () => {
    afterEach(() => { while (document.body.firstChild) { document.body.removeChild(document.body.firstChild); } });

    function build() {
        const el = createElement('c-nft-order-line-status', { is: NftOrderLineStatus });
        el.recordId = '801A1';
        document.body.appendChild(el);
        getRecord.emit(ORDER);
        getLines.emit(LINES);
        return el;
    }

    it('renders tiles and both lines', async () => {
        const el = build();
        await flush();
        const values = [...el.shadowRoot.querySelectorAll('.tile-value')].map((n) => n.textContent);
        expect(values).toEqual(['100%', '67%', '33%']);
        expect(el.shadowRoot.querySelectorAll('tbody tr').length).toBe(2);
        expect(el.shadowRoot.querySelectorAll('tr.row-amber').length).toBe(1);
    });

    it('filters to partially shipped lines', async () => {
        const el = build();
        await flush();
        el.shadowRoot.querySelector('button[data-value="Partially Shipped"]').click();
        await flush();
        expect(el.shadowRoot.querySelectorAll('tbody tr').length).toBe(1);
    });
});
