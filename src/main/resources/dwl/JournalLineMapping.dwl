%dw 2.0
output application/json
fun getDocument(lines) = 
	lines reduce (line, currentValue = '') -> if (currentValue != '') currentValue else line.'order-header-num'

fun checkCanada(accountType) = 
	startsWith(accountType, "CA") 

fun getTotal(header,line) =
	if (checkCanada(header.'account-type-name')) getCANLedgerTotal(header,line) else getUSLedgerTotal(line)

fun checkLegerTotalCanadaTaxCode (taxCode) =
	['PST-MB', 'PST-SK'] contains taxCode

fun getUSLedgerTotal(line) = 
	(line.total as Number default 0) + (line.'distributed-tax-amount' as Number default 0) 
	+ (line.'distributed-shipping-amount' as Number default 0) + (line.'distributed-handling-amount' as Number default 0) 
	+ (line.'distributed-misc-amount' as Number default 0) // + sum(line.taxLines.amount default[])

fun getCANLedgerTotal(header,line) = 
	(line.total as Number default 0) + (if(checkLegerTotalCanadaTaxCode(header.'header-tax-code')) (line.'distributed-tax-amount' as Number default 0) else 0)
	+ (line.'distributed-shipping-amount' as Number default 0) + (line.'distributed-handling-amount' as Number default 0) 
	+ (line.'distributed-misc-amount' as Number default 0) + sum(line.taxLines[?(checkLegerTotalCanadaTaxCode($.code))].amount default[])
	
fun getSplitTotal(lineSplit) = 
	(lineSplit.'account-allocation-amount' as Number default 0) + (lineSplit.'distributed-shipping-amount' as Number default 0) 
	+ (lineSplit.'distributed-handling-amount' as Number default 0) + (lineSplit.'distributed-misc-amount' as Number default 0)
	+ (lineSplit.'distributed-tax-amount' as Number default 0)

fun getVendorTaxGroup(header, lines) =
	if(startsWith(header.'account-type-name', "CA")) "Ex Exempt"
	else if((header.total - header.'Taxable Amount') !=0) "ST on Inv" else getTaxGroup(lines) 
	
fun getTaxGroup(lines) = 
	lines reduce (line, currentValue = "Ex Exempt") -> 
	if (currentValue == "SA Self A") currentValue else if (line.selfassessed_tax_code != "") "SA Self A" else "Ex Exempt" 

fun getLegerTaxGroup(header, line) =
	if(startsWith(header.'account-type-name', "CA")) "Ex Exempt"
	else 
		if(line.selfassessed_tax_code != "") "SA Self A" else "" //Vendor line.Tax Group

fun getLegerItemTaxGroup(header, line) =
	if(startsWith(header.'account-type-name', "CA")) "" 
	else 
		if(line.selfassessed_tax_code != "") line.selfassessed_tax_code else ""
---
vars.records map ((header) -> {
	Company: header.'account-type-name',
	Credit: if (header.total >= 0) header.total else 0,
	Debit: if (header.total < 0) header.total else 0,
	AccountType: 2,
	Account: header.'supplier-number',
	AccountTypeReal: 2,
	Currency: header.currency,
	Document: getDocument(header.lines),
	DocumentDate: header.'invoice-date',
	Invoice: header.'invoice-number',
	PaymentTerm: header.'payment-term',
	TaxGroup: getVendorTaxGroup(header, header.lines), 
	TransactionDate: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss"},
	Description: (header.'supplier-name' replace "Stericycle" with "") ++ header.'invoice-number',
	ActualTax: 0,
	CalcuatedTax: 0,
	(headerTaxLine: {
		Account: "SST01-10-199-999-0970",
	  	OffsetAccount: "SST02-10-199-999-0970",
	  	AccountType: "0",
	  	AccountTypeReal: "0",
	  	ActualTax: 0,
	  	CalculatedTax: 0,
	  	Credit: if((header.total - header.'Taxable Amount') < 0) abs(header.total - header.'Taxable Amount') else 0,
	  	Currency: header.currency,
	  	Debit: if((header.total - header.'Taxable Amount') >= 0) (header.total - header.'Taxable Amount') else 0,
		Description: (header.'supplier-name' replace "Stericycle" with "") ++ header.'invoice-number',
	 	TaxGroup: getVendorTaxGroup(header, header.lines), 
	  	ItemTaxGroup: "",
        TransactionDate: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss"}
	}) if((header.total - header.'Taxable Amount') !=0),
    lines: header.lines map ((line) -> {
        Account: if(line.'segment-6' !='') line.'segment-6' else line.'account-code',
        AccountType: if(line.'segment-6' !='') 3 else 0,
        AccountTypeReal: if(line.'segment-6' !='') 3 else 0,
        ActualTax: if (line.'selfassessed_tax_code' == "") 0 else getTotal(header, line) * (line.'selfassessed_tax_rate' as Number default 0)/100,
        CalculatedTax: if (line.'selfassessed_tax_code' == "") 0 else getTotal(header, line) * (line.'selfassessed_tax_rate' as Number default 0)/100,
        Credit: if (header.total < 0) getTotal(header, line) else 0,
        Currency: header.currency,
        Debit: if (header.total >= 0) getTotal(header, line) else 0,
        Description: (header.'supplier-name' replace "Stericycle" with "") ++ header.'invoice-number',
        OffsetAccount: "",
        OffsetAccountType: "",
        (ProjectCategory: "Expense") if (line.'segment-6' !=''),
      	(ProjectLineProperty: "No Charge") if (line.'segment-6' !=''),
        TaxGroup: getLegerTaxGroup(header, line),
        ItemTaxGroup: getLegerItemTaxGroup(header, line),
        TransactionDate: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss"},
     	(lineSplits: line.lineSplits map((lineSplit) -> {
	     	Account: lineSplit.'account-code',
	        AccountType: 0,
	        AccountTypeReal: 0,
	        ActualTax: if (lineSplit.'selfassessed_tax_code' == "") 0 else getTotal(header, lineSplit) * (lineSplit.'selfassessed_tax_rate' as Number default 0)/100,
	        CalculatedTax: if (lineSplit.'selfassessed_tax_code' == "") 0 else getTotal(header, lineSplit) * (lineSplit.'selfassessed_tax_rate' as Number default 0)/100,
	        Credit: if (header.total < 0) getSplitTotal(lineSplit) else 0,
	        Currency: header.currency,
	        Debit: if (header.total >= 0) getSplitTotal(lineSplit) else 0,
	        Description: (header.'supplier-name' replace "Stericycle" with "") ++ header.'invoice-number',
	        TaxGroup: getLegerTaxGroup(header, lineSplit),
	        ItemTaxGroup: getLegerItemTaxGroup(header, lineSplit),
	        TransactionDate: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss"}
     	})) if(sizeOf(line.lineSplits) > 0)
	})
})