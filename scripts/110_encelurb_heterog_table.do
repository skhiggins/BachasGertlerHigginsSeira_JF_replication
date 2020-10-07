** HETEROGENEITY BY BARGAINING POWER
**  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 110_encelurb_heterog_table
cap log close
set linesize 200
log using "$logs/`project'`sample'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

**********
** DATA **
**********
foreach var in totcons {
	use "$proc/encel_heterogeneity_`var'.dta", clear // !data!

	local u "$tables/encel_heterogeneity_`var'_`time'.tex"
	
	mkmat *, matrix(results)
	
	qui count
	forval row = 1/`r(N)' {
		if `row' == 1 local _append "replace"
		else local _append "append"
		if mod(`row', 3) == 1 & `row' <= 6 { // past row 6 is N
			local _brackets ""
			local _stars "stars(results[`=`row'+2', 1...])"
			local _format `"format("%5.2f")"'
			if `row'==1 local _title `"title("Diff-in-diff")"'
			else local _title `"title("Diff-in-diff $\times \mathbb{I}(\text{Baseline barganing power} < \text{median})$")"'
			local _midrule ""
		}
		else if mod(`row', 3) == 2 & `row' <= 6 {
			local _brackets `"brackets("()")"'
			local _stars ""
			local _format `"format("%5.2f")"'
			local _title "extracols(1)"
			if `row' == 5 local _midrule "midrule"
			else local _midrule ""
		}
		else if `row' > 6 { // N
			local _brackets `"brackets("{}")"'
			local _stars ""
			local _format `"format("%4.0f")"'
			if `row'==7 local _title `"title("Number of households")"'
			else local _title `"title("Number of observations")"'
			local _midrule ""
		}
		else continue // pvalue rows
		latexify results[`row', 1...] using `u', ///
			doublenegative `_brackets' `_stars' `_format' `_title' `_midrule' `_append'
	}
}

*************
** WRAP UP **
*************
log close 
exit
