export class BaseFilter {
    constructor(operator, value, operatorText) {
        this.operator = operator;
        this.value = value;
        this.operatorText = operatorText;
    }
    
    getDisplayValue() { 
        return this.value; 
    }
    
    matches(rowValue) { 
        throw new Error("Method 'matches()' must be implemented."); 
    }
    
    populatePopup(popup) {
        const opSelect = popup.querySelector('.cf-filter-operator');
        if (opSelect) opSelect.value = this.operator;
    }
}