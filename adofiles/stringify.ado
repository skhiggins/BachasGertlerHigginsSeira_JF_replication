** PROGRAM TO ADD ZEROS (OR OTHER CHARACTERS) TO BEGINNING OF STRING
**  e.g. if ID numbers are ten digits with up to 3 zeros, but in the data set
**  those zeros are missing, this command adds the zeros back in
** Sean Higgins
** Created August 2015
*! v1.0 skh 9oct2015

capture program drop stringify
program define stringify
	syntax varlist , digits(real) [add(string) replace gen(string)]
	if "`add'"=="" local add "0" // add 0s to beginning
	if "`gen'"!="" {
		assert wordcount("`varlist'")==wordcount("`gen'")
		tokenize `gen'
	}
	local i=0
	foreach var of local varlist {
		local ++i
		tempvar s_`var' l_`var' toadd
		if !strpos("`: type `var''","str") { // not a string var
			qui tostring `var', gen(`s_`var'')
		}
		else {
			qui gen str `s_`var'' = `var'
		}
		qui gen `l_`var'' = length(`s_`var'')
		cap assert `l_`var''>=`digits' 
		while _rc {
			qui replace `s_`var'' = "`add'" + `s_`var'' if `l_`var''<`digits' 
			qui replace `l_`var'' = length(`s_`var'')
			cap assert `l_`var''>=`digits'
		}
		if "`gen'"!="" {
			qui gen str ``i'' = `s_`var''
		}
		else {
			drop `var' 
			qui gen str `var' = `s_`var''
		}
	}
end
