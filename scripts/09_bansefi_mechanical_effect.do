** CALCULATE ACCOUNT-LEVEL MECHANICAL EFFECT BY (REDEFINED) BIMESTER
**  Pierre Bachas and Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 09_bansefi_mechanical_effect
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local fast = 0
local make_sample = 1
local startyear 2007
local endyear   2011
local startbim = 1
local endbim   = (`endyear' - `startyear' + 1)*6

**********
** DATA **
**********
// For 1% sample at end
if `make_sample' {
	use "$proc/DatosGenerales_sample1.dta", clear
	keep integranteid
	tempfile tosample
	save `tosample', replace
}

*********************************************
// Prepare Main data 
*********************************************
use "$proc/transactions_redef_bim`sample'.dta", clear
format naturaleza %1s // Was showing 244 characters

gen f = date( fecha, "YMD")
format f %d

egen id = group(integranteid)

// Create variable with number of days in bimester
label values bimester_redefined bimes
cap drop year
rename year_redefined year
decode bimester_redefined, gen(__bimester_label)
gen __first_month  = substr(__bimester_label,1,3)
tab __first_month
gen __second_month = substr(__bimester_label,5,3) 
tab __second_month
gen __temp_i = __first_month + " 1 " + string(year)
tab __temp_i 
gen f_initial = date(__temp_i, "MDY")
format f_initial %td
drop __*

replace f = f_initial if f < f_initial // because of redefined bimesters

summ bimester_redefined, meanonly
local max_bim = r(max)
forval i=1/`max_bim' {
	summ f_initial if bimester_redefined==`i', meanonly
	di r(mean)
	local initial_`i' = r(mean)
}
if !(`fast') forval i=1/`max_bim' {
	tab f_initial if bimester_redefined==`i' // as a check
}

gen n_days = .
assert mod(`endbim',6)==0 // otherwise need to edit next line; won't be Jan 1
local initial_`=`endbim'+1' = date("Jan 1 `=`endyear'+1'", "MDY")
forval i=`startbim'/`endbim' {
	local j = `i' + 1
	replace n_days = `initial_`j'' - `initial_`i'' if bimester_redefined==`i'
}
tab n_days
assert n_days >= 59 & n_days <= 62 if !missing(n_days) // number of days in a bimester
	// in sample there are 0 obs missing(n_days)
	// on server there are 2 obs (out of 26M) that missing(n_days)
tab bimester_redefined if missing(n_days)

// because of recoded bimesters
replace date = f_initial if date < f_initial // ones that were at end of previous bimester and recoded

save "$waste/transactions_redef`sample'_working.dta", replace 
					
*********************************************
// Analyse bimester by bimester
*********************************************
forval bi = `startbim'(1)`endbim'{
	
	use "$waste/transactions_redef`sample'_working.dta", clear
	
	keep if bimester_redefined == `bi'

	// (2) Generate Batch indicator: for authomatic batch indicador2 = 1 if it is automatic and 0 otherwise

	sort integranteid f
	
	bysort integranteid: gen N_transactions = _N
	egen group_tipo = group(integranteid naturaleza)
	
	egen tag_cliente = tag(integranteid)
	egen tag_tipo = tag(integranteid naturaleza)

	// Regroup transactions of the same kind done the same day (Was this done in Sean's code already?)
	bysort group_tipo f: egen temp_importe = total(importe)
	replace importe = temp_importe if temp_importe!=importe
	duplicates drop group_tipo f, force
	drop temp_importe
	
	// Generate and assign number of withdrawals and deposits by clients	
	bysort group_tipo: gen N_temp = _N
	gen N_deposits = N_temp if naturaleza=="H"
	gen N_withdrawals = N_temp if naturaleza=="D"
	drop N_temp
	
	sort integranteid N_deposits 
	replace N_deposits = N_deposits[_n-1] if N_deposits==. & integranteid[_n] == integranteid[_n-1]
	replace N_deposits = 0 if N_deposits==. 
	
	sort integranteid N_withdrawals
	replace N_withdrawals = N_withdrawals[_n-1] if N_withdrawals==. & integranteid[_n] == integranteid[_n-1]
	replace N_withdrawals = 0 if N_withdrawals==. 
										
	// Generate total deposit and total withdrawal amounts
	bysort group_tipo: egen total_temp = total(importe)
	gen total_d = total_temp if naturaleza=="H"
	gen total_w = total_temp if naturaleza=="D"
	drop total_temp
				
	// Assign total to all transaction of a given client
	sort integranteid total_d
	replace total_d =total_d[_n-1] if total_d==. & integranteid[_n] == integranteid[_n-1]
	replace total_d=0 if total_d==.  
	sort integranteid total_w
	replace total_w =total_w[_n-1] if total_w==. & integranteid[_n] == integranteid[_n-1]  
	replace total_w=0 if total_w==.  

	sort integranteid f						

	// For mental simplicity rename "Deber"/D as W(Withdrawals) "Haber"/H as D(desposits)
	replace naturaleza = "W" if naturaleza == "D" 
	replace naturaleza = "D" if naturaleza == "H"

	// tab N_transactions // 98% between 4-8
			
	sort integranteid f
	by integranteid: gen order_transaction = _n
	
	xtset id order_transaction
	if !(`fast') xtdes

	//  Delete observations of clients past the 8th transaction (Note: better than drop?)
	local threshold_order = 4			
	keep if order <= `threshold_order'			
				
	// Generate the spell of W an D's
	
	// Reshape to use concat			
	keep naturaleza *id order importe f n_days		
	reshape wide naturaleza importe f, i(integranteid) j(order) 
	egen pattern = concat(naturaleza*)

	if !(`fast') {
		local threshold_freq = 0 // Define threshold for patterns to be dropped
		qui count
		bysort pattern: gen temp_freq = _N/`r(N)'
		
		qui count 
		local temp_count `r(N)'
		qui count if temp_freq <= `threshold_freq' 
		
		disp "**** PCT LOST:  `r(N)'/`temp_count' *****"
		drop if temp_freq <= `threshold_freq' 
	}
	
	display "****** TIME = `bi' ******"
	if !(`fast') fre pattern, descending
	
	// Now generate the mechanical effect for all potential patterns

	// Variables for average mechanical effect by wave bimester pattern:
	//  days1, days2, days3 - days between deposit and first/second/third withdrawal
	//  prop1, prop2, prop3 - proportion of deposit withdrawn during first/second/third withdrawal
	// In 19_merge_mechanical_effect.do, we average these within each wave-bimester-pattern group, 
	//  then calculate each accounts mechanical effect as 
	//  (avg_days1*avg_prop1*D + avg_days2*avg_prop2*D + avg_days3*avg_prop3*D)/n_days
	//  where D is the deposit amount (still at the account level)
	//  (Note: the above equation is for patterns with 1 deposit and is adapted for patterns with >1 deposit)
	foreach var in mechanical_effect mechanical_effect2 { 
		gen `var' = .
	}
	forval i=1/3 {
		gen days`i' = .
		gen prop`i' = .
	}
	
	// No mechanical effect patterns
	//  (No withdrawal after a deposit in the bimester)
	//  Note these patterns are rare
	#delimit ;
	foreach var in mechanical_effect mechanical_effect2 { ;
		replace `var' = 0 if 
			  pattern == "D" 
			| pattern == "DD"
			| pattern == "W"
			| pattern == "WD"
			| pattern == "WDD"
			| pattern == "WW"		
			| pattern == "WWW"		
			| pattern == "WWWW"			
			| pattern == "WWD"			
			| pattern == "WWDD"			
			| pattern == "WWWD"			
			| pattern == "WDDD"
			| pattern == "DDD"
			| pattern == "DDDD"	
		;
	} ;
	forval i=1/3 { ;
		foreach v in days prop { ;
			replace `v'`i' = 0 if 
				  pattern == "D" 
				| pattern == "DD"
				| pattern == "W"
				| pattern == "WD"
				| pattern == "WDD"
				| pattern == "WW"		
				| pattern == "WWW"		
				| pattern == "WWWW"			
				| pattern == "WWD"			
				| pattern == "WWDD"			
				| pattern == "WWWD"			
				| pattern == "WDDD"
				| pattern == "DDD"
				| pattern == "DDDD"	
			;
		} ;
	} ;
	#delimit cr
	
	// DW
	// days1 is number of days between deposit and withdrawal
	// days2 = 0, days = 0
	// If W > D, prop1 = D/D = 1
	// If W < D, prop1 = W/D < 1
	//  achieve this with min()
	local patterns (pattern == "DW" | pattern == "DWD" | pattern == "DWDD")
	replace mechanical_effect = (min(importe1, importe2)*(f2-f1))/n_days if `patterns'
	replace mechanical_effect2 = 0 if `patterns' // mechanical_effect2 is the one that only calculates
		// mechanical effect for additional withdrawals
	replace days1 = f2 - f1 if `patterns'
	replace prop1 = min(importe1, importe2)/importe1 if `patterns'
	replace days2 = 0 if `patterns'
	replace prop2 = 0 if `patterns'			
	replace days3 = 0 if `patterns'
	replace prop3 = 0 if `patterns'
	
	// WWDW: Treated like DW
	// days1 is number of days between deposit and third withdrawal
	// days2 = 0, days = 0
	// If W3 > D, prop1 = D/D = 1
	// If W3 < D, prop1 = W3/D < 1
	//  achieve this with min()
	local patterns (pattern == "WWDW")
	replace mechanical_effect = (min(importe3, importe4)*(f4-f3))/n_days if `patterns'
	replace mechanical_effect2 = 0 if `patterns' // mechanical_effect2 is the one that only calculates
		// mechanical effect for additional withdrawals
	replace days1 = f4 - f3 if `patterns'
	replace prop1 = min(importe3, importe4)/importe3 if `patterns'
	replace days2 = 0 if `patterns'
	replace prop2 = 0 if `patterns'			
	replace days3 = 0 if `patterns'
	replace prop3 = 0 if `patterns'

	// WDW
	// days1 is number of days between deposit and subsequent withdrawal
	// days2 = 0, days = 0
	// If W > D, prop1 = D/D = 1
	// If W < D, prop1 = W/D < 1
	//  achieve this with min()
	local patterns (pattern == "WDW" | pattern == "WDWD")
	replace mechanical_effect = (min(importe2, importe3)*(f3-f2))/n_days if `patterns'
	replace mechanical_effect2 = 0 if `patterns'
	replace days1 = f3 - f2 if `patterns'
	replace prop1 = min(importe2, importe3)/importe2 if `patterns'
	replace days2 = 0 if `patterns'
	replace prop2 = 0 if `patterns'			
	replace days3 = 0 if `patterns'
	replace prop3 = 0 if `patterns'
	
	// DWDW
	// days1 is number of days between D1 and W1
	// days2 is number of days between D2 and W2
	// If W1 > D1, prop1 = D1/D1 = 1 // Withdraw more than deposit
	// If W1 < D1, prop1 = W1/D1 < 1 // Withdraw less than deposit
	//  (similarly for W2, D2). achieve this with min()
	local patterns (pattern == "DWDW")
	replace mechanical_effect = (min(importe1,importe2)*(f2-f1)+min(importe3,importe4)*(f4-f3))/n_days if `patterns'
	replace mechanical_effect2 = (min(importe3,importe4)*(f4-f3))/n_days if `patterns'
	replace days1 = f2 - f1 if `patterns'
	replace prop1 = min(importe1,importe2)/importe1 if `patterns'
	replace days2 = f4 - f3 if `patterns'
	replace prop2 = min(importe3,importe4)/importe3 if `patterns'
	replace days3 = 0 if `patterns'
	replace prop3 = 0 if `patterns'			

	// DDWW: Tricky one (two deposits followed by two withdrawals); not sure what's best
	//  Solution for now: treat first withdrawal as coming from first deposit, second from second
	// days1 is number of days between D1 and W1
	// days2 is number of days between D2 and W2
	// If W1 > D1, prop1 = D1/D1 = 1 // Withdraw more than deposit
	// If W1 < D1, prop1 = W1/D1 < 1 // Withdraw less than deposit
	//  (similarly for W2, D2). achieve this with min()
	local patterns (pattern == "DDWW")
	replace mechanical_effect = (min(importe1,importe3)*(f3-f1)+min(importe2,importe4)*(f4-f2))/n_days if `patterns' // Not exactly right but should be good aprox.
	replace mechanical_effect2 = (min(importe2,importe4)*(f4-f2))/n_days if `patterns'
	replace days1 = f3 - f1 if `patterns'
	replace prop1 = min(importe1,importe3)/importe1 if `patterns'
	replace days2 = f4 - f2 if `patterns'
	replace prop2 = min(importe2,importe4)/importe2 if `patterns'
	replace days3 = 0 if `patterns'
	replace prop3 = 0 if `patterns'					
		
	// DDW: Tricky one (two deposits followed by one withdrawal).
	// days1 measures time from first deposit to withdrawal
	// days2 measures time from second deposit to withdrawal			
	// prop1 measures proportion of first deposit withdrawn 
	//   (but if W < D1 + D2, withdraw is considered to come from D2 first and this is taken into account in calculation of prop1)
	// prop2 measures proportion of second deposit withdrawn
	local patterns (pattern == "DDW" | pattern == "DDWD")
	replace days1 = f3 - f1 if `patterns'
	replace days2 = f3 - f2 if `patterns'
	replace days3 = 0 if `patterns'			
	// If W > D1 + D2, prop1 = 1, prop2 = 1 // Withdraw more than sum of deposits (importe3>=importe2+importe1)
	local condition `patterns' & importe3>=importe2+importe1
	replace mechanical_effect = ((importe1)*(f3-f1)+importe2*(f3-f2))/n_days if `condition'
	replace mechanical_effect2 = (importe2*(f3-f2))/n_days if `condition'
	replace prop1 = 1 if `condition'
	replace prop2 = 1 if `condition'
	replace prop3 = 0 if `condition'
	// If W > D2, W < D1 + D2, prop1 = (W - D2)/D1, prop2 = D2/D2 = 1
	// Withdraw more than second deposit (importe3>=importe2) but less than sum of deposits (importe3<importe2+importe1)
	local condition `patterns' & importe3>=importe2 & importe3<importe2+importe1
	replace mechanical_effect = ((importe3-importe2)*(f3-f1)+importe2*(f3-f2))/n_days if `condition'
	replace mechanical_effect2 = (importe2*(f3-f2))/n_days if `condition'
	replace prop1 = (importe3-importe2)/importe1 if `condition'
	replace prop2 = 1 if `condition'
	replace prop3 = 0 if `condition'
	// If W < D2, prop1 = 0, prop2 = W/D2 // Withdraw less than second deposit (importe3<importe2)
	local condition `patterns' & importe3<importe2
	replace mechanical_effect = (importe3*(f3-f2))/n_days if `condition'
	replace mechanical_effect2 = 0 if `condition'
	replace prop1 = 0 if `condition'
	replace prop2 = importe3/importe2 if `condition'
	replace prop3 = 0 if `condition'
	
	// WDDW: Mechanical effect will be treated like DDW meaning that the first Withdrawal is ignored
	// days1 measures time from first deposit to second withdrawal
	// days2 measures time from second deposit to second withdrawal			
	// prop1 measures proportion of first deposit withdrawn 
	//   (but if W2 < D1 + D2, withdraw is considered to come from D2 first and this is taken into account in calculation of prop1)
	// prop2 measures proportion of second deposit withdrawn
	local patterns (pattern == "WDDW")
	replace days1 = f4 - f2 if `patterns'
	replace days2 = f4 - f3 if `patterns'
	replace days3 = 0 if `patterns'
	// If W2 > D1 + D2, prop1 = 1, prop2 = 1 // Withdraw more than sum of deposits (importe3>=importe2+importe1)
	local condition `patterns' & importe4>=importe3+importe2
	replace mechanical_effect = (importe2*(f4-f2)+importe3*(f4-f3))/n_days if `condition'
	replace mechanical_effect2 = (importe3*(f4-f3))/n_days if `condition'
	replace prop1 = 1 if `condition'
	replace prop2 = 1 if `condition'
	replace prop3 = 0 if `condition'
	// If W2 > D2, W2 < D1 + D2, prop1 = (W2 - D2)/D1, prop2 = D2/D2 = 1
	// Withdraw more than second deposit (importe3>=importe2) but less than sum of deposits (importe3<importe2+importe1)
	local condition `patterns' & importe4>=importe3 & importe4<importe3+importe2
	replace mechanical_effect = ((importe4-importe3)*(f4-f2)+importe3*(f4-f3))/n_days if `condition'
	replace mechanical_effect2 = (importe3*(f4-f3))/n_days if `condition'
	replace prop1 = (importe4-importe3)/importe2 if `condition'
	replace prop2 = 1 if `condition'
	replace prop3 = 0 if `condition'
	// If W2 < D2, prop1 = 0, prop2 = W2/D2 // Withdraw less than second deposit (importe3<importe2)
	local condition `patterns' & importe4<importe3
	replace mechanical_effect = (importe4*(f4-f3))/n_days if `condition'
	replace mechanical_effect2 = 0 if `condition'
	replace prop1 = 0 if `condition'
	replace prop2 = importe4/importe3 if `condition'
	replace prop3 = 0 if `condition'		

	// DWW					
	//  days1 measures time from deposit to first withdrawal 
	//  days2 measures time from deposit to second withdrawal
	local patterns (pattern == "DWW" | pattern == "DWWD")
	replace days1 = f2 - f1 if `patterns'
	replace days2 = f3 - f1 if `patterns'
	replace days3 = 0 if `patterns'
	// If W1 > D, prop1 = 1, prop2 = 0 // First withdrawal already exceeds deposit (importe1<=importe2)
	local condition `patterns' & importe1<=importe2
	replace mechanical_effect = (importe1*(f2-f1))/n_days if `condition'
	replace mechanical_effect2 = 0 if `condition'
	replace prop1 = 1 if `condition'
	replace prop2 = 0 if `condition'
	replace prop3 = 0 if `condition'
	// If W1 < D, W1 + W2 > D, prop1 = W1/D, prop2 = (D-W1)/D // First withdrawal less than deposit (importe1>importe2) but sum of withdrawals exceeds it (importe1<=importe2+importe3)
	local condition `patterns' & importe1>importe2 & importe1<=importe2+importe3
	replace mechanical_effect = (importe2*(f2-f1)+(importe1-importe2)*(f3-f1))/n_days if `condition'
	replace mechanical_effect2 = ((importe1-importe2)*(f3-f1))/n_days if `condition'
	replace prop1 = importe2/importe1 if `condition'
	replace prop2 = (importe1-importe2)/importe1 if `condition'
	replace prop3 = 0 if `condition'
	// If W1 + W2 < D, prop1 = W1/D, prop2 = W2/D // Sum of withdrawals less than deposit (importe1>importe2+importe3)
	local condition `patterns' & importe1>importe2+importe3
	replace mechanical_effect = (importe2*(f2-f1)+importe3*(f3-f1))/n_days if `condition'
	replace mechanical_effect2 = (importe3*(f3-f1))/n_days if `condition'
	replace prop1 = importe2/importe1 if `condition'
	replace prop2 = importe3/importe1 if `condition'
	replace prop3 = 0 if `condition'
	
	// WDWW: Treated like DWW meaning that the first Withdrawal is ignored
	//  days1 measures time from deposit to second withdrawal 
	//  days2 measures time from deposit to third withdrawal
	local patterns (pattern == "WDWW")
	replace days1 = f3 - f2 if `patterns'
	replace days2 = f4 - f2 if `patterns'
	replace days3 = 0 if `patterns'
	// If W2 > D, prop1 = 1, prop2 = 0 // First withdrawal already exceeds deposit (importe1<=importe2)
	local condition `patterns' & importe2<=importe3
	replace mechanical_effect = (importe2*(f3-f2))/n_days if `condition'
	replace mechanical_effect2 = 0 if `condition'
	replace prop1 = 1 if `condition'
	replace prop2 = 0 if `condition'
	replace prop3 = 0 if `condition'
	// If W2 < D, W2 + W3 > D, prop1 = W2/D, prop2 = (D-W2)/D // First withdrawal less than deposit (importe1>importe2) but sum of withdrawals exceeds it (importe1<=importe2+importe3)
	local condition `patterns' & importe2>importe3 & importe2<=importe3+importe4
	replace mechanical_effect = (importe3*(f3-f2)+(importe2-importe3)*(f4-f2))/n_days if `condition'
	replace mechanical_effect2 = ((importe2-importe3)*(f4-f2))/n_days if `condition'
	replace prop1 = importe3/importe2 if `condition'
	replace prop2 = (importe2-importe3)/importe2 if `condition'
	replace prop3 = 0 if `condition'
	// If W2 + W3 < D, prop1 = W2/D, prop2 = W3/D // Sum of withdrawals less than deposit (importe1>importe2+importe3)
	local condition `patterns' & importe2>importe3+importe4
	replace mechanical_effect = (importe3*(f3-f2)+importe4*(f4-f2))/n_days if `condition'
	replace mechanical_effect2 = (importe4*(f4-f2))/n_days if `condition'
	replace prop1 = importe3/importe2 if `condition'
	replace prop2 = importe3/importe2 if `condition'
	replace prop3 = 0 if `condition'
		
	// DWWW  	
	//  days1 measures time from deposit to first withdrawal 
	//  days2 measures time from deposit to second withdrawal			
	//  days3 measures time from deposit to third withdrawal			
	local patterns (pattern == "DWWW")
	replace days1 = f2 - f1 if `patterns'
	replace days2 = f3 - f1 if `patterns'
	replace days3 = f4 - f1 if `patterns'
	// If W1 > D, prop1 = 1, prop2 = 0, prop3 = 0 // First withdrawal already exceeds deposit amount (importe1<=importe2)
	local condition `patterns' & importe1<=importe2
	replace mechanical_effect = (importe1*(f2-f1))/n_days if `condition'
	replace mechanical_effect2 = 0 if `condition'
	replace prop1 = 1 if `condition'
	replace prop2 = 0 if `condition'
	replace prop3 = 0 if `condition'
	// If W1 < D, W1 + W2 > D, prop1 = W1/D, prop2 = (D-W1)/D, prop3 = 0 // First withdrawal is not entire deposit amount (importe1>importe2), 
	//  but first + second withdrawals exceed deposit (importe1<=importe2+importe3)
	local condition `patterns' & importe1>importe2 & importe1<=importe2+importe3
	replace mechanical_effect = (importe2*(f2-f1)+(importe1-importe2)*(f3-f1))/n_days if `condition'
	replace mechanical_effect2 = ((importe1-importe2)*(f3-f1))/n_days if `condition'
	replace prop1 = importe2/importe1 if `condition'
	replace prop2 = (importe1-importe2)/importe1 if `condition'
	replace prop3 = 0 if `condition'
	// If W1 + W2 < D, W1 + W2 + W3 > D, prop1 = W1/D, prop2 = W2/D, prop3 = (D - W1 - W2)/D // First two withdrawals do not sum to entire 
	//  deposit (importe1>importe2+importe3), but third withdrawal makes sum of withdrawals exceed deposit (importe1<=importe2+importe3+importe4)
	local condition `patterns' & importe1>importe2+importe3 & importe1<=importe2+importe3+importe4
	replace mechanical_effect = (importe2*(f2-f1)+(importe3)*(f3-f1)+(importe1-importe2-importe3)*(f4-f1))/n_days if `condition'
	replace mechanical_effect2 = ((importe3)*(f3-f1)+(importe1-importe2-importe3)*(f4-f1))/n_days if `condition'
	replace prop1 = importe2/importe1 if `condition'
	replace prop2 = importe3/importe1 if `condition'
	replace prop3 = (importe1-importe2-importe3)/importe1 if `condition'
	// If W1 + W2 + W3 < D, prop1 = W1/D, prop2 = W2/D, prop3 = W3/D
	local condition `patterns' & importe1>importe2+importe3+importe4
	replace mechanical_effect = (importe2*(f2-f1)+(importe3)*(f3-f1)+(importe4)*(f4-f1))/n_days if `condition'
	replace mechanical_effect2 = ((importe3)*(f3-f1)+(importe4)*(f4-f1))/n_days if `condition'
	replace prop1 = importe2/importe1 if `condition'
	replace prop2 = importe3/importe1 if `condition'
	replace prop3 = importe4/importe1 if `condition'
	
	// DDDW	
	// days1 measures time from first deposit to withdrawal
	// days2 measures time from second deposit to withdrawal
	// days3 measures time from third deposit to withdrawal			
	// prop1 measures proportion of first deposit withdrawn 
	// prop2 measures proportion of second deposit withdrawn
	// prop3 measures proportion of second deposit withdrawn 
	//   (but withdrawal is considered to be taken first out of D3 then D2 then D1)
	local patterns (pattern == "DDDW")
	replace days1 = f4 - f1 if `patterns'
	replace days2 = f4 - f2 if `patterns'
	replace days3 = f4 - f3 if `patterns'			
	// If W > D1 + D2 + D3, prop1 = 1, prop2 = 1, prop3 = 1 // Withdraw more than sum of deposits (importe4>=importe3+importe2+importe1)
	local condition `patterns' & importe4>=importe3+importe2+importe1
	replace mechanical_effect = (importe1*(f4-f1)+importe2*(f4-f2)+importe3*(f4-f3))/n_days if `condition'
	replace mechanical_effect2 = (importe2*(f4-f2)+importe3*(f4-f3))/n_days if `condition'
	replace prop1 = 1 if `condition'
	replace prop2 = 1 if `condition'
	replace prop3 = 1 if `condition'
	// If W > D2 + D3, W < D1 + D2 + D3
	// Withdraw more than sum of second & third deposit (importe4>=importe3+importe2) but less than sum of all deposits (importe4<importe3+importe2+importe1)
	local condition `patterns' & importe4>=importe3+importe2 & importe4<importe3+importe2+importe1
	replace mechanical_effect = ((importe4-importe3-importe2)*(f4-f1)+importe2*(f4-f2)+importe3*(f4-f3))/n_days if `condition'
	replace mechanical_effect2 = (importe2*(f4-f2)+importe3*(f4-f3))/n_days if `condition'
	replace prop1 = (importe4-importe3-importe2)/importe1 if `condition'
	replace prop2 = 1 if `condition'
	replace prop3 = 1 if `condition'
	// If W > D3, W < D2 + D3, prop1=0, prop2 =(W-D3)/D2, prop3=1
	local condition `patterns' & importe4>=importe3  & importe4<importe3+importe2
	replace mechanical_effect = ((importe4-importe3)*(f4-f2)+importe3*(f4-f3))/n_days if `condition'
	replace mechanical_effect2 = (importe3*(f4-f3))/n_days if `condition'
	replace prop1 = 0 if `condition'
	replace prop2 = (importe4-importe3)/importe2 if `condition'
	replace prop3 = 1 if `condition'
	// If W < D3, prop1 = 0, prop2 = 0, prop3 = W/D3 
	local condition `patterns' & importe4<importe3
	replace mechanical_effect = (importe4*(f4-f3))/n_days if `condition'
	replace mechanical_effect2 = 0 if `condition'
	replace prop1 = 0 if `condition'
	replace prop2 = 0 if `condition'
	replace prop3 = importe4/importe3 if `condition'
		
	gen bimester_redefined = `bi'
	label values bimester_redefined bimes
	keep *id pattern bimester_redefined mechanical_effect* f? importe? days? prop? n_days
	save "$waste/transactions_patterns_`bi'.dta" , replace		
}

// ADD THE PATTERN VARIABLE TO MAIN DATA

forval bi = `startbim'(1)`endbim' {
	if `bi'==`startbim' use "$waste/transactions_patterns_`bi'.dta", clear
	else append using "$waste/transactions_patterns_`bi'.dta"
}

// Tab in order of frequency
fre pattern, descending // !user! written by Ben Jann

if !(`fast') {
	count if pattern=="" 
	assert r(N)==0 // No empty patterns
}

*****************************************************************************************************************
// Considering the effect of switches on the mechanical effect 
*****************************************************************************************************************

gen bimester_for_merge=bimester_redefined 
merge 1:1 integranteid bimester_for_merge using "$proc/shift_dates.dta", nogenerate  // Merging to get switch_date + importe which corresponds to an actual bimester (and not a bimester_redefined), file generated in 10_transactions_redef_bim (August 2017) 

// Gen shift component of the mechanical effect as: (transfer*remaining_days)/total_days

local T1 = td(1jan2007)
local T2 = td(1mar2007)
local T3 = td(1may2007)
local T4 = td(1jul2007)
local T5 = td(1sep2007)
local T6 = td(1nov2007)
local T7 = td(1jan2008)
local T8 = td(1mar2008)
local T9 = td(1may2008)
local T10 = td(1jul2008)
local T11 = td(1sep2008)
local T12 = td(1nov2008)
local T13 = td(1jan2009)
local T14 = td(1mar2009)
local T15 = td(1may2009)
local T16 = td(1jul2009)
local T17 = td(1sep2009)
local T18 = td(1nov2009)
local T19 = td(1jan2010)
local T20 = td(1mar2010)
local T21 = td(1may2010)
local T22 = td(1jul2010)
local T23 = td(1sep2010)
local T24 = td(1nov2010)
local T25 = td(1jan2011)
local T26 = td(1mar2011)
local T27 = td(1may2011)
local T28 = td(1jul2011)
local T29 = td(1sep2011)
local T30 = td(1nov2011)
local T31 = td(1jan2012)
local T32 = td(1mar2012)
local T33 = td(1may2012)
local T34 = td(1jul2012)
local T35 = td(1sep2012)
local T36 = td(1nov2012)

gen temp_mechanical = .

forvalues i = 1(1)35 {
	local j = `i'+1
	replace temp_mechanical = importe_shifted*(`T`j'' - shift_date)/(`T`j''-`T`i'') if  (`T`i'' <= shift_date) & (shift_date  <= `T`j'' )
}

gen mechanical_effect_shifted = mechanical_effect 
replace mechanical_effect_shifted = mechanical_effect + temp_mechanical if temp_mechanical != . 

**********
** SAVE **
**********
keep integranteid bimester* *mechanical* shift_date pattern importe* f?  days? prop? n_days
save "$proc/mechanical_effect`sample'.dta", replace
		
if `make_sample' {
	merge m:1 integranteid using `tosample'
	tab _merge 
	keep if _merge==3
	drop _merge
	count
	describe
	save "$proc/mechanical_effect_sample1.dta", replace
}

*************
** WRAP UP **
*************
cap log close
exit
