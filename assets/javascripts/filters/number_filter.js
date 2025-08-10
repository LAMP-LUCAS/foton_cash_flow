import { BaseFilter } from './base_filter.js';

export class NumberFilter extends BaseFilter {
    constructor(operator, value1, value2, operatorText) {
        super(operator, value1, operatorText);
        this.value2 = value2;
    }
    
    matches(rowValue) {
        const rv = parseFloat(rowValue);
        if (isNaN(rv)) return false;
        const v1 = parseFloat(this.value);
        const v2 = parseFloat(this.value2);
        switch (this.operator) {
            case 'equal': return rv === v1;
            case 'greater_than': return rv > v1;
            case 'less_than': return rv < v1;
            case 'between': return rv >= v1 && rv <= v2;
            default: return false;
        }
    }
    
    getDisplayValue() {
        if (this.operator === 'between') return `${this.value} e ${this.value2}`;
        return this.value;
    }
    
    populatePopup(popup) {
        super.populatePopup(popup);
        popup.querySelector('input[name="filter_value_1"]').value = this.value;
        if (this.operator === 'between') {
            popup.querySelector('input[name="filter_value_2"]').value = this.value2;
        }
    }
}