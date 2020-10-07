** ENCELURB 2009 DATA PREP
**  Sean Higgins
**  created July 7 2014

************
** LOCALS **
************
local year 2009
local yy = substr("`year'",3,2)

local notdurables 01 07 // 01 is festividades escolares; 07 includes some durables (jewelry) but
	// also nondurables (vacations) in same category
local weeks_per_month = 30/7 // because they don't actually ask about last month, they ask
	// "en los últimos 30 días"
local weeks_per_month_precise = 4.34524 // goo.gl/lvFss5
local weeks_per_year = 52.1429 // goo.gl/3Ttao7

local jefe h211
local the_male   sexo==1 & (`jefe'==1 | `jefe'==2)
local the_female sexo==2 & (`jefe'==1 | `jefe'==2)

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 62_encelurb_dataprep_`year'
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

**********************************
** PRIVATE TRANSFERS IN AND OUT **
**********************************
// no section on this in the 2009 survey

*********************************************
** SOCIODEMOGRAPHIC VARS FOR IND DATA 2009 **
*********************************************
local incvars // to clear from 2004

use "$data/ENCELURB/`year'/panel_integrantes_febrero_2010.dta", clear
drop if h202>=3 // no longer live in hh
sort folio, stable

// SOCIODEM CHAR
// sociodem is defined in encelurb_dataprep_preliminary.doh
#delimit ;
sociodem , 
	edad(h209) 
	sexo(h210) 
	jefe(h211)
	casado(h214)
	asistio(h302)
	nivel(h303a)
	grado(h303b)
	leer(h301)
	trabajo(h401)
	trabajo2(h402)
	encel09
;
#delimit cr

// age of man and woman
gen edad_m = edad if `the_male'
gen edad_f = edad if `the_female'

// HEALTH INSURANCE
assert h501==1 | h501==2
gen healthinsurance = (h501==1)
** h501 ¿Está (NOMBRE) afiliado o inscrito a algún seguro médico?
gen seguropopular = (h502a==1 | h502b==1 | strpos(h502es,"POPULAR")>0) // ¿En que institución o programa?

// ESCOLARIDAD
** h301 ¿(NOMBRE) sabe leer y escribir un recado? 1 Si 2 No 9 No Sabe (only 0.1% have ==9)
gen analfabeto_m = analfabeto if `the_male'
gen analfabeto_f = analfabeto if `the_female'

gen asiste = (h305==1) if edad>=3 & edad<=13 // missing for those not asked the question
replace asiste = 1 if h305==9 & h322==1 & (edad>=3 & edad<=13) // use previous year
gen asistio = (h322==1) if edad>=3 & edad<=13 // anio escolar pasado

gen escolaridad_m = escolaridad if `the_male'
gen escolaridad_f = escolaridad if `the_female'

gen menos_9 = (escolaridad<9)

// FEMALE BARGAINING POWER 
//  (Note this question was only included in the 2002 and 2009 versions of survey)
//  Recode variables on household decision making as:
//   0 if male makes decision, 1 if joint or female

// Note 2009 survey has the questions in a different order; do this part separately
gen female04 = .
replace female04 = 1 if (h1501 == 1 | h1501 == 5) & `the_female' // Usted; otra mujer en el hogar
replace female04 = 0 if (h1501 == 2 | h1501 == 4) & `the_female' // Su pareja; otro hombre en el hogar
replace female04 = 1 if (h1501 == 3) & `the_female' // ambos en acuerdo común

gen female01 = .
replace female01 = 1 if (h1506 == 1 | h1506 == 5) & `the_female'
replace female01 = 0 if (h1506 == 2 | h1506 == 4) & `the_female'
replace female01 = 1 if (h1506 == 3) & `the_female'

gen female02 = .
replace female02 = 1 if (h1507 == 1 | h1507 == 5) & `the_female'
replace female02 = 0 if (h1507 == 2 | h1507 == 4) & `the_female'
replace female02 = 1 if (h1507 == 3) & `the_female'

gen female03 = .
replace female03 = 1 if (h1508 == 1 | h1508 == 5) & `the_female'
replace female03 = 0 if (h1508 == 2 | h1508 == 4) & `the_female'
replace female03 = 1 if (h1508 == 3) & `the_female'

// female08 question not included in this survey

local klist `klist' female*
	
// HOUSEHOLD LEVEL VARS
hhlevel encel09 // in encelurb_dataprep_preliminary.doh

save "$waste/encel`yy'_ind.dta", replace

// SPENDING FROM INDIVIDUAL LEVEL DATA (HOSPITAL)
use "$data/ENCELURB/`year'/panel_integrantes_febrero_2010.dta", clear
lower
drop if h202>=3 // no longer live in hh
sort folio, stable
clean h511, l(6) v(cons_hospital)
collapse (sum) cons_hospital (max) f?_*, by(folio)
replace cons_hospital = cons_hospital/`weeks_per_year' // yearly to weekly

// SAVE
save "$waste/encel`yy'_spending_ind.dta", replace

// INCOME
use "$data/ENCELURB/`year'/panel_integrantes_febrero_2010.dta", clear
drop if h202>=3 // no longer live in hh
sort folio, stable

** h410 for 1st job, h415 for second job
**  Cuanto gana (ganaba) en este trabajo, no incluya el aguinaldo?
	** a) Periodo
	   ** 0 No recibe este tipo de ingresos
	   ** 1 Día
	   ** 2 Semana
	   ** 3 Quincena
	   ** 4 Mes
	   ** 5 Bimestre
	   ** 6 Semestre
	   ** 7 Año
	   ** 9 No sabe
	** b) Monto (99999 = no sabe acc Questionnaire but in data label 9999=.)
	   ** (99998 = topcode 99,998+)
local i=1
local 1 410
local 2 415

foreach x in 410 415 {
	local 1 h`x'b
	local 2 h`x'a
	local x2 = `x' + 2
	** extreme outliers
	daywk_outliers `1' `2'
	gen     `1'_an = 0 // _an = anual
	replace `1'_an = `1'*365/(7/5) if `2'==1 // daily - assume 5 d/wk work
	replace `1'_an = `1'*(365/7)  if `2'==2 // weekly
	replace `1'_an = `1'*(365/15) if `2'==3 // quincena
	replace `1'_an = `1'*12       if `2'==4 // monthly 
	replace `1'_an = `1'*1        if `2'==5 // annual
	replace `1'_an = `1' if `1'==998 | `1'==999 | `1'==9998 | `1'==9999 | ///
						    `1'==99998 | `1'==99999 | `1'==999998 | `1'==999999
		// note in 2009, unlike previous, could be 99999-coded and still have `2'==1,2,etc.
	gen f_labincome`i' = (`2'==9)
	** portion of year worked
	local wk h`x2'a
	local mo h`x2'b
	tempvar mi_portion
	recode `wk' `mo' (99 = 0)
	replace `wk' = 0 if `mo'>0 & `mo'<99 & `wk'>4
	gen portion`i' = (`mo'+(`wk'/4))/12 if `mo'>0 
	replace portion`i' = `wk'/52 if `mo'==0
	replace portion`i' = 1 if `mo'==99 | `mo'==12
	assert portion`i' <= 1 if !mi(portion`i')
	// confirmed that results are robust to instead using portion=1 for all
	replace `1'_an = `1'_an*portion`i' if !mi(portion`i')
	local ++i
}
clean h410b_an h415b_an h418, l(4 5 6) v(labincome) // has coding for both 4 and 5 digits (9999 and 99999)
	// not a clean9s case like in previous years
	
local list1
local list2
forval i=1/5 {
	local 1 h419`i'b
	local 2 h419`i'a
	daywk_outliers `1' `2'
	gen `1'_an = 0
	if inlist(`i',1,2) { // for income placebo, doesn't make a difference what you do with these
		replace `1'_an = `1'*365/(7/5) if `2'==1 // assume 5 days per week
		replace `1'_an = `1'*(365/7)  if `2'==2 // semana
		replace `1'_an = `1'*(365/15) if `2'==3 // quincena
		replace `1'_an = `1'*12       if `2'==4 // mes
		replace `1'_an = `1'*6        if `2'==5 // bimestre
		replace `1'_an = `1'*2        if `2'==6 // semestre
		replace `1'_an = `1'*1        if `2'==7 // año
		replace `1'_an = `1' if `1'==998 | `1'==999 | `1'==9998 | `1'==9999 | ///
								`1'==99998 | `1'==99999 | `1'==999998 | `1'==999999
	}
	else  if !inlist(`i',5) { // for venta/renta, herencias, and regalos
		   // there was some obvious misreporting (e.g. a gift of 3500/day)
		   // so I assumed all these were one-time in the year since they
		   // are all irregular sources of income
		replace `1'_an = `1' if !mi(`1')
	}
	// note: keeping "venta/renta de activos de su propiedad"
	// as income source because (1) can't separate venta from renta
	// and (2) even though we normally wouldn't want to include venta since
	// the income increase is equal to an asset decrease, for savings the 
	// liquid income is important
	local list1 `list1' `1'_an
	local list2 `list2' `2'
}
clean `list1', l(3 4 5 6) v(othincome) 

rename h210 sexo
foreach var of varlist ???income {
	gen `var'_f = 0
	gen `var'_m = 0
	replace `var'_f = `var' if `the_female'
	replace `var'_m = `var' if `the_male'
}

collapse (sum) ???income* (max) f?_* drop, by(folio)
postcollapse h410b_an h415b_an h418, v(labincome)
postcollapse `list1', v(othincome)
save "$waste/encel`yy'_income.dta", replace

********************************************
** SOCIODEMOGRAPHIC VARS FOR HH DATA 2009 **
********************************************
use "$data/ENCELURB/`year'/panel_hogar_febrero_2010.dta", clear
sort folio, stable
localidades
gen year = `year'
local klist folio localidad *ent *mun *loc year

// CARACTERISTICAS DE LA VIVIENDA
gen piso_tierra = (h1005==1) // what about ==3 (mosaico, madera u otros recubrimientos; 5%) and ==9 (no sabe; only 3 obs)
** h1005 ¿De qué material es la mayor parte del piso de esta vivienda? 1 Tierra 2 Cemento o firme 3 Mosaico, madera u otros recubrimientos 
gen sin_sanitario = (h1014!=1)
** h1014 ¿Esta vivienda tiene:  1 excusado o sanitario?  2 letrina o retrete?  3 fosa?  4 hoyo negro o pozo ciego?  5 No tienen servicio sanitario (hacen en el suelo, corral, establo, playa, etcétera)?
gen sin_agua = (h1013!=1) | (h1016==2)
** h1013 ¿Llega agua al terreno de... 1 la red pública? 2 la red pública de otra vivienda? 3 una llave pública hidrante? 4 un pozo? 5 un río, arroyo, lago u otro? 6 una pipa? 7 no llega agua al terreno 
** h1016 ¿Tiene el(la) (servicio sanitario de 10.14) conexión de agua? 1 Si 2 No 9 No sabe
gen sin_drenaje = (h1018==2)
** h1018 ¿La vivienda cuenta con drenaje? 1 Si 2 No
recode h1009 h1010 (99 = .)
rename h1009 n_cuartos // Sin contar pasillos, baños ni cocina, ¿cuántos cuartos tiene en total esta vivienda?
rename h1010 n_cuartos_dormir // for #personas/cuarto
rename h101 n_personas 
recode n_cuartos_dormir (0 = 1) // only 6 obs w 0; otherwise dividing by zero
gen oc_por_cuarto = n_personas/n_cuartos_dormir

local klist `klist' piso_tierra sin_* n_* oc_*

// BANK ACCOUNT AND SAVINGS DUMMIES
gen cuenta_bancaria = (h1204==1)
local klist `klist' cuenta_bancaria
 
// SHOCKS
gen siniestro = 0
local s h1701
forval i=1/6 {
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
local s h1702
forval i=1/6 {
	local j 0`i'
	rename `s'`j' siniestro_``i''
	assert siniestro_``i'' == . if siniestro==0
}
local klist `klist' siniestro*


// OP BEN AND OTHER GOV PROGRAMS
gen op_ben1 = (h104==1) 
gen op_ben3 = (h104==1 | h105==1) // added if documentation Sep 16

local 01 liconsa
local 02 op_dinero
local 03 op_papilla
local 04 apoyo_alimentario // Despensas del DIF
local 05 seguro_popular
local 06 becas_educativas // PRONABES
local 07 seguro_popular2 // seguro popular nueva generacion
local 08 arranque_parejo // program for pregnant women
local 09 apoyo_vivienda
local 10 setenta_mas
local 11 becas_transport
local 12 fonaes
local 13 microempresa
local 14 guarderias
local 15 otro
local s h1101
forval i=1/15 {
	if length("`i'")==1 local i 0`i' // for 1-digit numbers (else i remains `i')
	gen b_``i'' = (`s'`i'==1) // b stands for beneficiary
}

local apoyo_alimentario `""DESPENSA""'
local mfi `""COMPARTAMOS" "CONPARTAMOS" "FINANCIERA" "INDEPENCIA" "ELEKTRA" "PRESTAMO""'
local becas_educativas `""BECA""'
local apoyo_vivienda `""INFONAVIT" "INVICAM" "PATRIMONIO HOY""'
local pensiones `""PENSION" "PENCION""'

local new_blist pensiones mfi 
local old_blist apoyo_alimentario becas_educativas apoyo_vivienda
local es h110115e
foreach x of local new_blist {
	gen b_`x' = 0
	foreach string of local `x' {
		replace b_`x' = 1 if strpos(`es',"`string'")>0
		replace b_otro = 0 if strpos(`es',"`string'")>0
	}
}
foreach x of local old_blist {
	foreach string of local `x' {
		replace b_`x' = 1 if strpos(`es',"`string'")>0
		replace b_otro = 0 if strpos(`es',"`string'")>0
	}
}

foreach x in 2 4 {
	gen op_ben`x' = op_ben`=`x'-1'
	replace op_ben`x' = 1 if b_op_dinero==1 // transferencias from Op
	replace op_ben`x' = 1 if b_op_papilla==1 // papilla from Op
}

local klist `klist' op_* b_*

// EXPENDITURES (Note own-consumption didn't appear in 2009 survey, so the consumption definitions I use don't include it)
local anu h711
clean h603? h603?? h606??, l(3) v(expend_alim)
clean h701, l(5) v(expend_alim_fuera)
clean h704??, l(4) v(expend_noalim)
clean h706??, l(4) v(expend_mes)
clean h709??, l(4) v(expend_tri)
clean h711??, l(5) v(expend_anio)

** SPECIFIC SPENDING CATEGORIES
// Durables (from annual spending section
unab durables :  `anu'??
local xcount = 0
foreach x of local durables {
	local ++xcount
	clean `x', l(5) v(expend_durables`xcount')
}
foreach x of local notdurables {
	local durables = subinstr("`durables'","`anu'`x'","",.)
}
clean `durables', l(5) v(expend_durables)

// Dummy variables for whether spent on durables
local i = 0
foreach var of varlist h710* {
	local ++i
	fre `var' // note about 10% are missing; treat as missing for dummy as well
	summ `anu'0`i' if missing(`var'), meanonly
	assert r(mean)==0 | r(N)==0
	gen byte spent_durables`i' = (`var' == 1) if !missing(`var')
}
local klist `klist' spent_*

#delimit ;
// Other durables
local other_durables_tri_
	h70909 /* juguetes */
	h70910 /* libros y discos */
;

// Non-durables (excluding food which is done by category below);
local non_durables_sem_
	h70410 /* cerillos y encendedores */
	h70406 /* periódicos y revistas */
	h70407 /* velas y veladoras */
;
local non_durables_mes_
	h70601 /* artículos de aseo peronal (crema dental, papel higiénico, desodorante, shampoo, etc.) */
	h70602 /* artículos de aseo para niños menores de 2 años (pañales desechables, toallas húmedas, etc.) */
	h70603 /* artículos para el aseo del hogar (detergentes, escobas, trapeadores, etc.) */
	h70604 /* combustibles (petróleo, gasolina, carbón, leña) */
;
local non_durables_tri_
	h70901 /* ropa para mujer (adulta) */
	h70902 /* ropa para hombre */
	h70903 /* ropa para niños (4-12 años) */
	h70904 /* ropa para niñas (4-12 años) */
	h70905 /* ropa para jóvenes (hombres) (13-18 años) */
	h70906 /* ropa para jóvenes (mujeres) (13-18 años) */
	h70907 /* calzado para adultos */
	h70908 /* calzado para niños o jóvenes */
;

// Services;
local transport_
	h70405 /* transporte en autobús, camioneta, camión, colectivo, taxi (no incluya gastos de transporte escolar */
;
local services_mes_ /* mensual */
	h70605 /* servicios personales (corte de pelo, manicure, pedicure, etc.) */
	h70606 /* diversiones (cine, club nocturnos, excursiones, ferias, etc.) */
;
local services_tri_ /* trimestral */
	h70913 /* ceremonias como bodas, XV años o bautizos */
;
local transport_educ_ 
	h70401 /* transporte escolar en autobús, camioneta, camión, colectivo, taxi para ir a la escuela primaria */
	h70402 /* transporte escolar en autobús, camioneta, camión, colectivo, taxi para ir a la escuela secundaria */
	h70403 /* transporte escolar en autobús, camioneta, camión, colectivo, taxi para ir a la escuela bachillerato o preparatoria */
	h70404 /* transporte escolar en autobús, camioneta, camión, colectivo, taxi para ir a otros niveles educativos (normal, universidad, y/u otros */
;
local educ_tri_ /* trimestral */
	h70911 /* uniformes escolares */
	h70912 /* útiles escolares */
	h70914 /* inscripción o cuota escolar */
;
local educ_mes_	/* mensual */
	h70609 /* colegiaturas o cooperación escolar? */
;
local educ_sem_
	h70409 /* materiales para trabajos o manualidades escolares */
;
local health_mes_ /* mensual */
	h70607 /* medicinas */
	h70608 /* consultas médicas */
;

// Food categories;
local alcohol_ 
	h60640 /* bebidas alcoholicas */
;
local tobacco_ 
	h70408 /* cigarros o tobaco */
;
local sugar_ 
	h60643 /* azucar */
;
local sweets_ 
	h60638 /* pastelitos en bolsa */
;	
local soda_
	h60639 /* refrescos */
	h60646 /* jarabe o polvo para preparar agua */
;
local junk_ 
	h60645 /* frituras diversas */
;
local oil_
	h60644 /* aceite vegetal */
;
local coffee_
	h60641 /* cafe soluble o instantaneo */
	h60642 /* cafe en grano */
;
local eatout_
	h701
;
local meat_ /* meat, fish, eggs */
	h60628 /* pollo */
	h60629 /* carne de res */
	h60630 /* carne de puerco */
	h60631 /* pescado y mariscos */
	h60632 /* atun, sardinas en lata */
	h60633 /* huevos */
	h60636 /* manteca de cerdo */
;
local dairy_ 
	h60634 /* leche */
	h60635 /* queso */
	h60637 /* yogurt, mantequilla, crema */
;
local veg_ 
	h6031 /* jitomates o tomates */
	h6032 /* cebollas */
	h6033 /* papas */
	h6034 /* zanahorias */
	h6035 /* verduras de hoja */
	h6037 /* nopales */
	h6038 /* chile */
	h6039 /* calabaza */
	h60310 /* chayote */
	h60315 /* camote */
	h60311 /* otra verdura */
;
local fruit_
	h6036 /* limones */
	h60312 /* naranjas */
	h60313 /* platanos */
	h60314 /* manzanas */
	h60314 /* otra fruta */
;
local cereals_
	h60317 /* tortillas */
	h60318 /* pan blanco */
	h60319 /* pan de dulce */
	h60320 /* pan de caja */
	h60321 /* sopa de pasta */
	h60322 /* arroz */
	h60323 /* galletas */
	h60324 /* frijol */
	h60325 /* cereales de caja */
	h60326 /* garbanzo */
	h60327 /* haba */
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
	other_durables_tri
	non_durables_sem
	non_durables_mes
	non_durables_tri
	transport
	services_mes
	services_tri
	transport_educ
	educ_tri
	educ_mes
	educ_sem
	health_mes
	tobacco
;
local categories_5 /* need to be cleaned with l(5) */
	eatout
;
local semanal 
	non_durables_sem
	transport
	transport_educ
	educ_sem
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
;
local mensual /* need to be converted to weekly */
	non_durables_mes
	educ_mes
	health_mes
	services_mes
;
local trimestral /* need to be converted to weekly */
	other_durables_tri
	non_durables_tri
	services_tri
	educ_tri
;
#delimit cr
// Make everything weekly (will convert to monthly in encelurb_merge)
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
rename cons_health_mes cons_health // already weekly
gen cons_educ = cons_educ_sem // + cons_educ_mes + cons_educ_tri // all already weekly
	// because the others not included in earlier survey waves
// all weekly (encelurb_merge will convert everything to monthly for ease of interpretation)

summ expend_*, sep(0)
local klist `klist' expend_* f?_* cons_* 

// ASSETS
local p h901
assetify , p(`p') post
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
foreach x in ind income spending_ind {
	merge 1:1 folio using "$waste/encel`yy'_`x'.dta", gen(m_`x') // created above
}
gen mustdrop = (m_ind!=3) // households that weren't in both individual and hh data

foreach x in labincome othincome { // lab and lbb (from 2002) combined in lab in 2003
	foreach suffix in "" "_f" "_m" {
		replace `x'`i'`suffix' = 0 if m_income!=3
	}
}

foreach suffix in "" "_f" "_m" {
	gen totinc`i'`suffix' = labincome`i'`suffix' + othincome`i'`suffix' 
		// since no private transf in/out in 2009 survey
}

** merge in survey date
merge 1:1 folio using "$data/ENCELURB/`year'/entrevistas_panel_febrero_2010.dta", keep(3) keepusing(vis1f)
rename vis1f fecha

save "$proc/encel`yy'_hh.dta", replace

*************
** WRAP UP **
*************
log close
exit


** ignoring spending on services for now
** (lots of measurement issues and the family
** is less likely to be able to change this consump to save)
** [see encelurb_dataprep.do in old folder where I did services]

