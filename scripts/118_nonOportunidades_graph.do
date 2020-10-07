** AS A PLACEBO TEST FOR CHANGING TRANSACTION COSTS OVER TIME,
**  LOOK AT SAVINGS OVER TIME OF NON-OPORTUNIDADES DEBICUENTA ACCOUNTS
** Sean Higgins
** 23dec2017

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 118_nonOportunidades_graph
cap log close
set linesize 200
log using "$logs/`project'`sample'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
// Control center
local depvar ending_balance 
local timevar cuatrimester
local startyear 2007
local alpha .05

// GRAPH FORMATTING
// For graphs:
graph_options, ///
	labsize(medlarge) /// 
	plot_margin(margin(sides)) ///
	x_angle(angle(vertical))

***************
** FUNCTIONS **
***************
// Label the months
cap program drop label_months
program define label_months
	syntax varlist, [Months(real -1) STARTyear(integer 2007) ENDyear(integer 2015)]
	tokenize `c(Mons)'
	local mm = 0
	if `months'==-1 local months = .
	forval year=`startyear'/`endyear' {
		forval m=1/12 {
			local mm = (`year' - `startyear')*12 + `m'
			if `mm'<=`months' ///
				local month_label `month_label' `mm' "``m'' `year'"
		}
	}
	cap label drop months
	label define months `month_label'
	foreach var of varlist `varlist' {
		label values `var' months
	}
end

**********
** DATA **
**********
use "$proc/nonOp_endbalance.dta", clear 
merge m:1 cuenta using "$proc/cuenta_sucursal.dta"
assert _merge != 1 
keep if _merge == 3
drop _merge
uniquevals cuenta // 21k, non-Oportunidades accounts opened
uniquevals sucadm // 130

stringify month, digits(2) gen(month_string)
stringify year, digits(4) gen(year_string)
describe
gen date_string = year_string + month_string + "01"
gen date = date(date_string, "YMD")
	
label_months month_counter

// Keep the ones opened prior to 2009 since we'll be looking at savings 
//  over 2009-2011
merge m:1 cuenta using "$proc/DatosGenerales.dta"
assert _merge != 1
uniquevals cuenta if _merge==2
uniquevals cuenta if _merge==3
drop integranteid // not defined for the lotteries accounts
keep if _merge == 3
drop _merge

gen date_opened = date(fecalta, "YMD")
tab sucadm

// Merge in locality of branch for clustering
merge m:1 sucadm using "$proc/branch_loc.dta"
drop if _merge == 2
// Assume the few problem ones are in distinct locs
//  (innocuous since there are few)
replace branch_clave_loc = sucadm if _merge == 1
uniquevals branch_clave_loc
uniquevals sucadm
drop _merge

bysort cuenta : gen tag = (_n==1)
gen year_opened = year(date_opened)
bysort year_opened : tab sucadm if tag 

uniquevals cuenta // 5k, non-Oportunidades accounts opened 2007

label_months month_counter, startyear(`startyear')
label list months

if "`timevar'" == "cuatrimester" {
	local start =  8
	local end   = 15
	
	gen cuatrimester = round((month_counter - 1)/4) + 1 
		// this makes the cuatrimester variable the same as in the rest
		//  of the paper
	tab cuatrimester month_counter if month_counter < 60
	
	sort cuenta
	by cuenta: assert sucadm == sucadm[1] // doesn't change w/in cuenta
	by cuenta: assert year_opened == year_opened[1] // ditto
	collapse (mean) `depvar', by(cuenta branch_clave_loc year_opened cuatrimester)
}
else {
	local start = 25
	local end   = 58
}
 
// Sample selection
uniquevals cuenta
keep if year_opened == 2007
uniquevals cuenta

winsify `depvar', winsor(5) timevar(`timevar') gen(`depvar'_w)

matrix results = J(`=`end'-`start'+1', 11, .)

local row = 0
forval m = `start'/`end' { // from beg of 2009 to end of other data
	local ++row
	matrix results[`row', 1] = `m'
	// Not winsorized
	reg `depvar' /// against constant for mean 
		if cuatrimester == `m', ///
		vce(cluster branch_clave_loc)
	local df = e(df_r)
	matrix results[`row', 2] = _b[_cons]
	matrix results[`row', 3] = _se[_cons]
	matrix results[`row', 4] = 2*ttail(`df', ///
		abs(_b[_cons]/_se[_cons]) ///
	)
	matrix results[`row', 5] = _b[_cons] - ///
		invttail(`df',`=`alpha'/2')*_se[_cons]
	matrix results[`row', 6] = _b[_cons] + ///
		invttail(`df',`=`alpha'/2')*_se[_cons]
	// Winsorized
	reg `depvar'_w /// against constant for mean
		if cuatrimester == `m', ///
		vce(cluster branch_clave_loc)
	local df = e(df_r)
	matrix results[`row', 7] = _b[_cons]
	matrix results[`row', 8] = _se[_cons]
	matrix results[`row', 9] = 2*ttail(`df', ///
		abs(_b[_cons]/_se[_cons]) ///
	)
	matrix results[`row', 10] = _b[_cons] - ///
		invttail(`df',`=`alpha'/2')*_se[_cons]
	matrix results[`row', 11] = _b[_cons] + ///
		invttail(`df',`=`alpha'/2')*_se[_cons]
	
}
matrix colnames results = "cuatrimester" ///
	"b_`depvar'" "se_`depvar'" "p_`depvar'" ///
		"rcap_lo_`depvar'" "rcap_hi_`depvar'"	///
	"b_`depvar'_w" "se_`depvar'_w" "p_`depvar'_w" ///
		"rcap_lo_`depvar'_w" "rcap_hi_`depvar'_w"
		
matlist results
	
clear
svmat results, names(col)

foreach var in b p rcap_lo rcap_hi {	
	rename `var'_`depvar'_w `var'
}

#delimit ;
label define cuatrimesters 
	 8 "Mar-Jun 2009"
	 9 "Jul-Oct 2009"
	10 "Nov 2009-Feb 2010" 
	11 "Mar-Jun 2010"
	12 "Jul-Oct 2010"
	13 "Nov 2010-Feb 2011"
	14 "Mar-Jun 2011"
	15 "Jul-Oct 2011"
;
label values cuatrimester cuatrimesters;

graph twoway 
	(scatter b cuatrimester if p<0.05,           `estimate_options_95') 
	(scatter b cuatrimester if p>=0.05 & p<0.10, `estimate_options_90') 
	(scatter b cuatrimester if p>=0.10,          `estimate_options_0' ) 
	(rcap rcap_hi rcap_lo cuatrimester if p<0.05,           `rcap_options_95')
	(rcap rcap_hi rcap_lo cuatrimester if p>=0.05 & p<0.10, `rcap_options_90')
	(rcap rcap_hi rcap_lo cuatrimester if p>=0.10,          `rcap_options_0' )
	, 
	ylabel(0(400)2000, `ylabel_options') 
	yscale(range(0 .))
	xtitle("", `xtitle_options')
	xlabel(8(1)15, `xlabel_options') 
	xscale(range(8 15))
	`plotregion' `graphregion'
	legend(off) 
;
#delimit cr

graph export "$graphs/nonOportunidades_saving`sample'_`time'.eps", replace
	
*************
** WRAP UP **
*************
log close
exit
