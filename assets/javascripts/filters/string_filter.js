import { BaseFilter } from './base_filter.js';

export class StringFilter extends BaseFilter {
    matches(rowValue) {
        const rv = (rowValue || '').toLowerCase();
        const v = (this.value || '').toLowerCase();
        switch (this.operator) {
            case 'contains': return rv.includes(v);
            case 'starts_with': return rv.startsWith(v);
            case 'ends_with': return rv.endsWith(v);
            case 'equal': return rv === v;
            case 'is_empty': return rv === '';
            case 'is_not_empty': return rv !== '';
            default: return false;
        }
    }
    
    populatePopup(popup) {
        super.populatePopup(popup);
        const input = popup.querySelector('.cf-filter-input');
        if (input) input.value = this.value;
    }
}