
/*=========================================================================================================================================================================
								2: Preparacion de los datos: Variables de segundo orden
==========================================================================================================================================================================*/

/*(************************************************************************************************************************************************************************ 
*-------------------------------------------------------------	2.11: Variables de ingresos  ------------------------------------------------------------------------------
************************************************************************************************************************************************************************)*/

* Ingreso familiar total - total
egen    itf = rsum(itf_sin_ri renta_imp) 
replace itf = .		if  itf_sin_ri==.



/*========================================================================================================================================================================
                           3: Calculos
=========================================================================================================================================================================*/

/*(************************************************************************************************************************************************************************ 
*-------------------------------------------------------------	3.1. RESPUESTAS INCONSISTENTES DE INDIVIDUOS  -------------------------------------------------------------
************************************************************************************************************************************************************************)*/

/* Respuestas Inconsistentes de Individuos 
	Ocupados, con ingreso en la ocupación principal missing		(cohi = 800)
	Ocupados, con todas las fuentes de ingreso laboral missing	(cohi = 810)
	Asalariados, con ingreso de trabajo asalariado missing		(cohi = 811)
	Cuentapropistas, con ingreso por cuenta propia missing		(cohi = 812)
	Patrones, con ingreso por patrón missing			(cohi = 813)
	Sin salario, con ingreso laboral positivo			(cohi = 814)
	Individuos con ingreso laboral invalidado por la ONE		(cohi = 890)				*/
				
* Coherente a nivel individual
gen     cohi = 1

* Trabajadores ocupados, con el ingresos laboral de la ocupación principal missing
replace cohi = 800		if            ocupado==1 & ip==.  & relab!=4

* Trabajadores ocupados, con todas las fuentes de ingresos laborales missing
replace cohi = 810		if  cohi==1 & ocupado==1 & ila==. & relab!=4

* Trabajadores que se identifican como asalariados, con ingresos de trabajo asalariado missing
replace cohi = 811		if  cohi==1 & relab==2   & iasalp==. 

* Trabajadores cuentapropistas, con ingresos por cuenta propia missing
replace cohi = 812		if  cohi==1 & relab==3   & ictap==. 

* Patrones con ingresos por patrón missing
replace cohi = 813		if  cohi==1 & relab==1   & ipatrp==. 

* Otras inconsistencias
replace cohi = 815		if  iasalp!=.  & relab!=2
replace cohi = 816		if  ipatrp!=.  & relab!=1	
replace cohi = 817		if  ictapp!=.  & relab!=3	

replace cohi = 818		if  iasalnp!=. & relab_s!=2 
replace cohi = 819		if  ipatrnp!=. & relab_s!=1	
replace cohi = 820		if  ictapnp!=. & relab_s!=3
*replace cohi = 900		if  pid==.


/*(************************************************************************************************************************************************************************ 
*-------------------------------------------------------------	3.2. RESPUESTAS INCONSISTENTES DE HOGARES  ----------------------------------------------------------------
************************************************************************************************************************************************************************)*/
	
* Coherente a nivel del hogar
gen cohh = 1

* Familias con jefe con ingreso individual inconsistente
gen	aux = 0
replace aux = cohi		if  cohi~=1 & relacion==1
egen    aux2 = sum(aux),	by(id)
replace cohh = aux2		if  cohh==1 & aux2>0
drop aux aux2

* Familias con Único Ocupado (no Jefe) con Ingreso Individual Inconsistente
egen  aux = sum(ocupado),	by(id)
gen unico = 1			if  ocupado==aux & ocupado==1
drop aux
gen   aux = cohi		if  cohi~=1 & unico==1
egen aux2 = sum(aux),		by(id)
replace cohh = 801		if  cohh==1 & aux2>0 & aux2<.
drop aux aux2

* Familias con Jefe no Ocupado y Ocupado con Mayor Nivel Educativo Inconsistente

* Identifica Hogar con Jefe Ocupado
gen   aux_ocu = 1		if  relacion==1 & ocupado==1
egen jefe_ocu = max(aux_ocu),	by(id)

* Identifica Miembro (no Jefe) de Mayor Educación Incoherente
egen    max_edu = max(nivel),	by(id)
gen     edu_max = 1		if  max_edu==nivel & ocupado==1
replace edu_max = .		if  cohi==1
replace edu_max = .		if  relacion==1
replace edu_max = .		if  jefe_ocu==1

gen     aux = 0
replace aux = cohi		if  edu_max==1
egen    aux2 = sum(aux),	by(id)
replace cohh = 802		if  cohh==1 & aux2>0 & aux2<.
drop aux aux2

* Familias con ingresos laborales totales negativos o invalidados
replace cohh = 902		if  cohh==1 & ilf<0

* Familias con ingresos totales negativos o invalidados
replace cohh = 903		if  cohh==1 & itf<0

* Identifica respuestas inconsistentes de ingreso del hogar para el cálculo oficial de la pobreza 
gen coh_oficial = 1
	 

/*(************************************************************************************************************************************************************************ 
*-------------------------------------------------------  3.3 INGRESOS FAMILIARES AJUSTADOS POR FACTORES DEMOGRAFICOS  ----------------------------------------------------
************************************************************************************************************************************************************************)*/

* Ingreso laboral familiar per capita 
gen ilpc_m = ilf_m / miembros
gen ilpc   = ilf   / miembros


* Ingreso no laboral familiar per capita 
gen inlpc_m = inlaf_m / miembros
gen inlpc   = inlaf   / miembros


* Ingreso familiar per capita 
gen ipcf_sr = itf_sin_ri / miembros
gen ipcf_m  = itf_m      / miembros
gen ipcf    = itf        / miembros


***  Ingreso familiar equivalente ***
/* Ye=(A+a1.K1+a2.K2)^theta 
donde A=numero de adultos, K1=niños menores de 5 y K2=niños entre 6 y 14*/

* Ingreso equivalente A (theta=0.9, a1=0.5, a2=0.75) 
gen	ae = 1
replace ae = 0.50	if  edad<=5
replace ae = 0.75	if  edad>=6 & edad<=14
replace ae = 0		if  hogarsec==1
egen aefa = sum(ae),	by(id)
gen iea = itf/(aefa^0.9)

* Ingreso familiar laboral monetario equivalente A
gen ilea_m = ilf_m/(aefa^0.9)

* Ingreso equivalente B (theta=0.75, a1=0.5, a2=0.75) 
gen ieb = itf/(aefa^0.75)
drop ae  

* Ingreso equivalente C (theta=0.9, a1=0.3, a2=0.5) 
gen	ae = 1
replace ae = 0.3	if  edad<=5
replace ae = 0.5	if  edad>=6 & edad<=14
replace ae = 0		if  hogarsec==1
egen   aef = sum(ae),	by(id)
gen iec = itf/(aef^0.9)

* Ingreso equivalente D (theta=0.75, a1=0.3, a2=0.5) 
gen ied = itf/(aef^0.75)
drop ae aef 

* Ingreso equivalente E (escala Amsterdam, theta=1) 
gen	ae = 1
replace ae = 0.98	if  hombre==1 & edad>=14 & edad<=17
replace ae = 0.9	if  hombre==0 & edad>=14
replace ae = 0.52	if  edad<14
replace ae = 0		if  hogarsec==1
egen aef = sum(ae),	by(id)
gen  iee = itf/aef
drop ae aef

/*(************************************************************************************************************************************************************************ 
*-----------------------------------------------------------------------  3.7 PERCENTILES  --------------------------------------------------------------------------------
************************************************************************************************************************************************************************)*/

*** Ingreso per capita familiar 
* Percentiles
cuantiles ipcf [w=pondera] if ipcf>=0 & cohh==1, n(100) orden_aux(id com relacion edad) g(pipcf)

* Deciles
cuantiles ipcf [w=pondera] if ipcf>=0 & cohh==1, n(10)  orden_aux(id com relacion edad) g(dipcf)

	
*** Ingreso "oficial" 
* Percentiles
cuantiles ing_pob_mod_lp [w=pondera] if ing_pob_mod_lp>=0 & coh_oficial==1, n(100) orden_aux(id com relacion edad) g(p_ing_ofi)

* Deciles
cuantiles ing_pob_mod_lp [w=pondera] if ing_pob_mod_lp>=0 & coh_oficial==1, n(10)  orden_aux(id com relacion edad) g(d_ing_ofi)


*** Ingreso equivalente 
* Percentiles
cuantiles iea [w=pondera] if iea>=0 & cohh==1, n(100) orden_aux(id com relacion edad) g(piea)

* Deciles
cuantiles iea [w=pondera] if iea>=0 & cohh==1, n(5)   orden_aux(id com relacion edad) g(qiea)


/*(************************************************************************************************************************************************************************ 
*-----------------------------------------------------------------  3.8 NUEVAS VARIABLES  ---------------------------------------------------------------------------------
************************************************************************************************************************************************************************)*/

* Ponderador de Ingresos
cap gen pondera_i = pondera

* IPC promedio del año 2005 
gen	ipc05 = 161.728		if  pais=="ARG"
replace ipc05 = 116.628		if  pais=="BOL"
replace ipc05 = 151.421		if  pais=="BRA"
replace ipc05 = 113.642		if  pais=="CHL"
replace ipc05 = 139.651		if  pais=="COL"
replace ipc05 = 169.897		if  pais=="CRI"
replace ipc05 = 230.432		if  pais=="DOM"
replace ipc05 = 175.438		if  pais=="ECU"
replace ipc05 = 118.020		if  pais=="SLV"
replace ipc05 = 143.800		if  pais=="GTM"
replace ipc05 = 149.544		if  pais=="HND"
replace ipc05 = 127.151		if  pais=="MEX"
replace ipc05 = 100.000		if  pais=="NIC"
replace ipc05 =  81.813		if  pais=="PAN"
replace ipc05 = 150.876		if  pais=="PRY"
replace ipc05 = 110.114		if  pais=="PER"
replace ipc05 = 162.281		if  pais=="URY"
replace ipc05 = 254.992		if  pais=="VEN"

* IPC promedio del año 2011
gen	ipc11 = 464.420		if  pais=="ARG"
replace ipc11 = 175.438		if  pais=="BOL"
replace ipc11 = 202.995		if  pais=="BRA"
replace ipc11 = 141.991		if  pais=="CHL"
replace ipc11 = 184.227		if  pais=="COL"
replace ipc11 = 280.733		if  pais=="CRI"
replace ipc11 = 340.573		if  pais=="DOM"
replace ipc11 = 228.592		if  pais=="ECU"
replace ipc11 = 146.890		if  pais=="SLV"
replace ipc11 = 204.817		if  pais=="GTM"
replace ipc11 = 221.800		if  pais=="HND"
replace ipc11 = 163.327		if  pais=="MEX"
replace ipc11 = 171.752		if  pais=="NIC"
replace ipc11 = 106.488		if  pais=="PAN"
replace ipc11 = 228.908		if  pais=="PRY"
replace ipc11 = 130.643		if  pais=="PER"
replace ipc11 = 249.065		if  pais=="URY"
replace ipc11 = 887.767		if  pais=="VEN"

* Factor de Paridad de Poder de Compra 2005 
gen	ppp05 =    1.353	if  pais=="ARG"
replace ppp05 =    2.571	if  pais=="BOL"
replace ppp05 =    1.571	if  pais=="BRA"
replace ppp05 =  387.361	if  pais=="CHL"
replace ppp05 = 1191.742	if  pais=="COL"
replace ppp05 =  278.961	if  pais=="CRI"
replace ppp05 =   20.396	if  pais=="DOM"
replace ppp05 =    0.501	if  pais=="ECU"
replace ppp05 =    4.812/8.75	if  pais=="SLV"
replace ppp05 =    4.540	if  pais=="GTM"
replace ppp05 =    9.662	if  pais=="HND"
replace ppp05 =    7.648	if  pais=="MEX"
replace ppp05 =    7.297	if  pais=="NIC"
replace ppp05 =    0.611	if  pais=="PAN"
replace ppp05 = 2127.796	if  pais=="PRY"
replace ppp05 =    1.653	if  pais=="PER"
replace ppp05 =   15.310	if  pais=="URY"
replace ppp05 = 1251.122	if  pais=="VEN"

* Factor de Paridad de Poder de Compra 2011 
gen	ppp11 =    2.768382	if  pais=="ARG"
replace ppp11 =    2.9061057	if  pais=="BOL"
replace ppp11 =    1.6587826	if  pais=="BRA"
replace ppp11 =  391.64424	if  pais=="CHL"
replace ppp11 = 1196.9546	if  pais=="COL"
replace ppp11 =  343.78567	if  pais=="CRI"
replace ppp11 =   20.74103	if  pais=="DOM"
replace ppp11 =    0.54723445	if  pais=="ECU"
replace ppp11 =    0.53077351	if  pais=="SLV"
replace ppp11 =    3.8732392	if  pais=="GTM"
replace ppp11 =   10.080314	if  pais=="HND"
replace ppp11 =    8.9402123	if  pais=="MEX"
replace ppp11 =    9.1600754	if  pais=="NIC"
replace ppp11 =    0.55340803	if  pais=="PAN"
replace ppp11 = 2309.44		if  pais=="PRY"
replace ppp11 =    1.568639	if  pais=="PER"
replace ppp11 =   16.42385	if  pais=="URY"
replace ppp11 =    2.915	if  pais=="VEN"

* Ingreso per cápita familiar ajustado por IPC
gen ipcf_cpi05 = ipcf * (ipc05/ipc)
gen ipcf_cpi11 = ipcf * (ipc11/ipc)

* Ingreso per cápita familiar ajustado por PPP
gen ipcf_ppp05 = ipcf * (ipc05/ipc) * (1/ppp05)
gen ipcf_ppp11 = ipcf * (ipc11/ipc) * (1/ppp11)
   
capture drop __*
