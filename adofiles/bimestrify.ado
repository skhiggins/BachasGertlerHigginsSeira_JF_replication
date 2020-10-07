
// Program to turn bimester of year (1,...,6) and year into a 
//  variable that counts up, e.g. if the starting year is 2007,
//  year=2007, bimester=1 --> `gen' = 1 
//  year=2009, bimester=3 --> `gen' = (2*6)+3 = 15
capture program drop bimestrify
program define bimestrify
	syntax , STARTyear(real) ///
		[bim(string) year(string) gen(string) alreadybim(string) short]
	if "`gen'"!="" {
		confirm new var `gen'
		gen `gen' = `bim' + 6*(`year'-`startyear')
			// so in `staryear' it will be 1,2,3,4,5,6
			// in `startyear'+1 it will be 7,8,9,10,11,12
			// etc.
	}
	else {
		confirm variable `alreadybim'
		local gen `alreadybim'
		tempvar year
		gen `year' = `startyear' + ceil(`gen'/6) - 1
	}
	
	if "`short'"=="" local starter "Jan-Feb `=substr("`startyear'",3,2)'"
	else local starter "Jan `=substr("`startyear'",3,2)'"

	quietly summ `gen', meanonly
	local max_bimestre = r(max) // bimestre is code for the new variable
	local min_bimestre = r(min)
	tokenize `c(Mons)' // "Jan Feb Mar..."
	forval m=1/12 { // months 
		if mod(`m',2) local odd_months  `odd_months'  ``m''
		else          local even_months `even_months' ``m'' 
	}
	local t=0
	foreach month of local odd_months {
		local ++t
		local _`t' `month'
	} // manual tokenize for `_1' instead of `1'
	local t=0
	foreach month of local even_months {
		local ++t 
		local `t'_ `month'
	}
	forval i=`min_bimestre'/`max_bimestre' {
		local j = mod(`i',6) + 6*(mod(`i',6)==0) // so 1,2,3,4,5,6
		if "`yy'"=="" { // made this change to deal with no obs. bimesters
			summ `year' if `gen'==`i', meanonly
			local yy = substr(string(r(mean)),3,2)		
		}
		else if `j'==1 { 
			local yy = string(`yy' + 1)
			if length("`yy'") == 1 local yy = "0`yy'"
		}
		else {
			// else if "`yy'"!="" & `j'>1, keep `yy' the same
		}
		if "`short'"=="" {
			local label_add `label_add' `i' "`_`j''-``j'_' `yy'"
			if `i'==1 & "`starter'"=="" local starter "`_`j''-``j'_' `yy'"
		}
		else {
			local label_add `label_add' `i' "`_`j'' `yy'"
			if `i'==1 & "`starter'"=="" local starter "`_`j'' `yy'"		
		}
	}
	label var `gen' "Bimester where 1=`starter'"
	cap label drop bimes
	label define bimes `label_add'
	label values `gen' bimes
end

