** DATA PREP FOR TESTING EXPANSION OF SUCURSALES, BRANCHES, SAVINGS ACCOUNTS IN CNBV DATA
** Sean Higgins
** Created 04aug2015

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 51_cnbv_bm_sucursales
set linesize 200
cap log close
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

*********
** DATA *
*********
local files : dir "$data/CNBV/BancaMultiple/" files "*.csv" 

foreach file of local files {
	di "`file'"
	
	// READ IN DATA
	qui insheet using "$data/CNBV/BancaMultiple/`file'", clear
	drop if mi(cve_mun)
	dupcheck cve_mun, assert
	
	// CONVERT MONTHLY VARIABLES TO REALS, FIX NAME
	ds v*
	local first_v = word(`"`r(varlist)'"',1) // " // first var with generic v[0-9]+ name
	local re_yearmonth = regexm("`: var label `first_v''","([0-9][0-9][0-9][0-9])([0-9][0-9])")
	local year = real(regexs(1))
	local month = real(regexs(2)) 

	foreach var of varlist v* {
		// Convert from string to real:
		local t_`var' : type `var'
		if strpos("`t_`var''","str") destring `var', replace ignore(",")

		// Make sure has non-missing values; if not drop
		qui count if !mi(`var')
		if r(N)==0 drop `var'
		else {
			// Change var name:
			**   (Note infix called them v4,... but saved the original variable name
			**   e.g. 201505 in the variable label for MOST variables but not all so I had
			**   to do the following work-around)
			local s_month = `month'
			if length("`s_month'")==1 local s_month = "0" + "`s_month'" // 01,...,12
			local yearmonth = `year'`s_month'
			rename `var' v`yearmonth'
			** for next iteration of loop:
			if `yearmonth'>201103 /// when the data is monthly 
				local month = `month' - 1 
			else /// when the data is quarterly
				local month = `month' - 3
			if `month'<=0 { // previous year
				local month = 12 + `month' // so if month was -1 and we subtracted 3, now month = 10
				local year = `year' - 1
			}
		}
	}

	local newfile = lower(regexr("`file'","(\.csv$)","_month.dta"))
	cap drop __* // for some reason it wasn't dropping the tempvars before saving
	save "$proc/`newfile'", replace
}

*************
** WRAP UP **
*************
log close
exit

