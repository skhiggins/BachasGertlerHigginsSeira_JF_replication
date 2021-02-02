** GENERATE GRAPHS OF WITHDRAWAL AND DEPOSIT DISTRIBUTIONS; EVENT STUDY FOR WITHDRAWALS
**  Pierre Bachas and Sean Higgins
**  Created 15April2016

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 106_withdrawals_deposits_graph
cap log close
local sample $sample 
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

*******************
** PRELIMINARIES **
*******************
// So that we can say in paper how many account-bimesters have >3 transactions
//  (to justify cutting at 3)
capture program drop proportion_morethan3
program define proportion_morethan3
	syntax varlist(max = 1) [if]
	local varname `varlist'
	if "`if'"=="" count 
	else count `if'
	local tot = r(N)
	if "`if'"=="" count if `varname' > 3
	else count `if' & `varname' > 3
	di r(N)/`tot'
end

**********
** DATA **
**********
use "$proc/account_withdrawals_deposits`sample'.dta", clear

//SUMMARY STATS ------------------------------------------------------------------
*** Number of observations (transactions) **********
count 
*** Number of unique IDs  **********
sort integranteid bimester_redefined, stable
by integranteid: gen nvals = _n == 1 
count if nvals
drop nvals
*** Number of unique IDs per bimester_redefined  **********
by integranteid bimester_redefined: gen nvals = _n == 1 
count if nvals
drop nvals

foreach N_X of varlist N_withdrawals N_client_deposits {
	preserve 
	
	*** Total amount 
	total `N_X'

	proportion_morethan3 `N_X' // overall average
	proportion_morethan3 `N_X' if t==0 
	proportion_morethan3 `N_X' if t==1
	proportion_morethan3 `N_X' if t==1 & pos_time_switch==0 
	proportion_morethan3 `N_X' if t==1 & pos_time_switch==1	
	
	// Top code at 4
	replace `N_X' = 4 if `N_X' >=4 
	
	count 
	tab `N_X' t , col

	// Pre-Post switch by wave
	forval i=1/2 {
		tab `N_X' t if pos_time_switch==0, col
		tab `N_X' t if pos_time_switch==1, col
	}
	
	// Place for histogram
	gen x = `N_X'*4
	replace x = x+1 if t==1 & pos_time_switch==0
	replace x = x+2 if t==1 & pos_time_switch==1
	
	gen category = .
	replace category =1 if t==0
	replace category =2 if t==1 & pos_time_switch==0
	replace category =3 if t==1 & pos_time_switch==1
	
	// NO TIME DIMENSION
	// Count how many deposits (frequency)
	bysort category `N_X': gen `N_X'_category = _N 
	bysort category : gen N_category = _N 
	gen freq = `N_X'_category/N_category 
	egen tag = tag(category `N_X')

	// For legend
	local label1 "Control" 
	local label2 "Treatment before cards"
	local label3 "Treatment after cards" 

	// GRAPH LOCALS
	forval color = 0/1 {
		if (`color') { // color version
			local suffix ""
			local orange "orange"
			local ltblue "ltblue"
			local blue   "blue"
		}
		else {
			local suffix "_bw"
			local orange "150 150 150" // used Instant Eyedropper and colorspace::desaturate() to determine
			local ltblue "224 224 224"
			local blue   "108 108 108" // manually made this one a bit darker to distinguish
		}

		# delimit ;
		local labsize huge ;
		graph_options, 
			labsize(`labsize') 
			y_labgap(labgap(1)) 
			ylabel_format(format(%2.1f)) 
			x_labgap(labgap(2)) 
			plot_margin(margin(l+5 r+2 b=0 t=0)) 
			title_options(
				size(`labsize') margin(b=1 t=1 l=0 r=0) span
			)
		;		
		local list_of_labels 1 "0" 5 "1" 9 "2" 13 "3" 17 "4 or more" ;
		local range range(0 20) ;
		
		if "`N_X'"=="N_withdrawals" { ;
			local _legend legend(off) ;
			local _ylabel
				ylabel(0(0.2)1, `ylabel_options') 
			;
			local _title "Panel A. Distribution of Withdrawals" ;
		} ;
		else { ;
			local _legend legend(on order(1 2 3) cols(1) ring(0) pos(3) 
				label(1 "`label1'") 
				label(2 "`label2'") 
				label(3 "`label3'") 
				size(`labsize')
				region(margin(t=0 l=0 r=0 b=0) 
				lcolor(white)) 
			);
			local _ylabel 
				ylabel(0(0.2)1, `ylabel_options_invis')
				yscale(noline)
			;
			local _title "Panel B. Distribution of Client Deposits" ;
		} ;

		twoway 
			(bar freq x if category==1 & tag==1, color("`orange'")) 
			(bar freq x if category==2 & tag==1, color("`ltblue'")) 
			(bar freq x if category==3 & tag==1, color("`blue'"))      
			, 
			xlabel(`list_of_labels', `xlabel_options')
			xscale(`range')
			`_ylabel'
			xtitle("") ytitle("") 
			title(`_title', `title_options')
			`_legend'
			`graphregion' `plotregion'
			name("`N_X'`suffix'", replace) 
		;

		#delimit cr
	
	} // end color = 0/1 loop
		
	restore	
	
} // end loop through outcome variables

// Combine into one graph
graph_options	// default no margin
graph combine N_withdrawals N_client_deposits  ///
	, imargin(sides) ysize(4) xsize(10) ycommon `plotregion' `graphregion' 

graph export "$graphs/dist_withdrawal_deposits`sample'_`time'.eps" , replace 

// Black and white version for print version of journal
graph combine N_withdrawals_bw N_client_deposits_bw  ///
	, imargin(sides) ysize(4) xsize(10) ycommon `plotregion' `graphregion' 
	
graph export "$graphs/dist_withdrawal_deposits_bw`sample'_`time'.eps" , replace 
 

*************
** WRAP UP **
*************
log close
exit

