
capture program drop lower
program define lower
syntax [varlist] [, DEScribe]
foreach var of varlist `varlist' {
	capture rename `var' `= lower("`var'")'
}
if "`describe'"!="" {
	des
}
end
