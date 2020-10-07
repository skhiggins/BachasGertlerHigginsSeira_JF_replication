// CREATE Z-SCORE OF A VARIABLE OR VARIABLES
// Sean Higgins

cap program drop myzscore
program define myzscore
	syntax varlist [pw aw iw fw] [if] [in], [gen(string) replace]
	if "`exp'"!="" local aw [aw `exp']
	if wordcount("`varlist'")>1 local s s
	if "`gen'"=="" & "`replace'"=="" {
		di as text "New variable`s' generated with stub z_"
		foreach var of varlist `varlist' {
			local gen `gen' z_`var'
		}
	}
	if "`gen'"!="" & "`replace'"!="" {
		di as error in smcl "Cannot specify both {bf:gen} and {bf:replace} options"
	}
	if "`replace'"!="" {
		local action replace
		foreach var of varlist `varlist' {
			local gen `gen' `var'
		}
	}
	else local action gen double
	cap assert wordcount("`varlist'") == wordcount("`gen'")
	if _rc { // if error
		di as error in smcl "Must specify same number of variables in {bf:gen} option"
		exit
	} 
	tokenize "`gen'"
	local i=1
	foreach var of varlist `varlist' {
		qui summ `var' `aw' `if' `in' [`weight' `exp']
		qui `action' ``i'' = (`var'-r(mean))/r(sd) `if' `in'
		local ++i
	}
end

