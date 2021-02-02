** COMPARE THE POINT ESTIMATES FROM OUR STUDY TO THOSE OF OTHER STUDIES

** Created by Sean Higgins, Jan 2017
** Research assistance by Joel Ferguson

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 96_comparison_figure
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
// List of studies
local a = 0 // counter
#delimit ;
local auth_list
	ashraf06
	drexler14
	dupas13
	dupas16
	karlan12
	karlan16
	karlan17
	kast14
	kast16
	prina15
	schaner16
	seshan14
	somville16
	/* our paper: */
	thispaper
;
#delimit cr
tokenize `auth_list'
local estimate_list "" 

// Durations
scalar weeks_per_month = 52/12

// For results display
local b "Savings rate"
local se "Standard error"

// Matrix for results
	// Columns will be: 
	//  1) beta
	//  2) se
	//  3) conf interval low
	//  4) conf interval high
	//  5) p-value
matrix savingsrates = J(30,5,.)
local rr = 0 // row counter
local b_col  1
local se_col 2
local lo_col 3
local hi_col 4
local p_col  5
matrix colnames savingsrates = "b" "se" "lo" "hi" "p"
scalar _alpha = 0.05 // significance level

// For graph
local rcap_options_0  lcolor(gs7)   lwidth(thin) horizontal
local rcap_options_90 lcolor(gs7)   lwidth(thin) horizontal
local rcap_options_95 lcolor(black) lwidth(thin) horizontal
local rcap_options_95_orange lcolor(orange) lwidth(thin) horizontal
local estimate_options_0  mcolor(gs7)   msymbol(Oh) msize(medsmall)
local estimate_options_90 mcolor(gs7)   msymbol(O)  msize(medsmall)
local estimate_options_95 mcolor(black) msymbol(O)  msize(medsmall)
local estimate_options_95_orange mcolor(orange) msymbol(O)  msize(medsmall)
local labsize medium
local plotregion plotregion( /** margin(t+2 b+2) */ fcolor(white) color(white) lstyle(none) lcolor(white)) 
local graphregion graphregion(fcolor(white) color(white) lstyle(none) lcolor(white)) 

******************************
** ESTIMATES FOR EACH STUDY **
******************************
// Reset study counter to 0
local a = 0

// Metadata from studies to merge in later
clear
import excel using "$data/comparison/savings_rates_metadata.xlsx", ///
	firstrow allstring
lower

// Get rid of any trailing spaces
foreach var of varlist article year extra {
	cap set_rc // to get _rc!=0
	while _rc {
		replace `var' = regexr(`var'," $","")
		cap assert !regexm(`var'," $") if !mi(`var')
	}
}

// Create a metadata variable with author, year, and any extra info
gen AuthorYear = article
replace AuthorYear = article + " (" + year + ")" if !mi(year) & mi(extra)
replace AuthorYear = article + " (" + extra + ")" if mi(year) & !mi(extra)
replace AuthorYear = article + " (" + year + ")" + " (" + extra + ")" ///
	if !mi(year) & !mi(extra)
tempfile tomerge 
save `tomerge', replace

************************
** ASHRAF ET AL. 2006 **
************************
/* NOTES
	This is the Advances in Economic Analysis & Policy paper on 
	deposit collectors; their 2006 QJE paper doesn't have income
	or consumption to estimate savings rate
*/
local ++a
local auth "``a''"
local months = 12 // Always use annual income as denominator 

local T ""

scalar _b_ =   163.520 // Table 6, household total savings
					   //  (May 2016 version; couldn't get published)
scalar _se_ =  289.632 
scalar _df_ = 10 - 1 - 1 - 1 // just 10 clusters; 
	// 1 for control for baseline savings balance, 
	// 1 for constant, 
	// 1 for treatment dummy

scalar _denom_ = 1.298*100000/12 // Table 1, column 2 of Dec 2015 version
	// (annual household income in hundreds of thousands of pesos)
	
local ++rr
local rownames `rownames' `auth'
foreach est in b se {
	scalar _`est'_`auth'_`T' = _`est'_`T'/(_denom_`T'*`months')
	di as text _n "``est'' for `T': " 
	di as result _`est'_`auth'_`T'
	local estimate_list "`estimate_list' _`est'_`auth'_`T'"
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}
scalar _lo_`auth'_`T' = _b_`auth'_`T' - invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _hi_`auth'_`T' = _b_`auth'_`T' + invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _p_`auth'_`T'  = 2*ttail(_df_,abs(_b_`auth'_`T'/_se_`auth'_`T')) 
foreach est in lo hi p {
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}

************************
** DREXLER ET AL 2014 **
************************
/* NOTES:
	The microdata doesn't have income or consumption, or even 
	microenterprise profits, so we use total microenterpise	sales.
	We also don't know exactly how long after baseline each 
	individual is surveyed, but we know it is at least 12 months (p.9)
	so we use 12 months as the time over which savings were accumulated
*/
local ++a
local auth "``a''"
local months = 12

// Read in replication data
use "$data/comparison/Drexler_etal_2014_AEJApplied/kisDataFinal.dta", clear

// Controls used in paper
global controls i_bus1 i_bus2 i_bus3 i_bus4 monto_dese savings

** Replicate their results for savings
regress e_save b_save treat_* $controls ///
	if e_busOwn==1, cluster(barrio)
regress e_saveTotal_w01 b_saveTotal_w01 treat_* $controls ///
	if e_busOwn==1, cluster(barrio)
	** note these results match Table 2 of Drexler, Fischer, Schoar 2014	
assert e(N)==661 // make sure same sample as in their paper
	// (see "Savings amount" row of Table 2)
foreach T of varlist treat_* {
	scalar _b_`T' = _b[`T']
	scalar _se_`T' = _se[`T']
	scalar _df_`T' = e(df_r)
	** Microenterprise sales [no total income or even profits] of treated:
	summ e_salesAvgMo_w01 if e(sample) & `T'==1, meanonly
	scalar _denom_`T' = r(mean)
}

** Pooled treatment effect
regress e_saveTotal_w01 b_saveTotal_w01 treat $controls ///
	if e_busOwn==1, cluster(barrio)
local T treat
scalar _b_`T' = _b[`T']
scalar _se_`T' = _se[`T']
scalar _df_`T' = e(df_r)
** Microenterprise sales [no total income or even profits] of treated:
summ e_salesAvgMo_w01 if e(sample) & `T'==1, meanonly
scalar _denom_`T' = r(mean)

foreach T of varlist /* treat_* */ treat {
	local ++rr 
	local rownames `rownames' `auth'_`T'
	foreach est in b se {
		scalar _`est'_`auth'_`T' = _`est'_`T'/(_denom_`T'*`months')
		di as text _n "``est'' for `T': " 
		di as result _`est'_`auth'_`T'
		local estimate_list "`estimate_list' _`est'_`auth'_`T'"
		matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
	}
	scalar _lo_`auth'_`T' = _b_`auth'_`T' - invttail(_df_`T',_alpha/2)*_se_`auth'_`T'
	scalar _hi_`auth'_`T' = _b_`auth'_`T' + invttail(_df_`T',_alpha/2)*_se_`auth'_`T'
	scalar _p_`auth'_`T'  = 2*ttail(_df_`T',abs(_b_`auth'_`T'/_se_`auth'_`T')) 
	foreach est in lo hi p {
		matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
	}
}

*****************************
** DUPAS AND ROBINSON 2013 **
*****************************
/* NOTES: 
	1) There are three separate treatment groups that get a savings mechanism
	(account or lockbox) so these are the three we look at. There is also a fourth
	treatment group health_pot but we don't estimate an effect for that group since
	they don't get a savings mechanism where we can measure their savings. And when
	we estimate the pooled treatment effect, we do not include the health pot arm
	as treated. (The result is we get a higher savings effect excluding it, 
	0.78% of income rather than 0.59%)

	2) This is the AER paper; the AEJ Applied focuses on the logbooks which only
	have total deposits, not net savings; tried to construct net savings from the 
	bank admin data in their microdata but got insane values (e.g. Ksh 5 million in
	savings; savings effect > income even with 5% trimming)
*/
local ++a
local auth "``a''"
local weeks = 52 // number of weeks for the 12-month effects

// Read in replication data
use "$data/comparison/Dupas_Robinson_2013_AER/HARP_ROSCA_final.dta", clear

drop if has_followup2!=1 // (as in paper)

// Create a savings variable for "formal" (in the lockbox or account) savings.
//  In the data set there are separate variables for each type of lockbox/account
gen savings = 0 // did this because we want 0, not missing, for those
	// in the control group
replace savings = savings + fol2_sb_amt_in_box if safe_box == 1 & !missing(fol2_sb_amt)
	// it has "savings + " so that if they receive multiple treatments
	//  it adds up the different savings 
	// and !missing(.) so that it would remain as 0 if they have 
	//  a missing value
replace savings = savings + fol2_l_amt_in_box if locked_box == 1 & !missing(fol2_l_amt)
replace savings = savings + fol2_hsacc_balance if health_savings == 1 & !missing(fol2_hsacc_balance)

local treatment_groups safe_box locked_box health_savings // health_pot excluded;
	// see explanation above under NOTES

/* NOTE: In the paper, for savings they only look at savings balances conditional
	on opening the account. So we are not directly replicating a regression from the 
	paper, but we use the same controls they do for the results in Table 3 */
regress savings /// dependent variable
	safe_box locked_box health_pot health_savings multitreat /// treatment dummies
	rosbg_monthly_contrib i.strata /// additional controls they use in the paper for Table 3
	, cluster(id_harp_rosca) // cluster robust standard errors
// as a double check, make sure the number of observations matches paper:
assert e(N)==771 // number of observations in regression (Table 3)
foreach T of local treatment_groups {
	scalar _b_`T' = _b[`T']
	scalar _se_`T' = _se[`T']
	scalar _df_`T' = e(df_r)
	summ bg_weekly_income if e(sample) & `T'==1, meanonly
	scalar _denom_`T' = r(mean)
}	

// Pooling across treatment arms
gen treated = (safe_box==1 | locked_box==1 | health_savings==1) // health_pot excluded;
	// see explanation above under NOTES
regress savings treated ///
	rosbg_monthly_contrib i.strata /// additional controls they use in the paper for Table 3
	, cluster(id_harp_rosca)
assert e(N)==771 // number of observations in regression (Table 3)
local T treated
scalar _b_`T' = _b[`T']
scalar _se_`T' = _se[`T']
scalar _df_`T' = e(df_r)
summ bg_weekly_income if e(sample) & `T'==1, meanonly
scalar _denom_`T' = r(mean)

foreach T in /* `treatment_groups' */ treated {
	local ++rr 
	local rownames `rownames' `auth'_`T'
	foreach est in b se {
		scalar _`est'_`auth'_`T' = _`est'_`T'/(_denom_`T'*`weeks')
		di as text _n "``est'' for `T': " 
		di as result _`est'_`auth'_`T'
		local estimate_list "`estimate_list' _`est'_`auth'_`T'"
		matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
	}
	scalar _lo_`auth'_`T' = _b_`auth'_`T' - invttail(_df_`T',_alpha/2)*_se_`auth'_`T'
	scalar _hi_`auth'_`T' = _b_`auth'_`T' + invttail(_df_`T',_alpha/2)*_se_`auth'_`T'
	scalar _p_`auth'_`T'  = 2*ttail(_df_`T',abs(_b_`auth'_`T'/_se_`auth'_`T')) 
	foreach est in lo hi p {
		matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
	}
}

**********************
** DUPAS ET AL 2016 **
**********************
** NOTES:
**	-This is Dupas, Karlan, Robinson, Ubfal
**	-Results pool data from 12, 18, and 24 month surveys
local ++a
local auth "``a''"
local months = 12 // Always use annual income as denominator 

scalar _b_malawi = 1.391 // Table 5, column 7
scalar _se_malawi = 0.98
scalar _denom_malawi = 34 // income of respondent + spouse from fn 27 
	// (Note table 1 only has income of respondent)
scalar _df_malawi = 2046 - 2 - 1 - 1 - 1 // 2046 is number of respondents
	// 2 is number of wave dummies (1 omitted)
	// 1 is control for baseline mean
	// 1 is constant
	// 1 is treatment dummy
	// they also have stratification dummies but not clear how many

scalar _b_uganda  = 4.98
scalar _se_uganda = 2.44
scalar _denom_uganda = 41 // income of respondent + spouse from fn 27
	// (Note table 1 only has income of respondent)
scalar _df_uganda = 2085 - 2 - 1 - 1 - 1 // 2085 is number of respondents
	// 2 is number of wave dummies (1 omitted)
	// 1 is control for baseline mean
	// 1 is constant
	// 1 is treatment dummy
	// they also have stratification dummies but not clear how many
	
scalar _b_pooled = 3.052
scalar _se_pooled = 1.334
scalar _denom_pooled = (_denom_malawi*2046 + _denom_uganda*2085)/(2046+2085)
scalar _df_pooled = (2046 + 2085) - 2 - 1 - 1 - 1 

foreach T in malawi uganda {
	local ++rr
	local rownames `rownames' `auth'_`T'
	foreach est in b se {
		scalar _`est'_`auth'_`T' = _`est'_`T'/(_denom_`T'*`months')
		di as text _n "``est'' for `T': " 
		di as result _`est'_`auth'_`T'
		local estimate_list "`estimate_list' _`est'_`auth'_`T'"
		matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
	}
	scalar _lo_`auth'_`T' = _b_`auth'_`T' - invttail(_df_`T',_alpha/2)*_se_`auth'_`T'
	scalar _hi_`auth'_`T' = _b_`auth'_`T' + invttail(_df_`T',_alpha/2)*_se_`auth'_`T'
	scalar _p_`auth'_`T'  = 2*ttail(_df_`T',abs(_b_`auth'_`T'/_se_`auth'_`T')) 
	foreach est in lo hi p {
		matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
	}
}

***********************
** KARLAN ET AL 2016 **
***********************
local ++a
local auth "``a''"

use "$data/comparison/Karlan_etal_2016_MgmtSci/analysis_dataallcountries.dta", clear

// Locals from their replication file
local randfeature = "highint rewardint joint dc joint_single"
local covariates = "female age highschool_completed married inc_7d wealthy hyperbolic spent_b4isaved saved_asmuch missing_female missing_age missing_highschool_completed missing_married missing_saved_asmuch missing_spent_b4isaved"
local treatments = "rem_any gain_rem loss_rem rem_no_motive rem_motive incentive noincentive late_rem_any foto puzzle_ica"
local treatments1 = "rem_any gain_rem loss_rem rem_no_motive rem_motive late_rem_any foto puzzle_ica"
local treatments2 = "rem_any gain_rem loss_rem incentive noincentive"
local treatments3 = "rem_any gain_rem loss_rem late_rem_any"

** This is a replication of their Table 4 except they used logs;
**  either way it is insignificant
regress quant_saved	rem_any_peru rem_any_boli rem_any_phil `randfeatures' `covariates' i.country, robust 
	// separated by country (only Philippines has income data so we have to use this specification)
local T rem_any_phil
scalar _b_`T' = _b[`T']
scalar _se_`T' = _se[`T']
scalar _df_ = e(df_r)

summ inc_7d if e(sample) & `T'==1 & philippines==1
scalar _denom_`T' = r(mean)

local months = 12 // Always use annual income as denominator 
	
local ++rr
local rownames `rownames' `auth'
foreach est in b se {
	scalar _`est'_`auth'_`T' = _`est'_`T'/(_denom_`T'*weeks_per_month*`months')
	di as text _n "``est'' for `T': " 
	di as result _`est'_`auth'_`T'
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}
scalar _lo_`auth'_`T' = _b_`auth'_`T' - invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _hi_`auth'_`T' = _b_`auth'_`T' + invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _p_`auth'_`T'  = 2*ttail(_df_,abs(_b_`auth'_`T'/_se_`auth'_`T')) 
foreach est in lo hi p {
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}

****************************
** KARLAN AND ZINMAN 2017 **
****************************
/* NOTES: 
	-They use average balances over 12 months rather than ending balance,
	but comparing the mean dependent variable from Table 3 and Appendix Table 1
	we can see that the average balance isn't changing over time so it should be
	OK to do this. And even if we instead used total DEPOSITS over 12 months,
	(Appendix Table 3) we would get equally small effect sizes.
	-We use the winsorized at 5% results but no matter whether we use no-winsorizing,
	winsorizing at 1%, or winsorizing at 5%, effect of treatment on savings is a 
	tight 0.
*/
local ++a
local auth "``a''"
local weeks = 52 // Results from Table 3 are over 1 year

// Read in replication data
use "$data/comparison/Karlan_Zinman_2017/proc/dreamfinal_for_analysis.dta"

// Locals from their replication files
local marketer "marketer1 marketer2 marketer3 marketer4 marketer5 marketer6 marketer7 marketer8 marketer9 marketer10 marketer11 marketer12 marketer13 marketer14 marketer15" 
local surveydate "week1 week2 week3 week4 week5 week6 week7 week8 week9 week10 week11 week12 week13 week14 week15 week16 week17 week18 week19"
local baseline "female college highwealth abvmed_income saved saved_formal satisfied presentbiased impatientnow decision1"
local savamt "savamt1 savamt2 savamt3 savamt4 savamt5 savamt6"
local barangay "barangay1 barangay2 barangay3 barangay4 barangay5 barangay6 barangay7 barangay8 barangay9 barangay10 barangay11 barangay12 barangay13 barangay14 barangay15 barangay16 barangay17"  
local irate "highinterest reward"
local indepvars_irate "`irate' `savamt' `marketer' `surveydate' `barangay'"

// Regress change in savings on treatment groups (replicates Table 3 results
//  in Karlan and Zinman, 2016) 
reg mb12mo `indepvars_irate', robust          // Table 3, column 2
reg mb12mo_recode99 `indepvars_irate', robust // Table 3, column 4
reg mb12mo_recode95 `indepvars_irate', robust // Table 3, column 3
	// We will use the 5% winsorized results from Table 3, column 3
	//  since that is the most comparable to our study
	
// Pooled treatment (high interest rate or reward interest rate)
assert !(highinterest==1 & reward==1) // make sure no one received both treatments
gen treated = (highinterest==1 | reward==1)
local indepvars_irate2 = subinstr("`indepvars_irate'","`irate'","treated",.)
	// replace the two treatment dummies in `irate' with the pooled treatment dummy
	//  created above
foreach suffix in "" "_recode99" "_recode95" {
	local T treated
	reg mb12mo`suffix' `indepvars_irate2', robust
}
// For the paper, use winsorized at 5% (consistent with our study):
local T treated
reg mb12mo_recode95 `indepvars_irate2', robust
scalar _b_`T' = _b[`T']
scalar _se_`T' = _se[`T']
scalar _df_ = e(df_r)

summ inc_7d if `T'==1 & e(sample)
scalar _denom_`T' = r(mean)

local ++rr
local rownames `rownames' `auth'
foreach est in b se {
	scalar _`est'_`auth'_`T' = _`est'_`T'/(_denom_`T'*`weeks')
	di as text _n "``est'':" 
	di as result _`est'_`auth'_`T'
	local estimate_list "`estimate_list' _`est'_`auth'_`T'"
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}
scalar _lo_`auth'_`T' = _b_`auth'_`T' - invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _hi_`auth'_`T' = _b_`auth'_`T' + invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _p_`auth'_`T'  = 2*ttail(_df_,abs(_b_`auth'_`T'/_se_`auth'_`T')) 
foreach est in lo hi p {
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}

************************
** KARLAN ET AL. 2017 **
************************
local ++a
local auth "``a''"
di "`auth'"
local months = 12 // Always use annual income as denominator 	

scalar _b_ = 13.73132  // Table S3; replicated
	// using their impacts_family_indices_components.do
scalar _se_ = 4.487768 // Table S3; replicated
	// using their impacts_family_indices_components.do
scalar _df_ = 561 - 1 // number of clusters = 561
scalar _denom_ = 123.102 // endline mean total income, control group
	// (Table S5; replicated)
	
local T ""
local ++rr
local rownames `rownames' `auth'
foreach est in b se {
	scalar _`est'_`auth'_`T' = _`est'_`T'/(_denom_`T'*`months')
	di as text _n "``est'' for `T': " 
	di as result _`est'_`auth'_`T'
	local estimate_list "`estimate_list' _`est'_`auth'_`T'"
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}
scalar _lo_`auth'_`T' = _b_`auth'_`T' - invttail(_df_`T',_alpha/2)*_se_`auth'_`T'
scalar _hi_`auth'_`T' = _b_`auth'_`T' + invttail(_df_`T',_alpha/2)*_se_`auth'_`T'
scalar _p_`auth'_`T'  = 2*ttail(_df_`T',abs(_b_`auth'_`T'/_se_`auth'_`T')) 
foreach est in lo hi p {
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}

***********************
** KAST AND POMERANZ **
***********************
local ++a
local auth "``a''"
local months = 12 // Always use annual income as denominator 	

// Breakdown for savings part is:
//  39% active users have average 18456, sd 77,672
//  of remaining 61%, 
//		14% (of total) take up but left minimum balance, 1000;
//  	47% (of total) do not take up, hence balance = 0
// To get the mean and standard deviation for non-active users:
local n_treatment = 2279 // Table 2
local n_takeup = 1218    // Table 2
local n_active = 886     // Table 2
local n_nonactive  = `n_treatment' - `n_active' 
local n_notakeup   = `n_treatment' - `n_takeup' 
clear
set obs `n_nonactive'
gen x = 0
replace x = 1000 in 1/`n_notakeup'
summ x
scalar _mean_nonactive = r(mean)
scalar _var_nonactive   = r(sd)^2

scalar _mean_active = 18456 // Table 2
scalar _var_active = 77672^2   // Table 2

scalar _b_savings = (`n_active'/`n_treatment')*_mean_active + ///
	((`n_takeup'-`n_active')/`n_treatment')*1000

// Total variance for ITT effect (Headrick, 2010, eqn 5.38):
#delimit ;
scalar _V_savings = 
	(
		(`n_nonactive'^2) * _var_nonactive + (`n_active'^2) * _var_active - 
		`n_nonactive'*_var_nonactive - `n_nonactive'*_var_active - 
		`n_active'*_var_nonactive - `n_active'*_var_active +
		`n_nonactive'*`n_active'*_var_nonactive + `n_nonactive'*`n_active'*_var_active +
		`n_nonactive'*`n_active'*(_mean_nonactive-_mean_active)^2 
	)/(
		(`n_nonactive' + `n_active' - 1)*(`n_nonactive' + `n_active')
	)
; /* note I tested to make sure this formula works with a toy example in 
		test_totalvar.R */
#delimit cr

local n_total = 3572 // Full sample treatment and control; table 3
scalar _b_debt = -12931 // Table 3 effect of peer groups on debt
scalar _V_debt = `n_total'*(5867^2) // V = N*se^2; se from Table 3

scalar _b_ = _b_savings - _b_debt // net savings
di _b_
scalar _V_ = _V_savings + _V_debt // - 2Cov(savings,debt)
	// assumes independence (i.e. Cov(savings,debt)=0) since we don't know 
	// variance-covariance matrix (don't have microdata)
scalar _se_ = sqrt(_V_)/sqrt(`n_total')
scalar _df_ = 307 - 3 // 307 is number of groups; 
	// 3 is for constant, post, account x post
	
scalar _denom_ = 4.27*79955 // number of household members * 
	// per capita monthly income (both from Table 1)
	
local T ""
	
local ++rr
local rownames `rownames' `auth'
foreach est in b se {
	scalar _`est'_`auth'_`T' = _`est'_`T'/(_denom_`T'*`months')
	di as text _n "``est'':" 
	di as result _`est'_`auth'_`T'
	local estimate_list "`estimate_list' _`est'_`auth'_`T'"
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}
scalar _lo_`auth'_`T' = _b_`auth'_`T' - invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _hi_`auth'_`T' = _b_`auth'_`T' + invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _p_`auth'_`T'  = 2*ttail(_df_,abs(_b_`auth'_`T'/_se_`auth'_`T')) 
foreach est in lo hi p {
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}

**********************
** KAST ET AL. 2016 **
**********************
/* NOTES: 
	-Although we prefer to show results for total savings instead of bank savings,
	the authors emphasize the bank savings results because their total savings
	results are very noisy. Thus, for this paper we use the bank savings results
	even though total savings results are available in the appendix. We only have 
	results for average balance rather than ending balance, but this should be similar
	based on the stable average balance by month (Figure 3, panel B)
	-Interest rate is 5% real interest rate rather than 0.3%
	-We use the 5% winsorized results, consistent with our study
*/
local ++a
local auth "``a''"
local months = 12 // "All outcomes are for one year after opening of the accounts"

local T "groups"
scalar _b_`T' = 1871 // Table 3, column 7 
scalar _se_`T' = 384
scalar _df_`T' = 196 - 1
scalar _denom_`T' = (80187+335)*(4.42-0.14)
	// Income per capita (monthly) * hh members for control - (diff treatment - control)

local T "interest"
scalar _b_`T' =  232
scalar _se_`T' = 368
scalar _df_`T' = 196 - 2 - 1 
	// 196 groups (clusters)
	// 2 treatment arm dummies
	// 1 constant
scalar _denom_`T' = (80187+615)*(4.42-0.07)

foreach T in groups /* interest */ {
	local ++rr
	local rownames `rownames' `auth'_`T'
	foreach est in b se {
		scalar _`est'_`auth'_`T' = _`est'_`T'/(_denom_`T'*`months')
		di as text _n "``est'' for `T': " 
		di as result _`est'_`auth'_`T'
		local estimate_list "`estimate_list' _`est'_`auth'_`T'"
		matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
	}
	scalar _lo_`auth'_`T' = _b_`auth'_`T' - invttail(_df_`T',_alpha/2)*_se_`auth'_`T'
	scalar _hi_`auth'_`T' = _b_`auth'_`T' + invttail(_df_`T',_alpha/2)*_se_`auth'_`T'
	scalar _p_`auth'_`T'  = 2*ttail(_df_`T',abs(_b_`auth'_`T'/_se_`auth'_`T')) 
	foreach est in lo hi p {
		matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
	}
}

****************
** PRINA 2015 **
****************
/* NOTES: bo_wk55 is total balance after 55 weeks. Total balance after 0 
  weeks is 0 since they didn't have the accounts, so Delta Savings is 
  precisely bo_wk55 (at least for savings in the account, and this paper
  doesn't have non-account savings except for assets and net worth in 
  Table 4 but it finds no statistically significant effects for those
  so let's ignore them).
*/
local ++a
local auth "``a''"
local weeks = 52 // Always use annual income

// Read in replication data
use "$data/comparison/Prina_2015_JDE/Nepal_JDE_R1.dta", clear

// Keep if completed both surveys (as in paper)
keep if base2 == 1 & end2 == 1
recode bo_wk55 (. = 0)
/* In this study the bo_wk55 variable is only non-missing for those who
  OPENED an account, but we want to estimate intent-to-treat (not everyone
  in the treatment group opened an account). So we need to assign 0 
  savings to those who did not open an account (both those who chose
  to not open one in the treatment group and those who could not open
  one because they were in the control group).
*/

// Regression (the paper never directly estimates impact of card on 
//  formal savings so this is not replicating any direct result in the paper)
local T ITT // intent to treat dummy
regress bo_wk55 `T', robust // individual-level randomization so no cluster here
scalar _b_`T' = _b[`T']   // Delta Savings
scalar _se_`T' = _se[`T'] // standard error of Delta Savings
scalar _df_ = e(df_r)

// Income
//  in Table 1 they use b2_totG2inc which is baseline, 
//  here let's use endline income, e2_totG2inc
summ e2_totG2inc if `T'==1 & e(sample) // note e2_totG2inc is weekly
scalar _denom_`T' = r(mean)

local ++rr
local rownames `rownames' `auth'
foreach est in b se {
	scalar _`est'_`auth'_`T' = _`est'_`T'/(_denom_`T'*`weeks')
	di as text _n "``est'':" 
	di as result _`est'_`auth'_`T'
	local estimate_list "`estimate_list' _`est'_`auth'_`T'"
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}
scalar _lo_`auth'_`T' = _b_`auth'_`T' - invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _hi_`auth'_`T' = _b_`auth'_`T' + invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _p_`auth'_`T'  = 2*ttail(_df_,abs(_b_`auth'_`T'/_se_`auth'_`T')) 
foreach est in lo hi p {
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}

*************************
** SCHANER 2016 (NBER) **
*************************
/* NOTES: Coefficients for 6-month and 3-year effects very similar; use 3-year
	since paper focuses on long-run impacts
*/
local ++a
local auth "``a''"
local months = 12 // Always use annual income

local T ""

scalar _b_  = 796 // Table 3, column 2 
scalar _se_ = 439
scalar _df_ = 1237 - 5 - 1 // 1237 couples
	// 5 are the treatment group dummies
	// 1 is constant
	
scalar _denom_ = 4265 + 1137 // monthly income (mean for 0% interest + 
	// treatment effect at the 3-year endline)

local ++rr
local rownames `rownames' `auth'
foreach est in b se {
	scalar _`est'_`auth'_`T' = _`est'_`T'/(_denom_`T'*`months')
	di as text _n "``est'':" 
	di as result _`est'_`auth'_`T'
	local estimate_list "`estimate_list' _`est'_`auth'_`T'"
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}
scalar _lo_`auth'_`T' = _b_`auth'_`T' - invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _hi_`auth'_`T' = _b_`auth'_`T' + invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _p_`auth'_`T'  = 2*ttail(_df_,abs(_b_`auth'_`T'/_se_`auth'_`T')) 
foreach est in lo hi p {
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}

**************************
** SESHAN AND YANG 2014 **
**************************
/* NOTES: Replication data not available for this one; 
	take results from tables in paper
*/ 
local ++a
local auth "``a''"
local months = 12 

local T ""

scalar _b_  = 23360 // Table 3, column 1
scalar _se_ = 36486
scalar _df_ = 200 - 1 - 1 // 200 is number of households
	// 1 is constant
	// 1 is treatment dummy

// Income: add treatment mean of migrant annual income and 
//  wife's household's annual income (Table 1, column 3)
scalar _denom_ = (318073 + 4755)/12 
	// divide by 12 to get monthly

local ++rr
local rownames `rownames' `auth'
foreach est in b se {
	scalar _`est'_`auth'_`T' = _`est'_`T'/(_denom_`T'*`months')
	di as text _n "``est'':" 
	di as result _`est'_`auth'_`T'
	local estimate_list "`estimate_list' _`est'_`auth'_`T'"
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}
scalar _lo_`auth'_`T' = _b_`auth'_`T' - invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _hi_`auth'_`T' = _b_`auth'_`T' + invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _p_`auth'_`T'  = 2*ttail(_df_,abs(_b_`auth'_`T'/_se_`auth'_`T')) 
foreach est in lo hi p {
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}

***************************
** SOMVILLE & VANDEWALLE **
***************************
local ++a
local auth "``a''"
local weeks = 52 // Always use annual income
	
local T ""

scalar _b_ = 227.7 // Table 5, column 3
scalar _se_ = 78.9
scalar _df_ = 17 - 1 // 17 is number of village clusters

scalar _denom_ = 770 // average weekly income, from text of 2016 working paper version of paper

local ++rr
local rownames `rownames' `auth'
foreach est in b se {
	scalar _`est'_`auth'_`T' = _`est'_`T'/(_denom_`T'*`weeks')
	di as text _n "``est'':" 
	di as result _`est'_`auth'_`T'
	local estimate_list "`estimate_list' _`est'_`auth'_`T'"
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}
scalar _lo_`auth'_`T' = _b_`auth'_`T' - invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _hi_`auth'_`T' = _b_`auth'_`T' + invttail(_df_,_alpha/2)*_se_`auth'_`T'
scalar _p_`auth'_`T'  = 2*ttail(_df_,abs(_b_`auth'_`T'/_se_`auth'_`T')) 
foreach est in lo hi p {
	matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
}

***************
** OUR PAPER **
***************
local ++a
local auth "``a''"
local months = 12 // Always use annual
local income = 3148.28 // Table 3b

// Take effect sizes directly from log file (already expressed as savings rates):
scalar _b_`auth'_2year  = 767.87  // Table 4, effect in period 5
scalar _se_`auth'_2year = 56.72   // Table 4, se for effect in period 5
scalar _df_2year = 331 // number of localities

scalar _p_`auth'_2year  = 5.63e-38 // from log file

scalar _b_`auth'_1year = 447.48 // Table 4, effect in period 3
scalar _se_`auth'_1year = 41.98 // Table 4, se for effect in period 3
scalar _df_1year = 331 // number of localities

scalar _p_`auth'_1year = 5.77e-27 // from log file

foreach T in 1year 2year {
	local ++rr
	local rownames `rownames' `auth'_`T'
	foreach est in b se {
		matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'/(`income'*`months')
	}
	scalar _lo_`auth'_`T' = (_b_`auth'_`T' - invttail(_df_`T',_alpha/2)*_se_`auth'_`T')/(`income'*`months')
	scalar _hi_`auth'_`T' = (_b_`auth'_`T' + invttail(_df_`T',_alpha/2)*_se_`auth'_`T')/(`income'*`months')
	scalar _p_`auth'_`T'  = 2*ttail(_df_`T',abs(_b_`auth'_`T'/_se_`auth'_`T')) 
	foreach est in lo hi p {
		matrix savingsrates[`rr',``est'_col'] = _`est'_`auth'_`T'
	}
}
	
*****************
** OUTPUT DATA **
*****************
matrix rownames savingsrates = `rownames'
clear
svmat2 savingsrates, names(col) rnames(auth) // !user! written by Nick Cox
	// (unlike -svmat-, allows row names to be saved as variable)
gen byte ours = 0
replace ours = 1 if strpos(auth, "thispaper")
drop if mi(b) // extra rows

// For creating a forest plot in R:
gen color = "black"
replace color = "gray40" if p>0.05 & ours==0
replace color = "darkorange3" if ours==1

gen pch = 19 // for marker style in R (solid circle)
replace pch = 1 if p>=0.10 // (hollow circle)
replace pch = 15 if ours==1 // squares for our study

// Merge in metadata
merge 1:1 auth using `tomerge' // , assert(match)
drop if _merge!=3
drop _merge

// two panels
gen real_months = real( ///
	subinstr(substr(months,1,2),"-","",.) ///
) // substr() since it can be a range
gen byte longer_term = real_months > 18
sort longer_term b
list b-auth, clean noobs

**********
** SAVE **
**********
export delimited using "$proc/savings_rates.csv", replace

*************
** WRAP UP **
*************
log close
exit
