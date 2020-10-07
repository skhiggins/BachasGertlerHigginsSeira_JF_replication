** READ IN RAW BANSEFI DATA GIVEN TO US SEPTEMBER 3 2015
** Pierre Bachas and Sean Higgins
** Created 5sep2015

*********
** LOG **
*********
time // saves locals `date' (YYYYMMDD) and `time' (YYYYMMDD_HHMMSS)
local project 03_bansefi_movimientos_dataprep
cap log close
set linesize 200
log using "$logs/`project'_`time'.log", text replace
di "`c(current_date)' `c(current_time)'"
pwd

************
** LOCALS **
************
local new = 0
local all = 1

*************************
** READ & EXPLORE DATA **
*************************
if `new'==0 | `all'==1 {
	quietly {
		forval year=2007/2015 {
			noisily mydi "`year'", stars(4) span
			clear
			// IMPORT DATA
			#delimit ;
			infix 
					str7   prod_ven         1-7   /* Producto Vendible (1-4) & Tarifa Vendible (5-7)                           */
					int    sucadm           8-11  /* Referencia que administra el acuerdo                                      */
					int    succar          12-15  /* Indica la referencia donde  realiza la transacción                        */
					str10  cuenta          16-25  /* Numéro de Acuerdo                                                         */
					str8   fecha_contable  26-33  /* Fecha Contable de la transacción (AAAAMMDD)   			*/
					/* only need fecha_contable; leave out the other two date variables
						which are missing for a lot of observations anyway
					str8   fecoprcn        34-41  /* Fecha de operación se realizo transacción (AAAAMMDD)                      */
					str8   fecvalor        42-49  /* Fecha valor a la que corresponde el movimiento (AAAAMMDD)                 */
					*/
					str1   naturaleza      50-50  /* D=DEBE (Egreso) H=HABER (Ingreso)                                         */
					double importe         51-67  /* Monto del movimiento realizado (99999999999999.99)                        */
					double trans           68-81  /* Numero de transacción asignada automaticamente por el sistema             */
					str8   cod_tx          82-89  /* Codigo de transacción del movimiento (Catalogo)                           */
					byte   cvetrans        90-91  /* Clave original de transaccion se integra con el clop y subclop            */
					long   codorigen       92-97  /* Clave original de transaccion se integra con el clop y subclop (Catalogo) */
					str50  descripcion     98-147 /* Contiene la descripcion de la transacción realizada						*/
				using "$data/Bansefi/MOV`year'.txt"
			;
			#delimit cr
			
			// FORMAT VARIABLES
			format importe   %16.2f
			format trans     %14.0f
			
			// EXTRACT the ATM code from the variable descripcion: generates variables ATM (ATM code) 
			generate hasATM = regexm(descripcion, " [0-9][0-9][0-9][0-9]$")
			
			// Kill extra blank spaces in ATM code
			local count = 1 
			quietly while `count' != 0 { 
				replace descripcion = subinstr(descripcion, "  ", " ", .) 
				capture drop temp 
				gen temp = strpos(descripcion, "  ") 
				summ temp 
				if r(max) == 0 & r(min) == 0 local count = 0 
			} 	
			
			gen temp_ATM = substr(descripcion, -11, .) if hasATM == 1
			
			replace temp_ATM = regexr(temp_ATM, "^[A-Z] ", "") // This erases a letter that sometimes remains from previous word string
			gen ATM = word(temp_ATM,1) // ATM is the first word remaining
			label var ATM "ATM code"		
			drop temp_ATM hasATM 
			
			// EXPLORE VARIABLES
			foreach var of varlist * {
				noisily mydi "`var'", stars(3) starchar("!")
				count if mi(`var')
				local n_mi = r(N)
				count
				noisily di "Proportion missing: " `n_mi'/r(N)
				noisily exampleobs `var' if !mi(`var'), n(50)
			}
			save "$proc/MOV`year'.dta", replace
		}
	}
}
if `new'==1 | `all'==1 { // the updated data for 2007
	quietly {
		local year_full 2007_nw
		local year 2007
		noisily mydi "`year'", stars(4) span
		clear
		// IMPORT DATA
		#delimit ;
		infix 
				str7	prod_ven         1-7   /* Producto Vendible (1-4) & Tarifa Vendible (5-7)                           */
				int		sucadm           8-11  /* Referencia que administra el acuerdo                                      */
				int		succar          12-15  /* Indica la referencia donde  realiza la transacción                        */
				str10	cuenta          16-25  /* Numéro de Acuerdo                                                         */
				str8	fecha_contable  26-33  /* Fecha Contable de la transacción (AAAAMMDD)   			*/
				/* only need fecha_contable; leave out the other two date variables
					which are missing for a lot of observations anyway
				str8	fecoprcn        34-41  /* Fecha de operación se realizo transacción (AAAAMMDD)                      */
				str8	fecvalor        42-49  /* Fecha valor a la que corresponde el movimiento (AAAAMMDD)                 */
				*/
				str1	naturaleza      50-50  /* D=DEBE (Egreso) H=HABER (Ingreso)                                         */
				double	importe       51-67  /* Monto del movimiento realizado (99999999999999.99)                        */
				double	trans         68-81  /* Numero de transacción asignada automaticamente por el sistema             */
				str8	cod_tx          82-89  /* Codigo de transacción del movimiento (Catalogo)                           */
				byte	cvetrans        90-91  /* Clave original de transaccion se integra con el clop y subclop            */
				long	codorigen       92-97  /* Clave original de transaccion se integra con el clop y subclop (Catalogo) */
				str50	descripcion     98-147 /* Contiene la descripcion de la transacción realizada						*/
			using "$data/Bansefi/MOV`year_full'.txt"
		;
		#delimit cr
		
		// FORMAT VARIABLES
		format importe   %16.2f
		format trans     %14.0f
		
		// EXTRACT the ATM code from the variable descripcion: generates variables ATM (ATM code) 
		generate hasATM = regexm(descripcion, " [0-9][0-9][0-9][0-9]$")
		
		// Kill extra blank spaces in ATM code
		local count = 1 
		quietly while `count' != 0 { 
			replace descripcion = subinstr(descripcion, "  ", " ", .) 
			capture drop temp 
			gen temp = strpos(descripcion, "  ") 
			summ temp 
			if r(max) == 0 & r(min) == 0 local count = 0 
		} 	
		
		gen temp_ATM = substr(descripcion, -11, .) if hasATM == 1
		
		replace temp_ATM = regexr(temp_ATM, "^[A-Z] ", "") // This erases a letter that sometimes remains from previous word string
		gen ATM = word(temp_ATM,1) // ATM is the first word remaining
		label var ATM "ATM code"		
		drop temp_ATM hasATM 
		
		// EXPLORE VARIABLES
		foreach var of varlist * {
			noisily mydi "`var'", stars(3) starchar("!")
			count if mi(`var')
			local n_mi = r(N)
			count
			noisily di "Proportion missing: " `n_mi'/r(N)
			noisily exampleobs `var' if !mi(`var'), n(50)
		}
		save "$proc/MOV`year'.dta", replace // overwrite the old MOV2007 which didn't have the
			// naturaleza variable
	}
}

*************
** WRAP UP **
*************
log close
exit
