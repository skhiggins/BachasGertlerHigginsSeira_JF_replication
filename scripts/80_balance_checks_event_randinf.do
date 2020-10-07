** BALANCE CHECKS OVER TIME RELATIVE TO CARD RECEIPT
**  Pierre Bachas and Sean Higgins

// Note: had to do this in a separate file to manually parallelize it;
//  otherwise it was too slow to do 2000 draws with full admin data

args start_perm end_perm
macro shift
macro shift // so that `*' has any additional elements
	// run the command as follows on server, to do e.g. permutations 101-200 for the four balance check variables being used:
	//  nohup stata-mp -b do dofiles/balance_checks_event_randinf.do 101 200 &
	// then the file will have local start_perm = 101 and local end_perm = 200

*****************
** DIRECTORIES **
*****************
if "`c(username)'"=="higgins" { // NBER server
	global main "/disk/bulkw/higgins/ATM"
}
else if "`c(username)'"=="skh2820" { // Kellogg Linux Cluster
	global main "/kellogg/proj/skh2820/ATM"
}
else if "`c(username)'"=="pierrebachas" { // Pierre's laptop
	global main "/Users/pierrebachas/Dropbox/Bansefi/ATM"
	local sample "_sample1" // to use 1% sample on laptop
}	
else if strpos("`c(username)'","Sean") { // Sean's laptop
	global main "C:/Dropbox/FinancialInclusion/Bansefi/ATM"
	local sample "_sample1" // to use 1% sample on laptop
}
include "$main/scripts/server_header.doh"
// To replicate on another computer simply uncomment the following lines by removing ** and change the path:
** global main "/path/to/replication/folder"

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 80_balance_checks_event_`start_perm'_`end_perm'
cap log close
set linesize 200
log using "$logs/`project'`sample'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
// Number of permutations
local N_perm = `end_perm' - `start_perm' + 1 // end_perm and start_perm defined by args above

local depvars `*' // `*' defined by args and macro shifts at beginning of dofile
#delimit ;
if "`depvars'"=="" local depvars 
	sum_bc 
	sum_bc_pos_time 
	sum_bc_pos_time_wd 
	sum_bc_not_before_POS
;
#delimit cr

// Start and end of event study graph
local lowcuat 0
local hicuat  4
local cols = `hicuat' - `lowcuat' + 1 // 1 col per coefficient; 1 row per permutation

**********
** DATA **
**********
use "$proc/balance_checks_forreg_withperm`sample'.dta", clear

***************************************************
// Balance checks regression with account FE
***************************************************
// Make empty matrices for results
foreach depvar of varlist `depvars' {	
	local mat_name `depvar'_ri // _ri for randomization inference
	matrix `mat_name' = J(`N_perm', `cols', .)
}

// Randomization inference
quietly { // just print a notification on each permutation's completion
	forval i = `start_perm'/`end_perm' { // end_perm and start_perm defined 
		// by args (when running do file on server)
		
		local j = `i' - `start_perm' + 1
		
		foreach depvar of varlist `depvars' { 
			local mat_name `depvar'_ri`_controls' // _ri for randomization inference
		
			reghdfe `depvar' ib(last).cuat_since_switch`i', absorb(integranteid_num) vce(cluster branch_clave_loc)
			
			local col = 0
			local _colnames ""
			forval cuat = `lowcuat'/`hicuat' { // cuat_since_switch
				local ++col
				matrix `mat_name'[`j', `col'] = ///
					abs(_b[`cuat'.cuat_since_switch]/_se[`cuat'.cuat_since_switch])
					
				local _colnames `_colnames' "css_`cuat'"
			}
			
			// Add column names
			if `i'==`start_perm' { // just need to do this once
				matrix colnames `mat_name' = `_colnames'
			}
			
			noi di "Permutation `i': `depvar'`_controls'"
		}
	}
}

// Save the permuted test statistics in a file to append and generate 
//  randomization inference p-values in another do file
foreach depvar of varlist `depvars' {	
	local mat_name `depvar'_ri // _ri for randomization inference
	
	clear
	svmat `mat_name', names(col)
	save "$proc/`mat_name'_`start_perm'_`end_perm'`sample'.dta", replace
}
	
*************
** WRAP UP **
*************
log close
exit
