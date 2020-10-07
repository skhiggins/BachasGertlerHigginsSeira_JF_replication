** HISTOGRAM OF MONTHS WITH CARD IN PAYMENT METHODS SURVEY
**  Sean Higgins

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 113_medios_histogram_graph
cap log close
set linesize 200
log using "$logs/`project'`sample'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

**********
** DATA **
**********
use "$data/Medios_de_Pago/medios_pago_titular_beneficiarios.dta" , clear

count // 5381

// Keep Sample of DebiCuenta (debit card) users
keep if t325 == 1 
	// 1 [N=1641] Tarjeta que pude usarse en cajeros y autoservicios (débito) 
	// 2 [N=3715] Tarjeta con huella (prepagada)
	// 3 [N=  25] Otra (especifique) // note I made sure none of these descriptions (t325es) are tarjeta de debito  
count // 1641
drop if mi(t4a01a) // added by Sean; some weren't asked part IV of the survey so they have missing for all vars
count // 1617

** tab t4a01a if t4a01b==99 // see if some where they reported years but not months; result: no
replace t4a01a=. if t4a01a==9
replace t4a01b=. if t4a01b==99 // note Pierre had ==9, but it should be ==99
gen months_card = t4a01a*12+t4a01b
sum months_card, d
** histogram months_card, discrete // look at distribution 

tab months_card

replace months_card = 42 if months_card>42 // top code at max value
#delimit ;
hist months_card, freq
	color(gray)
	xtitle("Months with card when surveyed", margin(top))
	xlabel(, notick nogrid)
	ylabel(, notick nogrid angle(horizontal))
	ytitle("Frequency", margin(right))
	graphregion(margin(l+2 r+4) fcolor(white) lstyle(none) lcolor(white))
	plotregion(margin(none) fcolor(white) lstyle(none) lcolor(white)) 
	start(0) width(1)
;
#delimit cr

graph export "$graphs/hist_medios_de_pago.eps", replace  

*************
** WRAP UP **
*************
log close
exit
