// REGRESSIONS BY SPENDING CATEGORY -- TABLE

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 95_encelurb_bycategory_table
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

*******************
** PRELIMINARIES **
*******************
graph_options, plot_margin(margin(sides))

************
** LOCALS **
************
local temptation "Temptation goods"
local other_food "Other food & drinks"
local non_durables "Other non-durable goods"
local educhealth "Education and health"
local services_mes "Other services"

#delimit ;
local outcomelist_cats /* just the big categories */
	temptation 
	other_food
	non_durables
	educhealth
	services_mes
;
#delimit cr

// tokenize
local i = 0
foreach cat_ of local outcomelist_cats {
	// for the table, need to replace & with \&
	local `cat_'_ = subinstr("``cat_''", "&", "\&", .)
	
	local ++i
	local `i' `cat_'
	local ++i // for the standard errors
	local ++i // for the pvalues row
	local ++i // for the randinf pvalues row
}

**********
** DATA **
**********
// Table
use "$proc/encel_bycategory_results.dta", clear // !data!

local u "$tables/encel_bycategory_`time'.tex"

drop outcome
mkmat *, matrix(results)

count
forval row = 1/`r(N)' {
	if `row' == 1 local _append "replace"
	else local _append "append"
	if mod(`row', 4) == 1 {
		local _brackets ""
		local _title `"title("{```row''_'}")"' 
		local _stars "stars(results[`=`row'+2', 1...])"
	}
	else if mod(`row', 4) == 2 {
		local _brackets `"brackets("()")"'
		local _title "extracols(1)"
		local _stars ""
	}
	else if mod(`row', 4) == 0 { // randinf pvalues 
		local _brackets `"brackets("[]")"'
		local _title "extracols(1)"
		local _stars ""	
	}
	else continue
	latexify results[`row', 1...] using `u', ///
		format("%4.3f" "%4.3f" "%4.3f" "%5.0fc" "%5.0fc") ///
		doublenegative `_brackets' `_title' `_stars' `_append'
}

*************
** WRAP UP **
*************
log close
exit
