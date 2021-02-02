** SUPPLY SIDE REGRESSIONS
**  Sean Higgins
**  Created 05aug2015

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 111_supplyside_table
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local dayspermonth = 365/12
local write = 1 // write to Latex

local nquarters = 6

// For latex tables
local lag0 "Current quarter"
forval i=1/`nquarters' {
	local lag`i' "`i' quarter lag"
}

local lead_lag_list ""
local ll = `nquarters'
while `ll'>=0 { // lags
	local lead_lag_list `lead_lag_list' has_card_L`ll'
	local ll = `ll' - 1
}
forval ll=1/`nquarters' { // leads
	local lead_lag_list `lead_lag_list' has_card_F`ll'
}

**********
** DATA **
**********
use "$proc/cnbv_supply.dta", clear
destring cve_mun, replace
xtset cve_mun yearmonth
keep if yearmonth<=201112 // restrict to period of study 
// Before 201103, data was quarterly; restrict to quarterly after 201103 as well
gen month = substr(string(yearmonth),5,2)
drop if !inlist(month,"03","06","09","12") // quarters are "03","06","09","12"

// Can't use cuentaahorro (number of savings accounts)
//  because method changed in 201104 and after that the total number of savings accounts counted
//  by CNBV changed from 57,000 to 130 (?!)
// Double checked that this problem wasn't our mistake: it exists in the raw CNBV .xlsm file
summ bm_cuentaahorro if yearmonth>=201104 & yearmonth<=201212
summ bm_cuentaahorro if yearmonth<201104

*****************
** REGRESSIONS **
*****************
local nrows = (`nquarters'*2 + 1)*2 + 5 
	// `nquarters'*2 is for leads and lags
	// +1 is for current period
	// *2 is for beta and se
	// +5 is control mean, F-test and p-value lags, F-test and p leads
matrix results = J(`nrows',4,.)
matrix pvalues = J(`nrows',4,.)
recode *cajeros (. = 0) if !missing(total_sucursales) 
recode *sucursales (. = 0) if !missing(total_cajeros) 
local col = 0
foreach prefix in total bansefi {
	foreach suffix in cajeros sucursales {
		local ++col
		local row = 0
		local depvar `prefix'_`suffix'
		xtreg `depvar' i.yearmonth `lead_lag_list', fe vce(cluster cve_mun)
		tab yearmonth if e(sample)
		forval i=0/`nquarters' {
			local ++row
			matrix results[`row',`col'] = _b[has_card_L`i']
			matrix pvalues[`row',`col'] = ///
				2*ttail(e(df_r),abs(_b[has_card_L`i']/_se[has_card_L`i']))
			local ++row
			matrix results[`row',`col'] = _se[has_card_L`i']
		}
		forval i=1/`nquarters' {
			local ++row
			matrix results[`row',`col'] = _b[has_card_F`i']
			matrix pvalues[`row',`col'] = ///
				2*ttail(e(df_r),abs(_b[has_card_F`i']/_se[has_card_F`i']))
			local ++row
			matrix results[`row',`col'] = _se[has_card_F`i'] 
		}
		local ++row 
		matrix results[`row',`col'] = _b[_cons]
		foreach x in L F {
			local totest`x' ""
			forval i=1/`nquarters' {
				local totest`x' `totest`x'' _b[has_card_`x'`i'] = 
			}
			local totest`x' `totest`x'' 0 // F-test of = 0
			test `totest`x''
			local ++row 
			matrix results[`row',`col'] = r(F)
			local ++row
			matrix results[`row',`col'] = r(p)
		}
	}
}
matlist results

***************
** FOR LATEX **
***************
local tt=1
local title`tt'   "Current quarter"
forval i=1/`nquarters' {
	local tt = `tt' + 2
	local title`tt'   "`i' quarter lag"
}
forval i=1/`nquarters' {
	local tt = `tt' + 2 
	local title`tt'   "`i' quarter lead"
}
local tt = `tt' + 2
local meanrow = `tt'
local title`tt'  "Mean control group"
local ++tt
local Frow1 = `tt'
local title`tt'  "F-test of lags"
local ++tt
local title`tt'  "{[p-value]}"
local ++tt
local Frow2 = `tt'
local title`tt'  "F-test of leads"
local ++tt
local title`tt'  "{[p-value]}"
if `write' {
	global writeto "$tables/supplyside_`date'.tex"
	local u using ${writeto}
	local o extracols(1) 
	forval r=1/`=rowsof(results)' {
		if `r'==1 local append ""
		else local append append
		if `r'==`meanrow' local format %5.2f
		else local format %4.2f
		if `r'==`=`meanrow'-1' local midrule midrule
		else local midrule ""
		if (mod(`r',2) == 1 & `r'<=`meanrow') | ///
			`r'==`Frow1' | ///
			`r'==`Frow2' { // if odd
				latexify results[`r',1...] `u', ///
					stars(pvalues[`r',1...]) ///
					title("`title`r''") format(`format') ///
					`append' `midrule'
		}
		else if mod(`r',2) == 0 { // if even
			latexify results[`r',1...] `u', `o' brackets("()") format(`format') `append' `midrule'
		}
		else if `r'==`=`Frow1'+1' | `r'==`=`Frow2'+1' {
			latexify results[`r',1...] `u', ///
				title("`title`r''") brackets("[]") ///
				format(`format') `append' `midrule'
		}
	}
}

*************
** WRAP UP **
*************
log close
exit
