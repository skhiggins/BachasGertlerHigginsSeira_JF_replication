** TO WINSOR WITHIN EACH TIME PERIOD AND WITHIN TREATMENT/CONTROL
** Sean Higgins
** Created around May 2015

*! 1.2 skh 02aug2016
** 1.1 skh 30sep2015

** REQUIRED ADO FILES
**  -mywinsor- (included below) (Modified version of Nick Cox's winsor, modified by Sean Higgins)
**  

** CHANGES
**   8-02-2016 Added -stable- option to -sort- in -mywinsor-
**   9-30-2015 Made it its own ado file rather than a program in a header file
**             More flexibility: 
**              -Added timevar(varname) option
**              -Treatment var can be any values not just 0/1

capture program drop winsify
program define winsify
	#delimit ;
	syntax varname [if/] [in], 
		[
		winsor(real 1) 
		timevar(varlist) 
		timevar_levels(string) /* to avoid time-consuming levelsof */
		treatment(varlist) 
		treatment_levels(string) /* to avoid time-consuming levelsof */
		gen(string) 
		replace
		highonly
		]
	;
	#delimit cr
	
	local die display as error in smcl
	
	if "`if'"!="" {
		local _if "if `if'" // doesn't include if alraeady dt /
		local _andif "& `if'"
	}
	
	// Winsor option
	if !(`winsor'>0 & `winsor'<50) {
		`die' "Winsor must be a number between 0 and 50 denoting the percent of the sample to be winsorized"
	}

	// Generate and replace options
	if "`gen'"!="" {
		confirm new variable `gen'
		qui gen `gen' = `varlist' `_if' `in'
	}
	else if "`replace'"=="" { // ie. both gen and replace are not specified
		`die' "Must specify either {bf:gen} or {bf:replace} option"
	}
	else {
		tempvar gen
		qui gen `gen' = `varlist' `_if' `in'
	}
	
	// Timevar option
	if "`timevar'"!="" {
		if "`treatment_levels'"=="" {
			quietly levelsof `timevar' `_if' `in', local(timevar_levels)
		}
	}
	else {
		tempvar timevar
		quietly gen `timevar' = 1 `_if' `in'
		local timevar_levels 1
	}
	
	// Treatment option
	if "`treatment'"!="" {
		if "`treatment_levels'"=="" {
			quietly levelsof `treatment' `_if' `in', local(treatment_levels)
		}
	}
	else {
		tempvar treatment
		quietly gen `treatment' = 1 `_if' `in'
		local treatment_levels 1
	}
	
	foreach timevar_level of local timevar_levels {
		foreach treatment_level of local treatment_levels {
			tempvar w_`timevar_level'_`treatment_level'
			#delimit ;
			quietly count 
				if `timevar'==`timevar_level' & 
				   `treatment'==`treatment_level' &
				   !missing(`varlist')
				   `_andif'
			;
			if r(N)<=2 continue;
			mywinsor `varlist' 
				if `timevar'==`timevar_level' & 
				   `treatment'==`treatment_level' 
				   `_andif'
				, 
				p(`=`winsor'/100') 
				gen(`w_`timevar_level'_`treatment_level'') 
				`highonly'
			;
			quietly replace `gen' = `w_`timevar_level'_`treatment_level''
				if `timevar'==`timevar_level' & 
				   `treatment'==`treatment_level' 
				   `_andif'
			;
			#delimit cr
		}
	}
	
	if "`replace'"!="" quietly replace `varlist' = `gen' `_if' `in'

end


// REVISED VERSION OF NICK COX'S -winsor-
// CHANGES: 
//  replaced int() with round() so that e.g. if 1% is 4.6 observations,
//   it will winsor based on 5 rather than 4
//  to correct problem if e.g. 50 < N < 100 and p(0.1) specified, will winsorize 1 obs
//  whereas Cox's version would give error

** 1.3.0 NJC 20 Feb 2002 edited by Sean Higgins 8 July 2015
** 1.2.0 NJC 9 Feb 2001 
** 1.1.0 NJC 23 Nov 1998
** works with strings: not obviously useful, but the generalisation is cheap
** bug fix if p small implies h of 0
** 1.0.0 NJC 18 Nov 1998
program def mywinsor, sortpreserve 
        version 7.0
        syntax varname [if] [in] /* 
	*/ , Generate(str) [ H(int 0) P(real 0) LOWonly HIGHonly ] 

        capture confirm new variable `generate'
	if _rc { 
		di as err "generate() should give new variable name"
		exit _rc
	}	
		
	if `h' == 0 & `p' == 0 {
                di as err "h() or p() option required, h( ) or p() > 0"
                exit 198
        }
        else if `h' > 0 & `p' > 0 {
                di as err "use either h() option or p() option"
                exit 198
        }
        else if `h' < 0 | `p' < 0 {
                di as err "invalid negative value"
                exit 198
        }

        if `p' >= 0.5 {
                di as err "p() too high"
                exit 198
        }
	
	marksample touse, strok
	qui count if `touse'
	if r(N) == 0 { error 2000 } 
        local use = r(N)
        local notuse = _N - `use'

	if "`lowonly'`highonly'" != "" { 
		local text = /*
		*/ cond("`lowonly'" != "", ", low only", ", high only")
	} 	
	
        if `p' > 0  {
                local h = max(round(`p' * `use'),1)
                if `h' == 0 {
                        di as err "0 values to be Winsorized"
                        exit 198
                }
                local which "Winsorized fraction `p'`text'"
        }
        else local which "Winsorized extreme `h'`text'"

        if `h' >= (`use' / 2) {
                di as err "`h' values to be Winsorized, `use' in data"
                exit 198
        }

        sort `touse' `varlist', stable
        local type : type `varlist'
        qui gen `type' `generate' = `varlist' if `touse'

        if "`lowonly'" == "" { 
		** replace upper tail by highest acceptable value
		local hiacc = _N - `h'
		local hiaccp1 = `hiacc' + 1
		qui replace `generate' = `generate'[`hiacc'] in `hiaccp1'/l
	}

	if "`highonly'" == "" { 
	        ** replace lower tail by lowest acceptable value
        	local loacc = `notuse' + `h' + 1
	        local loaccm1 = `loacc' - 1
        	local lowest = `notuse' + 1
	        qui replace `generate' = /* 
		*/ `generate'[`loacc'] in `lowest'/`loaccm1'
	}	

        local fmt : format `varlist'
        format `generate' `fmt'

        label var `generate' "`varlist', `which'"
end
