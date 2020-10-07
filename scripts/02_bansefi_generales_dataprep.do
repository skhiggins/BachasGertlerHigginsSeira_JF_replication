** READ IN RAW BANSEFI DATA GIVEN TO US SEPTEMBER 3 2015
** Sean Higgins
** Created 5sep2015

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 02_bansefi_generales_dataprep
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

*************************
** READ & EXPLORE DATA **
*************************
quietly {
	clear
	#delimit ;
	infix 
			byte  idarchivo      1-1   /* Base1 = 1 [ATM] && Base2 = 2 [lottery]; 3=additional accounts of Base1, 4=additional accounts of Base2 */
			str9	num_cliente    2-10  /* Número de Cliente BANSEFI */
			str10	cuenta        11-20  /* Número de cuenta BANSEFI */
			byte  grupo         21-21  /* Dato proporcionado por el Dr. Higgins */
			byte  prioridad		  22-22  /* Dato proporcionado por el Dr. Higgins */
			str7  prod_ven      23-29  /* Producto pertenece la cuenta (23-26) Tarifa pertenece la cuenta (27-29) */
			str8  fecalta       30-37  /* Fecha de alta de la Cuenta BANSEFI (AAAAMMDD) */
			str8  fecbaja       38-45  /* Fecha de baja de la Cuenta BANSEFI (AAAAMMDD) default 19000101 */
			byte  estatus       46-46  /* 4 = Activa, 7 = Cancelada */
			str9	integranteid	47-55  /* Identificador único del Programa PROSPERA */
		using "$data/Bansefi/DatosGenerales.txt"
	;
	label define grupos 
		1 "Always debicuenta"
		2 "Always cuentahorro (control)"
		3 "Switched (waves 1 and 2)"
	;
	label values grupo grupos;
	#delimit cr
	count
	noisily mydi "Total observations: `r(N)'", s(4)
	replace fecbaja = "" if fecbaja=="19000101" // default (i.e. not dropped)
	foreach var in grupo idarchivo prioridad {
		noisily mydi "`var' tabulation", stars(3) starchar("!")
		noisily tab `var', missing
	}
	assert idarchivo>1 if missing(integranteid) // these are non-Oportunidades accounts
	foreach var of varlist * {
		noisily mydi "`var'", stars(3) starchar("!")
		count if mi(`var')
		local n_mi = r(N)
		count
		noisily di "Proportion missing: " `n_mi'/r(N)
		noisily exampleobs `var' if !mi(`var'), n(50)
	}
	save "$proc/DatosGenerales.dta", replace
}

*************
** WRAP UP **
*************
log close
exit

