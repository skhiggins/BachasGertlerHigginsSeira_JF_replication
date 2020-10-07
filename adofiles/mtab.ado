capture program drop mtab
program define mtab
	syntax varlist [if] [in] [pw fw aw iw] [, NOLabel Freqonly DIsplay]
	if "`freqonly'"=="" {
		foreach var of varlist `varlist' {
			if "`display'"!="" {
				display "" 
				mydi "`var'"
			}
			tab `var' `if' `in' [`weight' `exp'], m `nolabel'
		}
	}
	else { // freqonly
		foreach var of varlist `varlist' {
			if "`display'"!="" {
				display ""
				mydi "`var'"
			}
			tab `var' `if' `in' [`weight' `exp'], mi summ(`var') nome nost `nolabel'
		}
	}
end
