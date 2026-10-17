import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import getLines from '@salesforce/apex/NFT_OrderLineController.getLines';

import PCT_CONFIRMED from '@salesforce/schema/Order.NFT_Pct_Confirmed__c';
import PCT_SHIPPED from '@salesforce/schema/Order.NFT_Pct_Shipped__c';
import PCT_INVOICED from '@salesforce/schema/Order.NFT_Pct_Invoiced__c';
import TOTAL_UNITS from '@salesforce/schema/Order.NFT_Total_Units__c';
import UNITS_CONFIRMED from '@salesforce/schema/Order.NFT_Units_Confirmed__c';
import UNITS_SHIPPED from '@salesforce/schema/Order.NFT_Units_Shipped__c';
import UNITS_INVOICED from '@salesforce/schema/Order.NFT_Units_Invoiced__c';
import LAST_MODIFIED from '@salesforce/schema/Order.LastModifiedDate';

const ORDER_FIELDS = [PCT_CONFIRMED, PCT_SHIPPED, PCT_INVOICED, TOTAL_UNITS, UNITS_CONFIRMED, UNITS_SHIPPED, UNITS_INVOICED, LAST_MODIFIED];
const FILTERS = ['Total', 'Pending', 'Confirmed', 'Partially Shipped', 'Shipped'];

function pillClass(done, total) {
    if (done >= total && total > 0) { return 'pill pill-good'; }
    if (done > 0) { return 'pill pill-warn'; }
    return 'pill pill-plain';
}

export default class NftOrderLineStatus extends NavigationMixin(LightningElement) {
    @api recordId;
    order;
    lines = [];
    error;
    loading = true;
    filter = 'Total';
    lastModified;
    wiredLines;

    @wire(getRecord, { recordId: '$recordId', fields: ORDER_FIELDS })
    wiredOrder({ data, error }) {
        if (data) {
            this.order = data;
            const lm = getFieldValue(data, LAST_MODIFIED);
            if (this.lastModified && lm !== this.lastModified && this.wiredLines) {
                refreshApex(this.wiredLines);
            }
            this.lastModified = lm;
        } else if (error) {
            this.error = this.reduce(error);
        }
    }

    @wire(getLines, { orderId: '$recordId' })
    wiredGetLines(result) {
        this.wiredLines = result;
        const { data, error } = result;
        if (data) {
            this.lines = data.map((l) => {
                const q = l.Quantity || 0;
                const c = l.NFT_Qty_Confirmed__c || 0;
                const s = l.NFT_Qty_Shipped__c || 0;
                const i = l.NFT_Qty_Invoiced__c || 0;
                return {
                    id: l.Id,
                    no: l.NFT_Line_No__c,
                    productId: l.Product2Id,
                    sku: l.Product2 ? l.Product2.ProductCode : '',
                    name: l.Product2 ? l.Product2.Name : '',
                    qty: q,
                    conf: `${c} / ${q}`, confClass: pillClass(c, q),
                    ship: `${s} / ${q}`, shipClass: pillClass(s, q),
                    inv: `${i} / ${q}`, invClass: pillClass(i, q),
                    status: l.NFT_Line_Status__c,
                    short: l.NFT_Short_Shipped__c,
                    waiting: q - s,
                    rowClass: l.NFT_Short_Shipped__c ? 'row-amber' : ''
                };
            });
            this.error = undefined;
            this.loading = false;
        } else if (error) {
            this.error = this.reduce(error);
            this.loading = false;
        }
    }

    reduce(error) {
        if (Array.isArray(error.body)) { return error.body.map((e) => e.message).join(', '); }
        return (error.body && error.body.message) || error.message || 'Something went wrong loading the order lines.';
    }

    num(field) { return this.order ? (getFieldValue(this.order, field) || 0) : 0; }
    pct(field) { return Math.round(this.num(field)); }

    get confirmedPct() { return this.pct(PCT_CONFIRMED); }
    get shippedPct() { return this.pct(PCT_SHIPPED); }
    get invoicedPct() { return this.pct(PCT_INVOICED); }
    get confirmedText() { return `${this.num(UNITS_CONFIRMED)} of ${this.num(TOTAL_UNITS)} units`; }
    get shippedText() { return `${this.num(UNITS_SHIPPED)} of ${this.num(TOTAL_UNITS)} units`; }
    get invoicedText() { return `${this.num(UNITS_INVOICED)} of ${this.num(TOTAL_UNITS)} units`; }
    get confirmedBar() { return `width:${this.confirmedPct}%`; }
    get shippedBar() { return `width:${this.shippedPct}%`; }
    get invoicedBar() { return `width:${this.invoicedPct}%`; }
    get shippedTileClass() {
        return this.shippedPct > 0 && this.shippedPct < 100 ? 'tile tile-partial' : 'tile';
    }

    get filters() {
        return FILTERS.map((f) => {
            const count = f === 'Total' ? this.lines.length : this.lines.filter((l) => l.status === f).length;
            return { value: f, label: `${f}: ${count}`, pressed: String(this.filter === f), cls: this.filter === f ? 'fpill fpill-on' : 'fpill' };
        });
    }

    get visibleLines() {
        return this.filter === 'Total' ? this.lines : this.lines.filter((l) => l.status === this.filter);
    }
    get hasLines() { return this.lines.length > 0; }
    get noVisibleLines() { return this.visibleLines.length === 0; }
    get shortLines() { return this.lines.filter((l) => l.short); }
    get hasShort() { return this.shortLines.length > 0; }

    handleFilter(event) { this.filter = event.currentTarget.dataset.value; }

    openProduct(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, objectApiName: 'Product2', actionName: 'view' }
        });
    }
}
