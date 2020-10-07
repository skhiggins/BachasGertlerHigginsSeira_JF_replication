** LOCALITY-LEVEL DISCRETE TIME HAZARD 

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 90_locality_discrete_time_table
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

**********
** DATA **
**********
use "$proc/locality_for_discretetime.dta", clear

#delimit ;
local locality_vars
	ln_pos_2008_1
	change_ln_pos
	ln_checking_2008
	change_ln_checking
	ln_branches_2008
	change_ln_branches
	ln_n_bansefi
	ln_atm_number
	ln_pobtot_2005
	partido_pan_2008
	change_partido_pan
	pct_illiterate
	pct_not_attending_school
	pct_primary_incomplete
	pct_no_health_ins
	pct_dirt_floor
	pct_no_toilet
	pct_no_water
	pct_no_plumbing         
	pct_no_electricity      
	pct_no_washer           
	pct_no_fridge 
;

local locality_var_titles 
	`"
	"Log point-of-sale terminals"
	"$\Delta$ Log point-of-sale terminals"
	"Log bank accounts"
	"$\Delta$ Log bank accounts"
	"Log commercial bank branches"
	"$\Delta$ Log commercial bank branches"
	"Log Bansefi bank branches"
	"Log commercial bank ATMs"
	"Log population"
	"Mayor $=$ PAN"
	"$\Delta$ Mayor $=$ PAN"
	"\% illiterate (age 15+)"
	"\% not attending school (age 6-14)"
	"\% without primary education (age 15+)"
	"\% without health insurance"
	"\% with dirt floor"
	"\% without toilet"
	"\% without water"
	"\% without plumbing"
	"\% without electricity"
	"\% without washing machine"
	"\% without refrigerator"
	"'
;
#delimit cr

foreach var of local locality_vars {
	local test_list `test_list' _b[`var'] =	
}
local test_list `test_list' 0
di "`test_list'"

preserve

// OPTION 1: Discrete time hazard with year dummies

local start_year = 2008
local end_year = 2012 // conditional on switching, 
	// everyone switched by 2012, so can end at 2011
gen expand_factor = 1 + year_switch - `start_year'
gen ever_switched = (!missing(year_switch))

keep if ever_switched

// note this is dropping those who didn't switch
expand expand_factor

sort localidad, stable
by localidad : gen t = _n 

by localidad : gen switching = (ever_switched == 1 & _n==_N)

tab t, gen(dum_t)

#delimit ;
// non-par;
regress switching dum_t* 
	`locality_vars'
	,
	nocons vce(cluster localidad)
;

// Model 1;
logit switching dum_t* /* set of time dummies */
	`locality_vars'
	, 
	nocons vce(cluster localidad)
;

// Model 2 ;
cloglog switching dum_t* /* set of time dummies */
	`locality_vars'
	, 
	nocons vce(cluster localidad) 
;
#delimit cr

restore

// OPTION 2: polynomial in time
gen bim_switch_key = .

local bimcount = 0
forval year = `start_year'/`end_year' {
	forval bim = 1/6 {
		if `year' == `start_year' & `bim' < 6 continue
		local ++bimcount
		replace bim_switch_key = `bimcount' if year_switch == `year' & bim_switch == `bim'
	}
}

tab bim_switch_key

gen ever_switched = !missing(bim_switch_key)
keep if !missing(bim_switch_key) // only those treated at some point
expand bim_switch_key 

sort localidad, stable
by localidad : gen t = _n  
by localidad : gen switching = ever_switched == 1 & _n==_N
	// last period in data for those who switched
	
// Polynomial 
local polynomial_degree = 5

tab t, gen(dum_t)

forvalues i = 1(1)`polynomial_degree' {
	gen t_`i' = t^`i'
}

//  linear; no time vars (as in Gertler et al 2016 AER)
regress switching `locality_vars', ///
	vce(cluster localidad)
	
	#delimit ;
	
// non-par
reg switching dum_t* /* polynomial in time */
	`locality_vars'
	, 
	vce(cluster localidad) 
;	
	
// linear with time vars ;
reg switching t_* /* polynomial in time */
	`locality_vars'
	, 
	vce(cluster localidad) 
;
	
//  Model 1 ;
logit switching t_* /* polynomial in time */
	`locality_vars'
	, 
	vce(cluster localidad) 
	iter(10) /* to break it if not converging */
;

//  Model 2	;
cloglog switching t_* /* polynomial in time */
	`locality_vars'
	, 
	vce(cluster localidad)
	iter(10) /* to break it if not converging */
;
#delimit cr

// Put it in a Latex table
local rows = wordcount("`locality_vars'")*2
matrix results = J(`rows', 4, .)
matrix pvalues = J(`rows', 4, .)
gen sample = (e(sample))

cap drop tag
sort sample localidad
by sample localidad: gen tag = (_n == 1) if sample==1

local row = 1
foreach var of local locality_vars {
	summ `var' if sample==1 & tag==1
	matrix results[`row', 1] = r(mean)
	matrix results[`row', 2] = r(sd)
	
	local row = `row' + 2
}

// linear with time vars 
#delimit ;
reg switching t_* /* polynomial in time */
	`locality_vars'
	, 
	vce(cluster localidad) 
;
#delimit cr
test `test_list'
local row = 1
foreach var of local locality_vars {
	matrix results[`row', 3] = _b[`var']
	matrix results[`=`row' + 1', 3] = _se[`var']
	matrix pvalues[`row', 3] = 2*ttail(e(df_r), abs(_b[`var']/_se[`var']))

	local row = `row' + 2
}

// Complementary log-log 
#delimit ;
cloglog switching t_* /* polynomial in time */
	`locality_vars'
	, 
	vce(cluster localidad)
	iter(10) /* to break it if not converging */
;
#delimit cr
test `test_list'
local row = 1
foreach var of local locality_vars {
	matrix results[`row', 4] = _b[`var']
	matrix results[`=`row' + 1', 4] = _se[`var']
	matrix pvalues[`row', 4] = 2*ttail(e(N_clust) - 1, abs(_b[`var']/_se[`var']))

	local row = `row' + 2
}

matlist results
matlist pvalues

local tablename "locality_discrete_time"

local varcount = 0
forval i=1/`=rowsof(results)' {
	if `i'==1 local _append "replace"
	else local _append "append"
	
	if mod(`i', 2) { // if odd number
		local ++varcount 
		local title : word `varcount' of `locality_var_titles'
		local info title("`title'")
	}
	else { // even
		local info extracols(1) brackets("()")
	}
	#delimit ;
	latexify results[`i', 1...] 
		using "tables/`tablename'.tex"
		,
		stars(pvalues[`i', 1...]) 
		`info' `_append'
		format("%4.2f %4.2f %5.4f %5.4f")
	;
	#delimit cr
}

*************
** WRAP UP **
*************
log close
exit

	