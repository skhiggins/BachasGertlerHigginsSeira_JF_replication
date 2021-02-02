** PREPARING LOCALITY DATA FOR BALANCE TABLES
**  Sean Higgins
**  created July 2014

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 58_locality_dataprep
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

**********
** DATA **
**********
// Locality level data
use "$data/CONEVAL/rezago_social_localidad.dta", clear // see CONEVAL/Notes.txt for where downloaded this dta
format clave %10.0f
rename clave localidad
lower
merge 1:1 localidad using "$proc/iter05u.dta", gen(m_coneval_iter) // T already defined in this data
	// census_dataprep.do
rename v110 pro_ocup_c // Promedio de ocupantes por cuarto

**********
** SAVE **
**********
order localidad nom* ///
	T /// 
	poblacion_total 
save "$proc/urban_locs.dta", replace

*************
** WRAP UP **
*************
log close
exit
