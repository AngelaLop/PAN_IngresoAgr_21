
capture drop aux_propieta

/* V1: ¿La vivienda que habita este hogar es?
		1 = Alquilada	
		2 = Hipotecada
		3 = Propia	
		4 = Cedida
		5 = Condenada	
		6 = Otra					*/
gen     aux_propieta = 0
replace aux_propieta = 1		if  v1>=2 & v1<=4
replace aux_propieta = .		if  hogarsec==1

* Renta implícita de la vivienda propia
* V2_PAGARIA: Si tuvieran que pagar alquiler por esta vivienda cuanto estima que tendría que pagar al mes
destring v2_pagar, replace
egen aux_rentimp = max(v2_pagar), by(id)

gen	renta_imp = aux_rentimp		if  aux_propieta==1 & aux_rentimp>0 & aux_rentimp<99998
replace renta_imp = renta_imp / p_reg 
replace renta_imp = renta_imp / ipc_rel 

gen flag = 1				if  aux_propieta==1 & renta_imp==.
drop aux_rentimp
