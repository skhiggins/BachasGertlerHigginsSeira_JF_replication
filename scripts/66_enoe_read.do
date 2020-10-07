// READ IN ENOE AND CREATE WAGE VARIABLE
//  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 66_enoe_read
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

**********
** DATA **
**********
// Note: full ENOE data set is large; read in just relevant variables
use year quarter cod_municipality fac rama* ///
	p1 p1a1 p1a2 p1a3 p1b p1c p1d p1e p3 p3a p3b p4a p6b1 p6b2 ///
	p7a p7b p7c p7gcan p9* using /// p9* are about previous jobs
	"$data/ENOE/employ_survey_dataset.dta", clear
	// raw merged ENOE sent by Laura Chioda
	
describe

// Note there's already a rama variable but it's just values 0-7
tab rama
tab rama_est1
drop rama*
	
// Look at what the SINCO and SCIAN (NAICS) code variables look like
exampleobs p3
exampleobs p7a
exampleobs p4a
exampleobs p7c
exampleobs p9i

// Convert to strings and create additional variables
gen sinco = string(p3)	
gen sinco2 = string(p7a)
gen rama = string(p4a)
gen rama2 = string(p7c)
gen rama_former = string(p9i)
gen subsector = substr(rama, 1, 3)
gen subsector2 = substr(rama2, 1, 3)
gen subsector_former = substr(rama_former, 1, 3)
gen sector = substr(rama, 1, 2)
gen sector2 = substr(rama2, 1, 2)
gen sector_former = substr(rama_former, 1, 2)

tab p1 if p9==1 // se quedo sin trabajo o negocio y tuvo que buscar otro

tab subsector

// Create monthly wage variable
//  p6b1: frequency with which they report payment
fre p6b1, descending

//  p6b2: amount paid
summ p6b2
count if p6b2 == 999998 
replace p6b2 = . if p6b2 == 999998 

gen wage = .
replace wage = p6b2 if p6b1==1           // Cada mes
replace wage = p6b2*2 if p6b1==2         // Cada 15 dias
replace wage = p6b2*(52/12) if p6b1==3   // Cada semana
replace wage = p6b2*(52/12)*5 if p6b1==4 //http://ajasociados.blogspot.com/2018/03/como-se-obtiene-el-2383-de-dias.html
	// 5 otro periodo de pago has only 0.6% of obs
	// 6 Le pagan por pieza has only 0.1% of obs
	// 7 No supo estimar; 8 Se negó contestar
	//  have a significant amount (17% of obs) but 
	//  if they answer these, the peso question is incomplete

// employed?
fre p1*, descending
gen employed = (p1 == 1 | p1a1 == 1 | p1a2 == 2)

** keep year quarter cod_municipality wage* employed *sector*
	// less variables so easier to work with

**********
** SAVE **
**********
// Save, then do the regressions in R
save "$proc/enoe_all.dta", replace

*************
** WRAP UP **
*************
log close
exit

