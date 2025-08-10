import { BaseFilter } from './base_filter.js';

export class MultiSelectFilter extends BaseFilter {
    matches(rowValue) {
        return this.value.includes(rowValue);
    }
    
    getDisplayValue() {
        return this.value.join(', ');
    }
    
    populatePopup(popup) {
        this.value.forEach(val => {
            const checkbox = popup.querySelector(`input[value="${val}"]`);
            if (checkbox) checkbox.checked = true;
        });
    }
}