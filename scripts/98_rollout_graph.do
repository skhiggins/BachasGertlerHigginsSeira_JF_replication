** GRAPH ROLLOUT BASED ON BIMESTER OF SWITCH IN BANSEFI DATA
**  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 98_rollout_graph
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
// Control center
local language_list "en" // put "en" "es" to produce English and Spanish
local color = 0
local presentation = 0
//  (version in paper is color=0, presentation=0)

// Colors
if `color' {
	local c1 orange
	local c2 blue	
	local c3 ltblue
	local c4 gs7
}
else {
	local c1 gs7
	local c2 gs3
	local c3 gs10
	local c4 `c3'
}

// Size
if `presentation' {
	local labsize medlarge
	local with "w/"
	local without "w/o"
	local pres "_pres"
}
else {
	local labsize medsmall
	local with "with"
	local without "without"
	local pres ""
}

local plotregion plotregion(margin(zero) fcolor(white) lstyle(none) lcolor(white)) 
local graphregion graphregion(margin(zero) fcolor(white) lstyle(none) lcolor(white)) 

local program "Oportunidades"
local opcard_en   "`program' bank accounts `with' cards"
local opnocard_en "`program' bank accounts `without' cards"
local balances_en "Bansefi account balances and transactions"

local program ""
local opcard_es   "Cuentas bancarias `program'con tarjeta" 
local balances_es "Balances y transacciones en cuenta Bansefi" 
local opnocard_es "Cuentas bancarias `program'sin tarjeta"

**********
** DATA **
**********
clear
use "$proc/bim_switch_integrante.dta" // created in 8_bimswitch.do

count
tab bim_switch
drop if missing(bim_switch)
drop if bim_switch < 13 // not very many obs; we know first switching
	// occurred Jan-Feb 2009 which is where we see the first 
	// substantial mass in the distribution of bim_switch
drop if bim_switch==33 | bim_switch==48 // just 1 obs at 33, 37 at 48; max is 32
tab bim_switch

gen byte dummy = 1
collapse (count) switchers = dummy, by(bim_switch)

gen bimester_rollout = bim_switch + (2007-2002)*6 
	// will have Jan-Feb 2002 as =1
qui count 
set obs `=r(N)+1'
replace bimester_rollout = 1 in `=r(N)+1'
sort bimester_rollout
tsset bimester_rollout
tsfill 
qui count
set obs `=r(N)+2'
replace bimester_rollout = _n in `=r(N)+1'/`=r(N)+2'
recode switchers (. = 0) // pre-2009 bimesters
gen cum_switchers = sum(switchers)
format *switchers %10.0gc // comma separators
list bimester_rollout switchers cum_switchers
bimestrify , startyear(2002) alreadybim(bimester_rollout) short
	// !user! written ado
label list bimes

local inc    50000
local upper 350000

gen bansefi = `upper' if /// Jan 07-Oct 11
	(bimester_rollout>=31 & bimester_rollout<=60) 
		// note each endpoint is 1 more so it lines up correctly
gen mp = `upper' if /// Jun-Jul 12 (?)
	(bimester_rollout>=63 & bimester_rollout<=64)

// To get it to line up correctly
qui count
set obs `=r(N)+1'
	
	
gen xaxis = 0
	
summ bimester_rollout, meanonly
local min_bim = r(min)
local max_bim = r(max)
	
foreach lang of local language_list { // uncomment es to also do Spanish version
	label var cum_switchers "`opcard_`lang''"
	label var bansefi "`balances_`lang''"
	label var mp "`medios_`lang''"
	
	** BANSEFI GRAPH
	#delimit ;
	graph twoway
		(area bansefi bimester_rollout, color(`c1') lwidth(none) lcolor(`c1'))
		(line cum_switchers bimester_rollout, color(black) lwidth(thick))
		(line xaxis bimester_rollout, color(black) lwidth(medium))
		,
		xlabel(`min_bim'(2)`max_bim', nogrid valuelabel angle(vertical) labsize(medsmall)) 
		xtitle("") 
		ylabel(0(`inc')`upper', notick nogrid angle(horizontal) labsize(`labsize') format(%10.0fc))  ytitle("")
		legend(pos(12) ring(1) cols(1) size(`labsize') 
			symx(*0.6) rowgap(*.3) keygap(*0.6) colgap(*.01)
			order(2 1) 
			span
			region(margin(zero) lcolor(white))
		)
		`plotregion'
		`graphregion'
		name(bansefi, replace)
	;
	#delimit cr	
	
	graph export "$graphs/timing_bansefi_`lang'`pres'.eps", replace

}

*************
** WRAP UP **
*************
log close
exit
