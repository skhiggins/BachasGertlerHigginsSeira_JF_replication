** PREPARE ITER DATA ON LOCALITIES FOR BALANCE TABLE 
** Sean Higgins
** Created 19jul2014

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 57_iter_locality_dataprep
cap log close
set linesize 200
log using "$logs/`project'_`time'`sample'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local yearlist 2005

** locals to account for differences in years
foreach y in 2005 {
	local s`y' v11-v130
	local pob`y' v10
	local loc`y' v5
	local mun`y' v3
	local ent`y' v1
}

** TREATMENT LOCALITIES
insheet using "$data/Prospera/1. Modelo_Urbano_263-Locs.csv", clear comma
levelsof cveofi, local(localities)

** INITIAL READ-IN
foreach y of local yearlist {
	local yy = substr("`y'",3,2)
		
	** load and clean data
	insheet using "$data/ITER/`y'/ITER_NALTXT`yy'.txt", clear
	lower *
	foreach var of varlist `s`y'' {
		destring `var', ignore("* N/D") replace
	}
	gen double localidad = `loc`y'' + 10000*`mun`y'' + 10000000*`ent`y''
	format localidad %10.0f
	replace localidad = . if `loc`y''==0 | `loc`y''==9998 | `loc`y''==9999
		// these are the aggregate level like state, municipality
	
	** create treatment var
	gen T = 0
	foreach x of local localities {
		replace T = 1 if localidad==`x'
	}
	replace T = . if `pob`y''<15000 | missing(`pob`y'') | missing(localidad)
		// for non-urban localities (missing(localidad) is for the aggregate obs like state and locality level)
	tab T, m 
	
	gen lpob = ln(`pob`y'')
	
	keep if T != .
	save "$proc/iter`yy'u.dta", replace
}
