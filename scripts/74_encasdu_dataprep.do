** ENCASDU Trust Survey data prep
**  Sean Higgins
**  created December 12 2014

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 74_encasdu_dataprep
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

*******************
** PRELIMINARIES **
*******************
// Load in preliminary programs 
include "$scripts/encelurb_dataprep_preliminary.doh" // !include!

// MERGE WITH LOCALITY/MUNICIPALITY-LEVEL VARS
//  Note: some of the other data sources don't have all the localities
//   or municipalities, so to keep the sample the same once adding these controls,
//   create a dummy variable denoting if it doesn't merge, then convert the 
//   missing to 0 and include the dummary variable as a control.
cap program drop merge_on
program define merge_on
	syntax varname using [if/], exists(string) controls(string)
	local varname `varlist' 
	
	merge m:1 `varname' `using', keepusing(`controls')
	
	if "`if'"!="" {
		local _if "if `if'"
		local and_if "& `if'"
	}
	
	gen `exists' = 0
	replace `exists' = 1 if _merge == 3
	assert !missing(`exists') if _merge == 3
	foreach var of varlist `controls' {
		replace `var' = 0 if `exists' == 0
	}			
	drop if _merge == 2
	drop _merge
	tab `exists' `_if'
	tab localidad if `exists' == 0 `and_if'
	uniquevals localidad if `exists' == 0 `and_if' 
end

************
** LOCALS **
************
// Variables
#delimit ;
local outcomes 
	donttrust 
	knowledge 
	ineligible
	notenough
;
// Assets consistent with Encelurb ;
local assets_bothsurveys 
	has_auto
	has_camion
	has_moto
	has_tv 
	has_video
	has_radio
	has_lavadora
	has_estufa_gas
	has_refrig
;
#delimit cr

**********
** DATA **
**********

// REASONS FOR NOT SAVING -----------------------------------------------

// MAPO sample
use "$proc/hogar_mapo_noviembre_2010.dta", clear
count
merge 1:1 folio using "$proc/entrevistas_mapo_noviembre_2010.dta", ///
	keepusing(folio edo mpio locali vis1f) keep(match)
drop _m
rename vis1f dateint
stringify locali, digits(9) gen(localidad) // already includes state & mun

// Localities
gen pozarica = (localidad=="301240159")
replace localidad="301310001" if localidad=="301240159"
	// Poza Rica, Papantla, Veracruz incorporated into Poza Rica de Hidalgo, Poza Rica de Hidalgo, Veracruz
	// (see http://goo.gl/jvOjev)
	// result: (72 real changes made) - those living in this locality
uniquevals localidad // 179 localities
	
tab h13a081s
** Reasons
 ** [1] "NO TIENE PERMITIDO DEJAR SU DINERO  EN CAJERO                               // knowledge
 ** [2] "NO SALE TODO EL APOYO EN EL CAJERO                                          // trust
 ** [3] "PORQUE NO ESTA INFORMADA SOBRE EL BANCO DE BANSEFI                          // knowledge
 ** [4] "POR EL CAJERO NO PUEDE AHORRAR NADA                                         // knowledge
 ** [5] "PORQUE NO SIENTE QUE ESTE SEGURO EL DINERO EN EL BANCO                      // trust         
 ** [6] "PORQUE NO NOS HAN DICHO QUE PODAMOS AHORRAR CON ESA TARJETA                 // knowledge                                         
 ** [7] "POR DESCONFIANZA                                                            // trust                                                                       
 ** [8] "NO SE MANEJAR LA TARJETA Y POR ESO SACO TODO EN UNA SOLA VEZ                // knowledge                                                                       
 ** [9] "PORQUE LES PONEN MUCHAS TRABAS EN BANSEFI O NO LES DABAN COMPLETO EL APOYO EN LA SUCURSAL BANSEFI // costs (trabas = obstacles)                                                 
** [10] "PORQUE NO TIENE MUCHA CONFIANZA EN DEJARLO                                  // trust                                                                       
** [11] "PORQUE LO UTILIZA PARA LA ESCUELA DE SUS HIJOS                              // not enough $                                                                       
** [12] "EL BANCO NO LE PERMITE AHORRAR                                              // knowledge                                                                     
** [13] "PORQUE LES DICEN QUE CANCELAN LA TARJETA SINO RETIRAN TODO EL APOYO         // ineligible                                                                      
** [14] "PORQUE NO SABE MANEJAR BIEN LA TARJETA                                      // knowledge                                                                       
** [15] "PORQUE QUIERIAN QUE LO DEJARA A PLAZO                                       // knowledge                                                                       
** [16] "PORQUE NO LE ENTIENDO  Y NO SE COMO                                         // knowledge                                                                       
** [17] "LO TIENE EN CASA PARA ALGUNA EMERGENCIA                                     // costs                                                                       
** [18] "NO TIENE CUENTA BANCARIA                                                    // knowledge                                                                       
** [19] "LES COBRAN POR DEJAR SU DINERO                                              // trust                                                                       
** [20] "PORQUE LES DICEN QUE NO DEBEN DE AHORRAR, ESO SE LOS DICE LA VOCAL PORQUE SI AHORRAN LES QUITAN EL PROGRAMA // knowledge                                 
** [21] "CREE QUE SI DEJA UN AHORRO Y LE QUITAN SU PROGRAMA ESE DINERO QUE AHORRO SE LO QUITEN PORQUE YA NO RECIBA EL PROGRAMA. ESE ES EL TEMOR A NO AHORRAR // trust
** [22] "PORQUE ME HAN DICHO QUE EN EL BANCO SE QUEDAN CON LO QUE DEJE               // trust                                                                       

#delimit ;
local drop
	`"
	"NO TIENE CUENTA"
	"'
;
local donttrust 
	`"
	"QUITA"
	"LES QUITAN"
	"DESCONFIANZA"
	"CONFIANZA"
	"ME HAN DICHO"
	"SEGURO"
	"CREE QUE SI DEJA"
	"LES COBRAN"
	"'
; // for now including things about not knowing how to use it in mistrust;
local knowledge /* don't know can save or don't know how to save */
	`"
	"NO TIENE CUENTA"
	"NO TIENE PERMITIDO"
	"NO LE PERMITE"
	"INFORMADO"
	"NO SE MANEJAR"
	"NO NOS HAN DICHO QUE PODAMOS"
	"NO SE COMO"
	"PORQUE LES DICEN QUE NO DEBEN"
	"QUE LO DEJARA"
	"NO PUEDE"
	"'
;
local notenough
	`"
	"LO UTILIZA"
	"'
;
local ineligible /* will become ineligible for the program if they have savings */
	`"
	"CANCELAN"
	"'
;
#delimit cr

gen drop = (h13a01!=1) // in this one all of those with cards were asked the 
	// question about whether saved in Bansefi account and if not, why not
tab date if !drop 

foreach ll of local outcomes {
	if "`ll'"=="drop" continue
	gen byte `ll' = 0 if !drop
}
replace donttrust = 1 if h13a081b==1 /// Porque si no saco todo el dinero, lo que queda en el banco puedo perderlo */
					    | h13a081e==1 //  Porque se desaparece mi ahorro 
replace ineligible = 1 if h13a081a==1 // Porque si ahorro en esa cuenta me pueden dar de baja de Oportunidades
replace notenough = 1 if h13a081c==1 /// Porque no me alcanza para ahorrar
					   | h13a081d==1 //  Porque necesito todo el dinero
foreach list in `outcomes' {
	foreach x of local `list' {
		replace `list' = 1 if strpos(h13a081s,"`x'")>0
	}
} 
gen especificar = !mi(h13a081s)
rename h13a081s reason

gen didntsave = (h13a08==2)

keep folio h106b localidad dateint drop `outcomes' didntsave especificar reason h13a11
tempfile mapo
save `mapo', replace

// Educacion sample
use "$proc/hogar_educacion_diciembre_2010.dta", clear
count
merge 1:1 folio using "$proc/entrevistas_educacion_noviembre_2010.dta", ///
	keepusing(folio edo mpio locali vis1f) keep(match)
drop _m
rename vis1f dateint
stringify locali, digits(9) gen(localidad) // already includes state & mun

count
foreach var of varlist h13191* {
	mydi "`var'"
	tab `var' // if h1301b>=2
}

** Reasons 
 ** [1] "YA NO RECIBE APOYOS                                                         // drop                                                                                             
 ** [2] "PORQUE NOS LO QUITAN POR NO RETIRAR TODO EL IMPORTE     					// trust                                                        
 ** [3] "PORQUE SOLO LE DEPOSITARON UNA VEZ              							// drop                                                                
 ** [4] "NO SABIA                                                                    // knowledge                                 
 ** [5] "POR QUE LE AN DICHO QUE SIEMPRE RETIRE TODO POR QUE SI NO SE LO QUITAN      // trust                                 
 ** [6] "TIENE UN AÑO SIN RECIBIR EL APOYO                                           // drop                          
 ** [7] "NO TIENE EL PROGRAMA LA DIERONDE BAJA                                       // drop                                 
 ** [8] "POR QUE LE HAN DEPOSITADO EL APOYO DESDE EL PERIODO ABRIL-MAYO       		// drop                                           
 ** [9] "NO SABE COMO HACERLO                                                        // knowledge                                    
** [10] "NO HA TENIDO NECESIDAD                                                      // not necessary                       
** [11] "NO LO HABIA PENSADO                                                         // not thought                          
** [12] "NO HABIA PENSADO EN ESO TODO ME LO GASTO                                    // not enough $                               
** [13] "NO HA RECIBIDO EL APOYO EN 8 MESES                                          // drop                                     
** [14] "NO HA RECIBIDO SU APOYO DE OPORTUNIDADEZ                                    // drop                                    
** [15] "NO SABE COMO                                                                // knowledge                                    
** [16] "NOLE HAN DADO SU APOYO                                                      // drop                                    
** [17] "NO SE PUEDE AHORRAR Y LAS PROMOTORAS LE INDICAN QUE NO DEJEN DINERO         // knowledge                                    
** [18] "POR QUE LE DIJIERON QUE SI NO COBRABA SU APOYO EN UN SOLO RETIRO SE CONGELABA LA CUENTA // ineligible                        
** [19] "NO   HA RECIBIDO APOYO EN UN AÑO                                            // drop              
** [20] "NO HA RECIBIDO APOYO EN UN AÑO                                              // drop                                    
** [21] "NO LO HA PENSADO                                                            // not thought                                    
** [22] "POR QUE DESCONOCE COMO SE REALIZA                                           // knowledge                                    
** [23] "NO LE HAN DEPOSITADO                                                        // drop                                    
** [24] "POR QUE SI DEJO MI DINERO EL BANCO ME LO QUITA                              // trust                                   
** [25] "NO HA TENIDO LA INTENCION DE AHORRAR                                        // not necessary                            
** [26] "NUNCA LO HABIA CONSIDERADO                                                  // not thought                                    
** [27] "POR QUE LE DIJERON QUE SIEMPRE SACARA TODO EL DINERO SI NO LO PERDIA        // trust                                 
** [28] "POR QUE NO TIENE TIEMPO DE IR A REALIZAR EL TRAMITE                         // knowledge                                       
** [29] "LE INFORMARON QUE HAY QUE HACER OTRO TRAMITE                                // knowledge                                    
** [30] "NO HA RECIBIDO APOYOS ECONOMICOS                                            // drop                                    
** [31] "PORQUE SI LO DEJA DESPUES DE 2 DIAS SE DESAPARECE EL DINERO                 // trust                                    
** [32] "NO HE RECIBIDO EL APOYO EN CASI UN AÑO                                      // drop                                    
** [33] "PORQUE NO HA RECIBIDO EL APOYO EN UN AÑO                                    // drop                                    
** [34] "APENAS VA A HABRIR LA CUENTA                                                // drop                                    
** [35] "YA NO TIENE EL APOYO DE OPORTUNIDADES                                       // drop                                    
** [36] "NO LO HA PENSADO Y NO SABE SI LE QUITEN EL DINERO                           // not thought                                   
** [37] "DEJO DINERO EN LA CUENTA DE AHORROS Y DESAPARECIO EN LA CUENTA              // trust                                    
** [38] "POR QUE HA DEJADO UN PAR DE VECES 200 PESOS Y DESPUES YA NO ESTA COMPLETO   // trust                                    
** [39] "YA NO TIENE EL APOYO MONETARIO DE OPORTUNIDADES                             // drop                                    
** [40] "PORQUE SIEMPRE HAY MUCHA GENTE Y SON MUCHOS LOS REQUISITOS QUE SOLICITAN    // knowledge                                    
** [41] "POQUE CUANDO SE VA A SACAR HAY MUCHA JENTE                                  // costs                                    
** [42] "SE LE HACE MEJOR TENERLO EN LA CASA                                         // costs                                    
** [43] "PORQUE SE LO QUITA EL BANCO                                                 // trust                                    
** [44] "POR QUE YA NO TIENE EL APOYO DEL PROGRAMA                                   // drop                                    
** [45] "NO HA TENIDO TIEMPO PARA VER CUAL ES EL PROCEDIMIENTO DE AHORRO}}           // knowledge                                    
** [46] "PORQUE LES HAN DICHO QUE SAQUEN TODO                                        // knowledge                                    
** [47] "PORQUE NO LE REGRESAN SU DINERO, YA LE PASO QUE LE RETUVIERON               // trust                                    
** [48] "TENIA QUE DEPOSITAR 1500 PARA ABRIR LA CUENTA                               // knowledge                                   
** [49] "POR QUE DESCONFIA DE LOS BANCOS                                             // trust                                    
** [50] "POR QUE NO SABE COMO SE AHORRA EN LA CUENTA                                 // knowledge                                    
** [51] "PORQUE NO UTILIZA BANSEFI                                                   // ?                                    
** [52] "NO SABIA QUE PODIA DEJAR EL DINERO EN LA CUENTA BANSEFI                     // knowledge                                    
** [53] "POR QUE LES DIJERON QUE RETIRARAN TODO SU DINERO ( LA VOCAL)                // knowledge                                   
** [54] "LES DIJERON EN LA MAPO QUE NO DEJARAN DINERO EN SUS CUENTAS PORQUE EL GOBIERNO IBA A DECIR QUE NO LO NECESITABAN // ineligible
** [55] "NO SABIA COMO HACERLO                                                       // knowledge                                    
** [56] "NO SABIA                                                                    // knowledge                                    
** [57] "POE SI LO DEJO EN EL BANCO LO QUITAN                                        // trust                                    
** [58] "SU PRIMER PAGO SE LO DARAN EN NOVIEMBRE                                     // drop                                    
** [59] "NO HA RECIBIDO EL APOYO DESDE HACE 10 MESES                                 // drop                                    
** [60] "NO HA RECIBIDO EL APOYO EN 8 MESES                                          // drop                                    
** [61] "LES RECOMENDARON RETIRAR TODO YA QUE SI DEJAN ALGO SE LOS QUITAN POR ESTO NO AHORRA // trust                             
** [62] "NO EXPLICARON CUAL ERA EL PROCEDIMIENTO PATRA AHORRA                        // knowledge                                     
** [63] "PORQUE EL BANCO SE LO QUEDA                                                 // trust                                    
** [64] "NECESITA HACER UN TRAMITE                                                   // knowledge                                    
** [65] "PORQUE ES BIEN SABIDO QUE SI DEJA PARTE DEL APOYO EN LA TARJETA SE LOS QUITAN O YA NO APARECE EN LA CUENTA // trust     
** [66] "POR QUE LE DIJERON QUE EL APOYO ES DEL GOBIERNO Y DEBE DE SACARLO TODO      // ineligible (implicit -- or could be knowledge)                                    
** [67] "PORQUE LE INFORMARON QUE AUN NO PODIA AHORRAR                               // knowledge                                    
** [68] "NO FUNCIONA LO DEL AHORRO                                                   // knowledge (learning benefit of saving)                                    
** [69] "POR QUE SI NO LO RETIRA SE LO QUITAN                                        // trust                                               

foreach ll of local outcomes {
	if "`ll'"=="drop" continue
	gen byte `ll' = 0 if h1302==1 // card
}
replace ineligible = 1 if h13191a==1 // Porque si ahorro en esa cuenta me pueden dar de baja de Oportunidades
replace donttrust = 1 if h13191b==1 // Porque si no saco todo el dinero, lo que queda en el banco puedo perderlo (in this version they didn't have option "Porque se desaparece mi ahorro" like they did in MAPO sample, but these are so similar)
replace notenough = 1 if h13191c==1 /// Porque no me alcanza para ahorrar
					   | h13191d==1 // Porque necesito todo el dinero
gen drop = (h1318!=1)

#delimit ;
local drop 
	`"
	"APENAS"
	"HA RECIBIDO"
	"HE RECIBIDO"
	"LE HAN DEPOSITADO"
	"HAN DADO"
	"NO TIENE EL PROGRAMA"
	"YA NO"
	"SIN RECIBIR"
	"UNA VEZ"
	"PRIMER PAGO SE LO DARAN"
	"'
;
local donttrust 
	`"
	"PORQUE NOS LO QUITAN"
	"SE LO QUITAN"
	"SE LO QUITA"
	"LO QUITAN" 
	"LOS QUITAN"
	"LO QUEDA"
	"EL BANCO ME LO QUITA"
	"LO PERDIA"
	"DESAPARECIO"
	"DESAPARECE"
	"YA NO ESTA COMPLETO"
	"NO LE REGRESAN SU DINERO"
	"DESCONFIA"
	"'
; 
local knowledge /* don't know can save or don't know how to save */
	`"
	"NO SABIA"
	"NO SABE COMO"
	"DESCONOCE"
	"NO HA TENIDO TIEMPO PARA VER CUAL ES"
	"NO EXPLICARON"
	"NO FUNCIONA"
	"NO SE PUEDE AHORRAR"
	"POR QUE NO TIENE TIEMPO DE IR A"
	"LE INFORMARON QUE HAY QUE"
	"PORQUE SIEMPRE HAY"
	"PORQUE LES HAN DICHO QUE SAQUEN"
	"TENIA QUE DEPOSITAR 1500 PARA ABRIR"
	"POR QUE LES DIJERON QUE RETIRARAN"
	"TRAMITE"
	"PORQUE LE INFORMARON QUE AUN NO PODIA"
	"POR QUE LE DIJERON QUE SIEMPRE"
	"POR QUE LE AN DICHO"
	"'
;
local ineligible 
	`"
	"POR QUE LE DIJIERON QUE SI NO"
	"LES DIJERON EN LA MAPO"
	"POR QUE LE DIJERON QUE EL APOYO"
	"'
;
local notenough
	`"
	"TODO ME LO GA"
	"'
;
#delimit cr
foreach list in `outcomes' {
	foreach x of local `list' {
		replace `list' = 1 if strpos(h13191es,"`x'")>0
	}
} 
gen especificar = !mi(h13191es)
rename h13191es reason
gen didntsave = (h1319==2)
keep folio h106b localidad dateint drop `outcomes' didntsave especificar reason h1305
append using `mapo'
gen municipio = substr(localidad, 1, 5)

merge m:1 localidad using "$proc/familias_loc.dta"
assert _merge==3 if !drop
drop _merge

gen dateswitch = .
format dateswitch %td
local day_received_card = round((2+4+6+8+2)/5) // average day received card (always in second month of bimester)
// (see Guia_PS_Migracion_tarjeta_debito_v0.0 document from Oportunidades)

forval year=2008/2014 {
	forval b=1/6 {
		replace dateswitch = mdy(`=`b'*2',`day_received_card',`year') if bimswitch==`year'`b' // average day switched (will have some measurement error since individuals received their cards on different days but I couldn't get data on the exact day each household in this sample received their cards from Oportunidades)
	}
}
local days_per_bimester = 365/6
local days_per_month    = 365/12
replace dateswitch = dateswitch + `days_per_bimester'*2 // 2 bimester delay

gen dateint_td = date(dateint,"DMY")
format dateint_td %td
gen card_lt_1y = . // card less than 1 year
replace card_lt_1y = 0 if !drop
replace card_lt_1y = 1 if (dateint_td < dateswitch + 12*(365/12))

gen days_card = dateint_td - dateswitch
tab days_card if !drop

drop if days_card < 0 // 1 loc in wave 2 with only 4 obs

summ days_card if !drop, d
gen card_less = (days_card <= r(p50)) if !drop // median split
forval i=0/1 {
	summ days_card if card_less==`i' & !drop, d
}

local dummy card_less

tab `dummy' if !drop

tab dateswitch if !drop
tab `dummy' dateswitch if !drop

count if !drop
count if !drop & especificar==1
de

// Keep only the relevant observations
keep if !drop

gen better = h13a11 if !mi(h13a11)
replace better = h1305 if !mi(h1305)
tab better 
tab better if days_card > 14*`days_per_month' // !used! in conclusion
tab better if days_card < 14*`days_per_month'

tempfile encasdu_reasons // reasons for not saving; at hh level
save `encasdu_reasons', replace

// CONTROLS/BALANCE VARS --------------------------------------------------------

// MAPO SAMPLE

// SOCIODEMOGRAPHIC CHARACTERISTICS
use "$proc/integrantes_mapo_noviembre_2010.dta", clear
count

// sociodem is defined in encelurb_dataprep_preliminary.doh
#delimit ;
sociodem , 
	edad(h209) 
	sexo(h210) 
	jefe(h211) 
	casado(h214)
	asistio(h3b02)
	nivel(h3b03a)
	grado(h3b03b)
	leer(h3b01)
	trabajo(h4a01)
	trabajo2(h4a02)
	salud(h5a01)
	encasdu
;
#delimit cr

hhlevel encasdu // in encelurb_dataprep_preliminary.doh
	
tempfile encasdu_mapo_ind
save `encasdu_mapo_ind', replace	

// BENEFICIARY SOCIODEMOGRAPHICS
use "$proc/integrantes_mapo_noviembre_2010.dta", clear
merge m:1 folio using "$proc/hogar_mapo_noviembre_2010.dta"
	// h208 indicates who is the beneficiary
count

// need to sociodem it again to have the variables for beneficiary
#delimit ;
sociodem , 
	edad(h209) 
	sexo(h210) 
	jefe(h211) /* not actually jefe; person being interviewed */
	casado(h214)
	asistio(h3b02)
	nivel(h3b03a)
	grado(h3b03b)
	leer(h3b01)
	trabajo(h4a01)
	trabajo2(h4a02)
	salud(h5a01)
	encasdu
;
#delimit cr

gen titular = (intp == h208)
tab titular

// if titular missing use spouse
keep if titular==1

gen titular_age = edad
gen titular_male = (sexo == 1)
gen titular_married = (married == 1)

keep folio titular_*
tempfile encasdu_mapo_titulares
save `encasdu_mapo_titulares', replace

// INCOME
use "$proc/integrantes_mapo_noviembre_2010.dta", clear
merge m:1 folio using "$proc/hogar_mapo_noviembre_2010.dta", keepusing(h4a21*) // other income
	// is in the household data set in ENCASDU
count

local i=1
local p h4a // prefix
foreach x in 13 { // ENCASDU doesn't have questions about other jobs
		// in contrast to ENCELURB
	local 1 `p'`x'b // amount
	local 2 `p'`x'a // periodo
	local x2 = `x' + 2
	*** cap drop labincome`i' portion`i'
	*** extreme outliers
	daywk_outliers `1' `2'
	gen `p'`x'_an = 0 // _an = anual
	replace `p'`x'_an = `1'*365/(7/5) if `2'==1 // daily - assume 5 d/wk work
	replace `p'`x'_an = `1'*(365/7)  if `2'==2 // weekly
	replace `p'`x'_an = `1'*(365/15) if `2'==3 // quincena
	replace `p'`x'_an = `1'*12       if `2'==4 // monthly 
	replace `p'`x'_an = `1'*1        if `2'==5 // annual
	replace `p'`x'_an = `1'*1        if `2'==6 // por pieza (no addl info)
	replace `p'`x'_an = `1' if `1'==99998 | `1'==9998 // leave as is if top coded
	gen f_labincome`i' = (`2'==9) | (`2'==7) 
		// 7 is "otro periodo de pago"
	** portion of year worked
	local wk `p'`x2'b
	local mo `p'`x2'a
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
clean `p'13_an, l(5) v(labincome) 

local list1
local list2
forval i=1/5 {
	local 1 h4a21`i'b
	local 2 h4a21`i'a
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

collapse (sum) labincome (mean) othincome (max) f?_* drop, by(folio) 	
	// in this one, othincome is (mean) because it came from household
	//  data set; since I merged that into the individual data set 
	//  that means it's repeated for every individual
postcollapse `p'13_an , v(labincome)
postcollapse `list1', v(othincome)

tempfile encasdu_mapo_income
save `encasdu_mapo_income', replace

// HOUSING CHAR AND ASSETS  
use "$proc/hogar_mapo_noviembre_2010.dta", clear
gen byte piso_firme = (h1005==2) | (h1005==3)
gen byte dirt_floor = !piso_firme
gen rooms = h1009
replace rooms = . if h1009==9
gen agua_entubada = (h1013==1)
gen sin_sanitario = (h1014!=1)
gen sin_drenaje   = (h1018==2 | h1018==9)

local p h901
assetify , p(`p') post // defined in encelurb_dataprep_preliminary.doh
** testing
foreach var of varlist has_* {
	tab `var'
}

#delimit ;
gen has_tv = max(has_tv_color, has_tv_cable);
gen has_electricos = 1 if 
	  has_compu==1
	| has_horno_elec==1
	| has_microonda==1
	| has_cafetera==1 ;				
#delimit cr

myzscore `assets_bothsurveys', replace
pca `assets_bothsurveys' 
predict assetindex
summ assetindex 
gen z_assetindex = (assetindex - r(mean))/r(sd)

tempfile encasdu_mapo_hh
save `encasdu_mapo_hh', replace

// EDUCACION SAMPLE
use "$proc/integrantes_educacion_diciembre_2010.dta", clear
count
de

// SOCIODEM CHAR
#delimit ;
sociodem , 
	edad(h209) 
	sexo(h210) 
	jefe(h211)
	casado(h214)
	asistio(h3a02)
	nivel(h3a03a)
	grado(h3a03b)
	leer(h3a01)
	trabajo(h4a01)
	trabajo2(h4a02)
	salud(h501)
	encasdu
;
#delimit cr

hhlevel encasdu // in encelurb_dataprep_preliminary.doh

append using `encasdu_mapo_ind'
tempfile encasdu_ind
save `encasdu_ind', replace // has both MAPO and Educacion samples

// BENEFICIARY SOCIODEMOGRAPHICS
use "$proc/integrantes_educacion_diciembre_2010.dta", clear
merge m:1 folio using "$proc/hogar_educacion_diciembre_2010.dta", keepusing(h208) 
	// h208 indicates who is the beneficiary
count

// need to sociodem it again to have the variables for beneficiary
#delimit ;
sociodem , 
	edad(h209) 
	sexo(h210) 
	jefe(h211)
	casado(h214)
	asistio(h3a02)
	nivel(h3a03a)
	grado(h3a03b)
	leer(h3a01)
	trabajo(h4a01)
	trabajo2(h4a02)
	salud(h501)
	encasdu
;
#delimit cr

gen titular = (intp == h208)
tab titular

// if titular missing use spouse
** replace titular = (intp == 2) if (h208==97)
keep if titular==1

gen titular_age = edad
gen titular_male = (sexo == 1)
gen titular_married = (married == 1)

keep folio titular_*

append using `encasdu_mapo_titulares'
tempfile encasdu_titulares
save `encasdu_titulares', replace // has both MAPO and Educacion samples

// INCOME
use "$proc/integrantes_educacion_diciembre_2010.dta", clear
merge m:1 folio using "$proc/hogar_educacion_diciembre_2010.dta", keepusing(h4a21*) // other income
	// is in the household data set in ENCASDU
count

local i=1
local p h4a // prefix
foreach x in 13 17 31 { // 13 is primary job, 17 is secondary, 31 is child work (ages 5-15)
		// which in the other sample was included with the primary job question (i.e.
		// that question encompassed ages 5+).
	local 1 `p'`x'b // amount
	local 2 `p'`x'a // periodo
	local x2 = `x' + 2
	*** cap drop labincome`i' portion`i'
	*** extreme outliers
	daywk_outliers `1' `2'
	gen `p'`x'_an = 0 // _an = anual
	replace `p'`x'_an = `1'*365/(7/5) if `2'==1 // daily - assume 5 d/wk work
	replace `p'`x'_an = `1'*(365/7)  if `2'==2 // weekly
	replace `p'`x'_an = `1'*(365/15) if `2'==3 // quincena
	replace `p'`x'_an = `1'*12       if `2'==4 // monthly 
	replace `p'`x'_an = `1'*1        if `2'==5 // annual
	replace `p'`x'_an = `1'*1        if `2'==6 // por pieza (no addl info)
	replace `p'`x'_an = `1' if `1'==99998 | `1'==9998 // leave as is if top coded
	gen f_labincome`i' = (`2'==9) | (`2'==7) 
		// 7 is "otro periodo de pago"
	** portion of year worked
	if `x'!=31 {
		local wk `p'`x2'b
		local mo `p'`x2'a
		tempvar mi_portion
		recode `wk' (99 = 0)
		replace `wk' = 0 if `mo'>0 & `mo'<99 & `wk'>4
		gen portion`i' = (`mo'+(`wk'/4))/12 if `mo'>0 
		replace portion`i' = `wk'/52 if `mo'==0
		replace portion`i' = 1 if `mo'==99 | `mo'==12
		assert portion`i' <= 1 if !mi(portion`i')
		// confirmed that results are robust to instead using portion=1 for all
		replace `p'`x'_an = `p'`x'_an*portion`i' if !mi(portion`i')
	}
	// else (for child labor they didn't ask portion question) assume full portion
	local ++i
}
clean `p'13_an `p'17_an `p'31_an, l(5) v(labincome) // because the MAPO survey doesn't have second.
	// job, don't include it here either

local list1
local list2
forval i=1/5 {
	local 1 h4a21`i'b
	local 2 h4a21`i'a
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

collapse (sum) labincome (mean) othincome (max) f?_* drop, by(folio) 	
	// in this one, othincome is (mean) because it came from household
	//  data set; since I merged that into the individual data set 
	//  that means it's repeated for every individual
postcollapse `p'13_an `p'17_an, v(labincome)
postcollapse `list1', v(othincome)

append using `encasdu_mapo_income'

gen totinc = othincome + labincome

tempfile encasdu_income
save `encasdu_income', replace

// HOUSING CHAR AND ASSETS
use "$proc/hogar_educacion_diciembre_2010.dta", clear
gen byte piso_firme = (h1005==2) | (h1005==3)
gen byte dirt_floor = !piso_firme
gen rooms = h1010
replace rooms = . if h1010==9
gen agua_entubada = (h1013==1)
gen sin_sanitario = (h1014!=1)
gen sin_drenaje = (h1018==2 | h1018==9)

local p h901
assetify , p(`p') post // defined in encelurb_dataprep_preliminary.doh
** testing
foreach var of varlist has_* {
	tab `var'
}

#delimit ;
gen has_tv = max(has_tv_color,has_tv_cable) ;
gen has_electricos = 1 if 
	  has_compu==1
	| has_horno_elec==1
	| has_microonda==1
	| has_cafetera==1 ;				
#delimit cr

myzscore `assets_bothsurveys', replace
pca `assets_bothsurveys' 
predict assetindex
summ assetindex 
gen z_assetindex = (assetindex - r(mean))/r(sd)

append using `encasdu_mapo_hh'

tempfile encasdu_hh
save `encasdu_hh', replace

// HOUSEHOLD LEVEL DATA SETS
// MAPO sample
use "$proc/hogar_mapo_noviembre_2010.dta", clear
count
merge 1:1 folio using "$proc/entrevistas_mapo_noviembre_2010.dta", ///
	keepusing(folio edo mpio locali vis1f) keep(match)
drop _merge
rename vis1f dateint
stringify locali, digits(9) gen(localidad) // already includes state & mun

// MERGE LOC DATA 
gen pozarica = (localidad=="301240159")
replace localidad="301310001" if localidad=="301240159"
	// Poza Rica, Papantla, Veracruz incorporated into Poza Rica de Hidalgo, Poza Rica de Hidalgo, Veracruz
	// (see http://goo.gl/jvOjev)
	// result: (72 real changes made) - those living in this locality
uniquevals localidad // 179 localities

gen drop = (h13a01!=1)
keep folio h106b localidad dateint drop
tempfile mapo
save `mapo', replace	

// Educacion sample
use "$proc/hogar_educacion_diciembre_2010.dta", clear
count
merge 1:1 folio using "$proc/entrevistas_educacion_noviembre_2010.dta", keepusing(folio edo mpio locali vis1f) keep(match)
drop _merge
rename vis1f dateint
stringify locali, digits(9) gen(localidad) // already includes state & mun

gen drop = (h1318!=1)
keep folio h106b localidad dateint drop 
append using `mapo'

merge 1:1 folio using `encasdu_ind'
assert _merge==3
drop _merge

merge 1:1 folio using `encasdu_titulares'
** assert _merge==3 // in this case not true 
	// because some households didn't report who beneficiary was
drop _merge

merge 1:1 folio using `encasdu_income'
assert _merge==3
drop _merge

merge 1:1 folio using `encasdu_hh'
assert _merge==3
drop _merge

// More vars
replace totinc = totinc/12 // monthly
gen oc_por_cuarto = n_member/rooms

//  Keep only those who have a card
keep if !drop

tempfile encasdu_controls
save `encasdu_controls', replace

// MERGE IT ALL TOGETHER
use `encasdu_reasons', clear
merge 1:1 folio using `encasdu_controls'
assert _merge == 2 | _merge == 3
keep if _merge == 3
drop _merge

*****************************************
** MERGE WITH LOCALITIY LEVEL CONTROLS
*****************************************		
// Log number of POS terminals
merge_on localidad using "$proc/bdu_baseline.dta" if !drop, ///
	exists(data_POS) controls(log_pos) 
	// 100% have `exists' == 1
	// 0 localities with `exists' == 0

// Bansefi data on savings and transactions 
merge_on localidad using "$proc/bansefi_baseline_loc.dta" if !drop, ///
	exists(data_bansefi) controls(N_withdrawals net_savings_ind_0 log_net_savings_ind_0)
	// 98% have `exists' == 1
	// 2 localities with `exists' == 0
	
// CNBV data on branches, ATMs, cards
merge_on municipio using "$proc/cnbv_baseline_mun.dta" if !drop, ///
	exists(data_cnbv) controls(log_branch_number log_atm_number log_cards_all)
	// 100% have `exists' == 1
	// 0 localities with `exists' == 0

// Price data from micro-CPI
merge_on municipio using "$proc/cpix_baseline_mun.dta" if !drop, ///
	exists(data_cpix) controls(log_precio)
	// 80% have `exists' == 1
	// 6 localities with `exists' == 0

// Wage data from ENOE
merge_on municipio using "$proc/enoe_baseline_mun.dta" if !drop, ///
	exists(data_enoe) controls(log_wage)
	// 100% have `exists' == 1
	// 0 locality with `exists' == 0

**********
** SAVE **
**********
save "$proc/encasdu_forreg.dta", replace

*************
** WRAP UP **
*************
log close
exit
