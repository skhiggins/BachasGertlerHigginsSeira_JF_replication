** TESTING EXPANSION OF BANSEFI SUCURSALES IN CNBV DATA
** Sean Higgins
** Created 01aug2015

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 50_cnbv_bd_sucursales
set linesize 200
cap log close
log using "$logs/`project'`sample'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local proj bd_sucursales
local numsuc_rename sucursales // to be consistent with names in
local numcajaut_rename cajeros //  banca multiple files

*********
** DATA *
*********
foreach var in numsuc numcajaut {
	local files : dir "$data/CNBV/BancaDesarrollo/" files "*`var'*"
	di `"`files'"' // "
	// Test what bimester they changed the locality codes
	local i=0
	local max_unique=0
	local changeat = . 
	foreach file of local files {
		local ++i
		
		// Parse month and year from file name:
		local re_file = regexm("`file'","([0-9][0-9][0-9][0-9])([0-9][0-9])")
		local yearmonth = real(regexs(0))
		local year      = real(regexs(1))
		local month     = real(regexs(2))
		mydi "`yearmonth'", s(4)
		
		// DATA
		qui insheet using "$data/CNBV/BancaDesarrollo/`file'", clear
		qui replace estado = estado[_n-1] if mi(estado) // note this is recursive
		qui drop if mi(localidad) | localidad=="(en blanco)" // these are state aggregates
		tab estado if !mi(estado)
		unab clavelocalidad : c*localidad, max(1) // because for some months 
			// clavelocalidad is the variable name and for others cvelocalidad
		local t_clavelocalidad : type `clavelocalidad'
		if !(strpos("`t_clavelocalidad'","str")) { // if `clavelocalidad' is not a string var
			// Had to do a bizarre work-around because I was getting type mismatch error:
			tempvar str_clavelocalidad
			gen str16 `str_clavelocalidad'=string(`clavelocalidad',"%16.0f")
			replace `str_clavelocalidad'="" if `str_clavelocalidad'=="."
			drop `clavelocalidad'
			gen str16 `clavelocalidad' = `str_clavelocalidad'
		}
		uniquevals `clavelocalidad'
		gen l_clavelocalidad = length(`clavelocalidad')
		qui summ l_clavelocalidad, meanonly
		if r(max)>4 { // INEGI locality codes
			// Just as a check:
			cap assert !mi(`clavelocalidad')
			if _rc list localidad if mi(`clavelocalidad')
			else di "No mi(`clavelocalidad')" 

			// Fix locality codes:
			replace `clavelocalidad' = `clavelocalidad'[_n-1] if mi(`clavelocalidad')
			cap drop __*
			list `clavelocalidad' if !(length(`clavelocalidad')==12)
			* br if !(length(`clavelocalidad')==12)
			assert length(`clavelocalidad')==12 // for some reason 
				// they preceded the INEGI locality codes with prefixes
			ds e*do *localidad*, not // saved in r(varlist)
			collapse (sum) `r(varlist)', by(`clavelocalidad')
			drop if substr(`clavelocalidad',1,3)!="484" 
				// Mexico is 484; other codes are for branches in other countries
			di "`yearmonth'"
			replace `clavelocalidad' = substr(`clavelocalidad',4,.)
			assert  length(`clavelocalidad') == 9
			exampleobs `clavelocalidad' // Sean's user-written ado file
			qui dupcheck `clavelocalidad', assert
			
			if `yearmonth'<`changeat' {
				local changeat `yearmonth' // they changed to INEGI locality codes in this month 
				di "change at `changeat'"
			}
			gen yearmonth = `yearmonth'
			gen year  = `year'
			gen month = `month'
			
			tempfile f_`yearmonth'
			save `f_`yearmonth'', replace
		}
	}
	foreach file of local files {
		local re_file = regexm("`file'","([0-9][0-9][0-9][0-9])([0-9][0-9])")
		local yearmonth = real(regexs(0))
		if `yearmonth'==`changeat' use `f_`yearmonth'', clear
		else if `yearmonth'>`changeat' append using `f_`yearmonth''
		// else do nothing
		unab clavelocalidad : c*localidad, max(1) // because for some months 
			// clavelocalidad is the variable name and for others cvelocalidad
		qui dupcheck `clavelocalidad' yearmonth, assert
	}

	// SUMMARY OF TOTAL BANSEFI BRANCHES/ATMs IN COUNTRY BY MONTH
	levelsof yearmonth, local(yearmonths)
	local rows = wordcount("`yearmonths'")
	matrix results = J(`rows',2,.)
	local row = 0
	foreach yearmonth of local yearmonths {
		local ++row
		summ bansefi if yearmonth==`yearmonth'
		matrix results[`row',1] = `yearmonth'
		matrix results[`row',2] = r(sum)
	}
	assert `row' == `rows' // double check matrix filled correctly
	matlist results

	save "$proc/bd_``var'_rename'_month.dta", replace
	
	
} // end loop over `var' (branches and ATMs)

*************
** WRAP UP **
*************
log close
exit
