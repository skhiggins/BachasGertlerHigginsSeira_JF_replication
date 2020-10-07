** ENCELURB 2004 DATA PREP
**  Sean Higgins
**  created July 7 2014

************
** LOCALS **
************
local year 2004
local yy = substr("`year'",3,2)

local notdurables 01 07 // 01 is festividades escolares; 07 includes some durables (jewelry) but
	// also nondurables (vacations) in same category
local weeks_per_month = 30/7 // because they don't actually ask about last month, they ask
	// "en los últimos 30 días"
local weeks_per_month_precise = 4.34524 // goo.gl/lvFss5
local weeks_per_year = 52.1429 // goo.gl/3Ttao7

local jefe s03c09
local the_male   sexo==1 & (`jefe'==1 | `jefe'==2)
local the_female sexo==2 & (`jefe'==1 | `jefe'==2)

**********
*** LOG **
**********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 61_encelurb_dataprep_`year'
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

**************************
** PRELIMINARY PROGRAMS **
**************************
// Load in preliminary programs 
include "$scripts/encelurb_dataprep_preliminary.doh" // !include!

**********
** DATA **
**********
*********************************
** PRIVATE TRANSFERS IN AND OUT *
*********************************
use "$data/ENCELURB/`year'/socio_monetarias_desde_hogar.dta", clear
lower
gen transfer_out_dummy = 1 // this data set only includes those that did have a transfer out
	// (want to have transfer_out_dummy==1 even for those who don't remember amount transfered)
clean9s s11c0601, l(5) v(desde_hogar) nine(s11c0602) // double checked that this works
collapse (sum) desde_hogar (max) transfer_out_dummy f?_*, by(id_hogar) // note collapse (sum) treats . as 0 so need next line
postcollapse s11c0601, v(desde_hogar) // does replace desde_hogar3 = . if f1_s14a0601==1 // 99998; 
									  //      replace desde_hogar4 = . if f2_s14a0601==1 // 99998 or 99999
rename id_hogar folio
save "$waste/encel`yy'_desde_hogar.dta", replace

use "$data/ENCELURB/`year'/socio_especie_desde_hogar.dta", clear
lower
gen e_transfer_out_dummy = 1 // e_.. for "en especie" (in kind)
	// this data set only includes those that did have an in-kind transfer out
	// (want to have transfer_out_dummy==1 even for those who don't remember amount transfered)
clean9s s12c0601, l(5) v(desde_hogar) nine(s12c0601) // double checked that this works
collapse (sum) desde_hogar (max) e_transfer_out_dummy f?_*, by(id_hogar) // note collapse (sum) treats . as 0 so need next line
postcollapse s12c0601, v(desde_hogar) // does replace desde_hogar3 = . if f1_s14a0601==1 // 99998; 
									  //      replace desde_hogar4 = . if f2_s14a0601==1 // 99998 or 99999
rename id_hogar folio
save "$waste/encel`yy'_desde_hogar_e.dta", replace

use "$data/ENCELURB/`year'/socio_monetarias_hacia_hogar.dta", clear
lower
gen transfer_in_dummy = 1
clean9s s13c0601, l(5) v(hacia_hogar) nine(s13c0602)
collapse (sum) hacia_hogar (max) transfer_in_dummy f?_*, by(id_hogar)
postcollapse s13c0601, v(hacia_hogar)
rename id_hogar folio
save "$waste/encel`yy'_hacia_hogar.dta", replace

use "$data/ENCELURB/`year'/socio_especie_hacia_hogar.dta", clear
lower
gen e_transfer_in_dummy = 1
clean9s s14c0601, l(5) v(hacia_hogar) nine(s14c0602)
collapse (sum) hacia_hogar (max) e_transfer_in_dummy f?_*, by(id_hogar)
postcollapse s14c0601, v(hacia_hogar)
rename id_hogar folio
save "$waste/encel`yy'_hacia_hogar_e.dta", replace

***********************************************
*** SOCIOECONOMIC VARS FROM IND DATA FOR 2004 **
***********************************************
use "$data/ENCELURB/`year'/socio_personas_soc.dta", clear
lower // Sean's user written ado file, changes all varnames to lowercase
rename id_hogar folio
sort folio, stable

// SOCIODEM CHAR
** note sexo and edad already named as such
#delimit ;
sociodem , /* sociodem subroutine defined in encelurb_dataprep_preliminaries.doh */
	edad(edad) 
	sexo(sexo) 
	jefe(`jefe')
	casado(s03c13)
	casado_vals("1,2")
	asistio(s05c17)
	nivel(s05c0201)
	grado(s05c0202)
	leer(s05c01)
	trabajo(s06c01)
	trabajo2(s06c02)
	encel04
;
#delimit cr

// age of man and woman
gen edad_m = edad if `the_male'
gen edad_f = edad if `the_female'

// HEALTH INSURANCE
gen healthinsurance = (s03c1201!=0)
replace healthinsurance = . if s03c1201==9 // "No sabe" 50 obs
gen seguropopular = (s03c1201==4 | s03c1202==4)

// ESCOLARIDAD
gen analfabeto_m = analfabeto if `the_male'
gen analfabeto_f = analfabeto if `the_female'

** s05c0201 = nivel
** 0 Ninguno
** 1 Kinder o preescolar
** 2 Primaria
** 3 Secundaria
** 4 Preparatoria o Bachillerato
** 5 Normal
** 6 Carrera técnica o Comercial
** 7 Profesional o Superior
** 8 Maestría o Doctorado
** 9 No sabe

gen asiste = (s05c04==1) if edad>=5 & edad<=25 // missing for those not asked the question
replace asiste = 1 if s05c04==9 & s05c17==1 & (edad>=5 & edad<=25) // use previous year
gen asistio = (s05c17==1) if edad>=5 & edad<=25 // anio escolar pasado

gen escolaridad_m = escolaridad if `the_male'
gen escolaridad_f = escolaridad if `the_female'

gen menos_9 = (escolaridad<9)
	
mtab escolaridad

// HOUSEHOLD LEVEL VARS
hhlevel // in encelurb_dataprep_preliminary.do

// SAVE
save "$waste/encel`yy'_ind.dta", replace

// SPENDING FROM INDIVIDUAL LEVEL DATA (TRANSPORT, SCHOOL, HEALTH)
use "$data/ENCELURB/`year'/socio_personas_soc.dta", clear
lower // Sean's user written ado file, changes all varnames to lowercase
rename id_hogar folio
sort folio, stable
local s s05c
#delimit ;
local educ_ /* año pasado */
	`s'2801 /* colegiaturas */
	`s'2901 /* uniformes, libros, cuadernos */
	/* note transporte is separate under transport */
	/* `s'3101 */ /* cuanto le daba para gastar (presumably on school expenses b/c in that section */
;
local educ_nine 
	`s'2802 
	`s'2902 
	/* `s'3102  */
;
local transport_educ_ /* a la semana */
	`s'3001
;
local transport_educ_nine
	`s'3002
;
local ss s04c;
local health_
	`ss'0401 /* appointments (1) */
	`ss'0403 /* appointments (2) */
	`ss'0405 /* appointments (3) */
	`ss'0501 /* medicine (1) */
	`ss'0503 /* medicine (2) */
	`ss'0505 /* medicine (3) */
;
local health_nine
	`ss'0402
	`ss'0404
	`ss'0406
	`ss'0502
	`ss'0504
	`ss'0506
;
local hospital_ /* últimas 4 semanas */
	`ss'1001
;
local hospital_nine
	`ss'1002
;
local toclean_4 
	educ 
	transport_educ 
	health
;
local toclean_6
	hospital
;
local anual 
	educ
	hospital
;
local 4weeks
	health
;
#delimit cr
local collapselist ""
forval i=3/6 {
	foreach toclean of local toclean_`i' {
		clean9s ``toclean'_', l(`i') v(cons_`toclean') nine(``toclean'_nine')
		local collapselist `collapselist' cons_`toclean'
	}
}
foreach v of local anual {
	replace cons_`v' = cons_`v'/`weeks_per_year' // weekly
}
foreach v of local 4weeks {
	replace cons_`v' = cons_`v'/4 // weekly
}
collapse (sum) `collapselist' (max) f?_*, by(folio)

// SAVE
save "$waste/encel`yy'_spending_ind.dta", replace

// INCOME
use "$data/ENCELURB/`year'/socio_personas_soc.dta", clear
lower // Sean's user written ado file, changes all varnames to lowercase
rename id_hogar folio
sort folio, stable

local i=1
local p s06c // prefix
** checking for outliers
foreach x in 10 16 {
	mydi "`x'"
	forval j=1/5 {
		di "`j'"
		count if `p'`x'02==`j' & !mi(`p'`x'01)
		if r(N)!=0 extremes `p'`x'01 if `p'`x'02==`j', n(20) hi clean
	}
}
foreach x in 10 16 {
	local 1 `p'`x'01 // amount
	local 2 `p'`x'02 // periodo
	local x2 = `x' + 2
	
	** extreme outliers
	daywk_outliers `1' `2'
	gen `p'`x'_an = 0 // _an = anual
	replace `p'`x'_an = `1'*365/(7/5) if `2'==1 // daily - assume 5 d/wk work
	replace `p'`x'_an = `1'*(365/7)  if `2'==2 // weekly
	replace `p'`x'_an = `1'*(365/15) if `2'==3 // quincena
	replace `p'`x'_an = `1'*12       if `2'==4 // monthly 
	replace `p'`x'_an = `1'*1        if `2'==5 // annual
	replace `p'`x'_an = `1' if `1'==99998 | `1'==9998 // leave as is if top coded
	gen f_labincome`i' = (`2'==9)
	** portion of year worked
	local wk `p'`x2'01
	local mo `p'`x2'02
	tempvar mi_portion
	recode `wk' (99 = 0)
	replace `wk' = 0 if `mo'>0 & `mo'<99 & `wk'>4
	gen portion`i' = (`mo'+(`wk'/4))/12 if `mo'>0 
	replace portion`i' = `wk'/52 if `mo'==0
	replace portion`i' = 1 if `mo'==99 | `mo'==12
	assert portion`i' <= 1 if !mi(portion`i')
	// confirmed that results are robust to instead using portion=1 for all
	replace `p'`x'_an = `p'`x'_an*portion`i' if !mi(portion`i')
	local ++i
}
clean9s `p'10_an `p'16_an `p'1901, l(5) v(labincome) nine(`p'1002 `p'1602 `p'1902) // 2102 is aguinaldo
local pp s06c20
local list1
local list2
*** look for outliers
forval i = 1(2)7 {
	mydi "`i'", s(2)
	local i1 = `i'+1
	forval j=1/5 {
		di "`j'" 
		count if `pp'0`i1'==`j' & !mi(`pp'0`i')
		if r(N)!=0 extremes `pp'0`i' if `pp'0`i1'==`j', n(20) hi clean
	}
}
forval i=1(2)9 {
	local i1 = `i' + 1
	local i = "0" + "`i'"
	if length("`i1'")==1 local i1 = "0" + "`i1'"
	** extreme outliers
	daywk_outliers `pp'`i' `pp'`i1'
	gen `pp'`i'_an = 0
	if inlist(`i',1,3) { // for income placebo, doesn't make a difference what you do with these
		// Same as 2003 (but different from 2002)
		//  1 otros trabajos o actividades que no se hayan registrado antes
		//  3 retiro, jubilacion o pension por vejez. liquidación o indemnizacion laboral por accidente, pension alimenticia, invalidez o viudez
		//  5 venta/renta de activos de su propiedad (casa, carro, aparatos electrodomésticos, tractor, yunta, etc.)
		//  7 otro motivo que no sea su trabajo, como herencias o juegos de azar
		//  9 regalos, donaciones, envíos de dinero o ayudas gubernamentales
		// NOTE: EXCLUDE 9 SINCE TRANSFERS IN/OUT ACCOUNTED FOR ELSEWHERE, OP TRANSFERS FROM ADMIN DATA
		replace `pp'`i'_an = `pp'`i'*365/(7/5) if `pp'`i1'==1 // assume 5 days per week
		replace `pp'`i'_an = `pp'`i'*(365/7)  if `pp'`i1'==2
		replace `pp'`i'_an = `pp'`i'*(365/15) if `pp'`i1'==3
		replace `pp'`i'_an = `pp'`i'*12       if `pp'`i1'==4
		replace `pp'`i'_an = `pp'`i'*1        if `pp'`i1'==5
		replace `pp'`i'_an = `pp'`i' if `pp'`i'==99998 | `pp'`i'==9998 // leave as is if top coded
		gen byte f_otherinc`i' = (`pp'`i1'==9)
	}
	else if !inlist(`i',9) {
		replace `pp'`i'_an = `pp'`i' if !mi(`pp'`i')
		gen byte f_otherinc`i' = 0 // since assuming paid once per year and ignoring `pp'`i1'
	} 
	local list1 `list1' `pp'`i'_an
	local list2 `list2' `pp'`i1'
}
clean9s `list1', l(5) v(othincome) nine(`list2')

foreach var of varlist ???income {
	gen `var'_f = 0
	gen `var'_m = 0
	replace `var'_f = `var' if `the_female'
	replace `var'_m = `var' if `the_male'
}

collapse (sum) ???income* (max) f?_* drop, by(folio)
postcollapse `p'10_an `p'16_an `p'1901, v(labincome)
postcollapse `list1', v(othincome)
save "$waste/encel`yy'_income.dta", replace

**********************************************
** SOCIOECONOMIC VARS FROM HH DATA FOR 2004 **
**********************************************
use "$data/ENCELURB/`year'/socio_hogares_soc.dta", clear
lower // Sean's user written ado file, changes all varnames to lowercase
rename id_hogar folio
drop if resf>2
** resf Resolución final: 1 Entrevista completa 2 Entrevista incompleta 3 Informante inadecuado 4 Entrevista aplazada (hacer cita) 5 Ausencia de ocupantes en el momento de la visita 6 Se negó a dar información 11 Vivienda no localizada 12 Otro (especifique en observaciones) 
localidades
gen year = `year'
local klist folio** localidad *ent *mun *loc** ageb manzana year

** CREATE folio_manz VARIABLE WHICH WAS INCLUDED IN 2002, 2003 BUT NOT 2004
gen folio_manz = s_ent + s_mun + s_loc + s_ageb + s_manzana

// CARACTERISTICAS DE LA VIVIENDA 
** NOTE: no var for whether they have electricity
gen piso_tierra = (s01c01==1) // what about ==3?
** s01c01 ¿De qué material es la mayor parte del piso de esta vivienda? 1 Tierra 2 Cemento o firme 3 Mosaico, madera u otros recubrimientos 
gen sin_sanitario = (s01c12!=1)
** s01c12 ¿Esta vivienda tiene:  1 excusado o sanitario?  2 letrina o retrete?  3 fosa?  4 hoyo negro o pozo ciego?  5 No tienen servicio sanitario (hacen en donde quieren)? 
gen sin_agua = (s01c08==2) | (s01c09==2) // Note: used to be (s01c08==2 & s01c10!=1) | (s01c09==2) but I realized that if they answer No to s01c08 then the agua por pipa they are getting for s01c10 they probably have to go fetch (see discussion here http://goo.gl/oXyHlb)
** s01c08 ¿Llega el agua entubada al terreno? 1 Si 2 No (skip to c10)
** s01c09 ¿Llega el agua entubada al interior de la vivienda? 1 Si (to c11) 2 No (to c11)
** s01c10 ¿De dónde toman el agua para preparar los alimentos? 1 Agua por pipa del servicio público 2 Agua por pipa del servicio particular 3 Pozo 4 Agua por acarreo 5 Otro 
gen sin_drenaje = (s01c14==2)
** s01c14 ¿La vivienda cuenta con desagüe de aguas sucias? 1 Si 2 No
recode s01c05 s01c04 (99 = .)
rename s01c05 n_cuartos // Sin contar pasillos, baños ni cocina, ¿cuántos cuartos tiene en total esta vivienda?
rename s01c04 n_cuartos_dormir // for #personas/cuarto
rename s02c01 n_personas 
recode n_cuartos_dormir (0 = 1) // otherwise dividing by zero
gen oc_por_cuarto = n_personas/n_cuartos_dormir
local klist `klist' piso_tierra sin_* n_* oc_*

// BANK ACCOUNT AND SAVINGS DUMMIES
gen ahorro_pasado   = (s09c01==1)
gen cuenta_bancaria = (s08c01==1)
gen ahorro_actual   = (s10c01==1)
local klist `klist' cuenta_** ahorro_*

// SHOCKS
gen siniestro = 0
local s s23c01
forval i=1/5 {
	local i 0`i'
	replace siniestro = 1 if `s'`i'==1
}
count if siniestro==1
local 1 ahorros
local 2 prestado
local 3 vendieron
local 4 ayuda
local 5 trabajo_extensive
local 6 trabajo_intensive
local s s23c02
forval i=1/6 {
	local j 0`i'
	rename `s'`j' siniestro_``i''
	assert siniestro_``i'' == . if siniestro==0
}
local klist `klist' siniestro*

// OP BEN AND OTHER GOV PROGRAMS
gen op_ben1 = (s02c09==1) // note s02c10 is ¿recibe apoyos? and 97% do
*** s02c09 ¿Este hogar es beneficiario del Programa Oportunidades (Progresa)?
gen op_ben3 = (s02c09==1 | s02c07==1)
*** s02c07 ¿Este hogar cuenta con alguna documentación del programa Oportunidades como: Identificación Provi- sional, S1/CRUS, folio ENCASEH/ENCASURB o constancia de atención?

local 01 tortilla_gratuita
local 02 liconsa
local 03 op_dinero
local 04 op_papilla
local 05 apoyo_alimentario // Despensas del DIF
local 06 desayunos_escolares
local 07 becas_educativas // Distintas a las de Oportunidades
local 08 becas_transporte
local 09 apoyos_INI // Instituto Nacional Indigenista
local 10 probecat // becas de capacitacion
local 11 apoyos_campo
local 12 apoyo_vivienda
local 13 procampo
local 14 credito_palabra
local 15 pet // Programa de Empleo Temporal
local 16 fonaes // empresas sociales
local 17 microempresa // fondo para la micro, pequeña y mediana empresa?
local 18 programas_estatales
local 19 programas_municipales
local 20 seguro_popular
local 21 otro
local s s15c02
forval i=1/21 {
	if length("`i'")==1 local i 0`i' // for 1-digit numbers (else i remains `i')
	gen b_``i'' = (`s'`i'==1) // b stands for beneficiary
}
// dealing with the "otro? (Especifique)"
local pensiones `""TERCERA EDAD" "ANCI" "PENSION""'
local apoyo_alimentario `""ALIMENT" "DIF" "DESPENSA" "KILO" "TAZA""'
local becas_educativas `""BECA""'
local op_dinero `""OPORTUNIDADES""'
local op_papilla `""DESPENSA DE OP""'
local seguro_popular `""SEGURO POPULAR""'
local apoyos_campo `""SEMILLA""'
local new_blist pensiones
local old_blist apoyo_alimentario becas_educativas op_dinero op_papilla seguro_popular apoyos_campo
foreach x of local new_blist {
	gen b_`x' = 0
	foreach string of local `x' {
		replace b_`x' = 1 if strpos(s15c0222,"`string'")>0
		replace b_otro = 0 if strpos(s15c0222,"`string'")>0
	}
}
foreach x of local old_blist {
	foreach string of local `x' {
		replace b_`x' = 1 if strpos(s15c0222,"`string'")>0
		replace b_otro = 0 if strpos(s15c0222,"`string'")>0
	}
}
tab s15c0222 if b_otro==1

foreach x in 2 4 {
	gen op_ben`x' = op_ben`=`x'-1'
	replace op_ben`x' = 1 if b_op_dinero==1 // transferencias from Op
	replace op_ben`x' = 1 if b_op_papilla==1 // papilla from Op
}
	
mtab b_* // check results
local klist `klist' op_* b_*

** Note: results in paper use administrative Op ben status; survey self-reported alternatives: 
**  op_ben1 is just based on the s02c09 variable (¿Este hogar es beneficiario del Programa Oportunidades (Progresa)?)
**  op_ben2 is op_ben1 and also corrects if they reported receiving a cash transfer or baby food from Oportunidades
**  op_ben3 is s02c09 OR s02c07 (cuenta con documentacion?)
**  op_ben4 is op_ben3 and also corrects if they reported receiving a cash transfer or baby food from Oportunidades

// EXPENDITURES (Note own-consumption didn't appear in 2009 survey, so the consumption definitions I use don't include it)
local sem s16c
local men s17c
local tri s18c
local anu s19c
clean `sem'03??, l(3) v(expend_alim)
clean `sem'06??, l(3) v(expend_auto_alim)
clean `sem'09??, l(3) v(expend_alim) // because of how clean is written this will add on the one gen'd in the previous
clean `sem'12??, l(3) v(expend_auto_alim)
clean `sem'13,   l(5) v(expend_alim_fuera)
clean `sem'17??, l(4) v(expend_noalim) // note in 2002 it was l(3), now l(4)
clean `sem'20??, l(4) v(expend_auto_noalim)
clean `men'03??, l(4) v(expend_mes)
clean `men'06??, l(4) v(expend_auto_mes)
clean `tri'03??, l(5) v(expend_tri)
clean `tri'06??, l(5) v(expend_auto_tri)
clean `anu'03??, l(5) v(expend_anio)
clean `anu'06??, l(5) v(expend_auto_anio)

** SPECIFIC SPENDING CATEGORIES

// Durables (from annual spending section
unab durables :  `anu'03??
local xcount = 0
foreach x of local durables {
	local ++xcount
	clean `x', l(5) v(expend_durables`xcount')
}
foreach x of local notdurables {
	local durables = subinstr("`durables'","`anu'03`x'","",.)
}
clean `durables', l(5) v(expend_durables)

// Dummy variables for whether spent on durables
local i = 0
foreach var of varlist `anu'02* {
	local ++i
	fre `var' // note about 10% are missing; treat as missing for dummy as well
	summ `anu'030`i' if missing(`var'), meanonly
	assert r(mean)==0 | r(N)==0
	gen byte spent_durables`i' = (`var' == 1) if !missing(`var')
}
local klist `klist' spent_*

#delimit ;
// Other durables;
local other_durables_tri_
	`tri'0309 /* juguetes */
	`tri'0310 /* libros y discos */
;

// Non-durables (excluding food which is done by category below);
local non_durables_sem_
	`sem'1701 /* cerillos y encendedores */
	`sem'1703 /* periódicos y revistas */
	`sem'1704 /* velas y veladoras */
;
local non_durables_mes_
	`men'0301 /* artículos de aseo peronal (crema dental, papel higiénico, desodorante, shampoo, etc.) */
	`men'0302 /* artículos de aseo para niños menores de 2 años (pañales desechables, toallas húmedas, etc.) */
	`men'0303 /* artículos para el aseo del hogar (detergentes, escobas, trapeadores, etc.) */
	`men'0304 /* combustibles (petróleo, gasolina, carbón, leña) */
;
local non_durables_tri_
	`tri'0301 /* ropa para mujer (adulta) */
	`tri'0302 /* ropa para hombre */
	`tri'0303 /* ropa para niños (4-12 años) */
	`tri'0304 /* ropa para niñas (4-12 años) */
	`tri'0305 /* ropa para jóvenes (hombres) (13-18 años) */
	`tri'0306 /* ropa para jóvenes (mujeres) (13-18 años) */
	`tri'0307 /* calzado para adultos */
	`tri'0308 /* calzado para niños o jóvenes */
;

// Services;
local transport_ 
	`sem'1702 /* transporte en autobuses, camionetas, camion, taxis (no incluye gastos de transporte escolar) */
;
local services_mes_ 
	`men'0305 /* servicios personales (corte de pelo, manicure, pedicure, etc.) */
	`men'0306 /* diversiones (cine, club nocturnos, excursiones, ferias, etc.) */
;
local health_tri_ /* trimestral */
	`tri'0311 /* gastos relacionados con salud (consultas médicas, exámenes de laboratorio, anticonceptivos, etc.) */
;

// Food categories;
local alcohol_ 
	`sem'0914 /* bebidas alcoholicas */
;
local tobacco_ 
	`sem'1705 /* cigarros */
;
local sugar_  
	`sem'0912 /* azucar */	
;
local sweets_
	`sem'0318 /* pastelillos en bolsa */
;
local soda_ 
	`sem'0911 /* refrescos */
	`sem'0913 /* concentrados o polvo para preparar agua */
;
local junk_  
	`sem'0917 /* papas fritas, chicharrones, etc */
	`sem'0918 /* otros articulos industrializados */
;
local oil_
	`sem'0916 /* aceite vegetal */
;
local coffee_
	`sem'0915 /* cafe */
;
local eatout_
	`sem'13
;
local meat_ 
	`sem'0901 /* carne de res */
	`sem'0902 /* pollo */
	`sem'0903 /* carne de puerco */
	`sem'0904 /* atun, sardinas en lata */
	`sem'0905 /* pescado y mariscos */
	`sem'0906 /* huevos */
	`sem'0910 /* otros productos de origen animal (embutidos, manteca, etc.) */
;
local dairy_ 
	`sem'0907 /* leche */
	`sem'0908 /* queso */
	`sem'0909 /* otros productos lacteos */
;
local veg_ 
	`sem'0301 /* jitomates o tomates */
	`sem'0302 /* cebollas */
	`sem'0303 /* papas */
	`sem'0304 /* chiles */
	`sem'0305 /* zanahorias */
	`sem'0306 /* calabacitas */
	`sem'0311 /* otras verduras */
;
local fruit_ 
	`sem'0307 /* platanos */
	`sem'0308 /* manzanas */
	`sem'0309 /* naranjas */
	`sem'0310 /* otras frutas */
;
local cereals_
	`sem'0312 /* tortillas */
	`sem'0313 /* pan blanco */
	`sem'0314 /* pan de dulce */
	`sem'0315 /* sopa de pasta */
	`sem'0317 /* arroz */
	`sem'0319 /* otros cereales */
	`sem'0316 /* frijol */
;
local categories_3 /* need to be cleaned with l(3) */
	alcohol
	sugar
	sweets
	soda
	junk
	oil
	coffee
	meat
	dairy
	fruit
	veg
	cereals
;
local categories_4 /* need to be cleaned with l(4) */
	non_durables_sem
	non_durables_mes
	services_mes
	tobacco 
	transport
;
local categories_5 /* need to be cleaned with l(5) */
	other_durables_tri
	non_durables_tri
	eatout
	health_tri
;
local semanal 
	non_durables_sem
	alcohol
	tobacco
	sugar
	sweets
	soda
	junk
	oil
	coffee
	meat
	dairy
	fruit
	veg
	cereals
	transport
;
local mensual /* need to be converted to weekly */
	non_durables_mes
	services_mes	
;
local trimestral /* need to be converted to weekly */
	other_durables_tri
	non_durables_tri
	health_tri
;
#delimit cr
forval i=3(1)5 {
	foreach category of local categories_`i' {
		clean ``category'_', l(`i') v(expend_`category') // go straight to creating as cons_
	}
}
foreach category of local semanal {
	gen cons_`category' = expend_`category'
}
foreach category of local mensual { // monthly to weekly
	gen cons_`category' = expend_`category'/`weeks_per_month'
}
foreach category of local trimestral { // trimonthly to weekly
	gen cons_`category' = expend_`category'/(3*`weeks_per_month')
}
gen spent_other_durables = (expend_other_durables_tri > 0 & !missing(expend_other_durables_tri))

// AGGREGATES
forval i=1/7 {
	gen cons_durables`i' = expend_durables`i'/`weeks_per_year'
}
gen cons_durables = (expend_durables/`weeks_per_year') 
gen cons_weekexcl = expend_alim + expend_noalim 
gen cons_week  = expend_alim + expend_noalim + expend_alim_fuera
gen cons_month = cons_week + expend_mes/`weeks_per_month'
gen cons_3month = cons_month + (expend_tri/(3*`weeks_per_month_precise'))
gen cons_year = cons_3month + (expend_anio/(12*`weeks_per_month_precise'))
replace cons_health = cons_health + cons_health_tri // note both are already weekly
// all weekly (encelurb_merge will convert everything to monthly for ease of interpretation)

summ expend_*, sep(0)
local klist `klist' expend_* f?_* cons_* 

// ASSET OWNERSHIP
local p  s22c01
local es s22c0218
assetify `es', p(`p') pre
** Take a look
foreach var of varlist has_* {
	tab `var'
}
local klist `klist' has_*

********************
** MERGE AND SAVE **
********************
keep `klist'
order `klist'
#delimit ;
local suffixes 
	ind 
	desde_hogar 
	desde_hogar_e 
	hacia_hogar 
	hacia_hogar_e
	income 
	spending_ind
;
#delimit cr
foreach x of local suffixes {
	merge 1:1 folio using "$waste/encel`yy'_`x'.dta", gen(m_`x') // created above
}
gen mustdrop = (m_ind!=3) // households that weren't in both socio_personas_soc and socio_hogares_soc
replace transfer_out_dummy = 0 if m_desde_hogar!=3
replace e_transfer_out_dummy = 0 if m_desde_hogar_e!=3
replace transfer_in_dummy = 0 if m_hacia_hogar!=3
replace e_transfer_in_dummy = 0 if m_hacia_hogar_e!=3
foreach x in labincome othincome { 
	foreach suffix in "" "_f" "_m" {
		replace `x'`suffix' = 0 if m_income!=3
	}
}
foreach x in hacia_hogar desde_hogar {
	replace `x' = 0 if m_`x'!=3
}
foreach suffix in "" "_f" "_m" {
	gen totinc`suffix' = labincome`suffix' + othincome`suffix' 
		// since no private transf in/out in 2009 survey
}
save "$proc/encel`yy'_hh.dta", replace

*************
** WRAP UP **
*************
log close
exit

