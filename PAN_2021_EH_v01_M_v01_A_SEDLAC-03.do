/*=========================================================================
Country name:		Panama
Year:			2019
Survey:			EH
Vintage:		01M-01A
Project:		03
---------------------------------------------------------------------------
Author:			Santiago Garganta 	
			sgarganta@cedlas.org
Dependencies:		CEDLAS/UNLP -- The World Bank
Creation Date:		January, 2021
Output:			sedlac do-file template
===========================================================================*/

/*=========================================================================
                        0: Program set up
===========================================================================*/
version 10
drop _all

local country  "PAN"    // Country ISO code
local year     "2019"   // Year of the survey
local survey   "EH"     // Survey acronym
local vm       "01"     // Master version
local va       "01"     // Alternative version
local project  "03"     // Project version
local period   ""       // Periodo, ejemplo -S1 -S2
local alterna  ""       // 
local vr       "01"     // version renta
local vsp      "01"	// version ASPIRE
include "${rootdatalib}/_git_sedlac-03/_aux/sedlac_hardcode.do" 

/*=============================================================================================================================================
			1: Preparacion de los datos: Variables de Primer Orden
===============================================================================================================================================*/

/*(********************************************************************************************************************************************* 
			1.1: Abrir bases de datos  
**********************************************************************************************************************************************)*/ 

* Abre base de datos original  
local ano 2021	
use "$data\EML2021_completa", replace", clear

/*(********************************************************************************************************************************************** 
			1.2: Variables de identificacion 
***********************************************************************************************************************************************)*/

* Identificador del pais		
gen pais = "PAN"

* Identificador del año	
gen ano = 2019

* Identificador de la encuesta		
gen encuesta = "EH"

* Identificador del hogar		
rename hogar hogar_inec
sort            llave_sec hogar_inec
egen id = group(llave_sec hogar_inec)

local vars     "llave_sec hogar_inec"      
if "`vars'"!="" {
	gen hhid = ""
	local zero "0"
	
	foreach var of local vars { // vars
		tempvar str`var' actd`var' nzer`var'
		local type: type `var'
		if strpos("`type'", "str")!=0  gen `str`var'' = `var' // if string
		
		else { // if not string
			
			local i = 0
			while 1 { // exponent
				local a = 10^`i'
				local minran = 1*`a'
				local maxran = 10*`a'-1
				qui sum `var'
				if  inrange(`r(max)', `minran',`maxran') {
					local maxd `=`i'+1' // number of max digits
					continue, break
				}
				else local ++i
			}
			
			tostring `var', gen(`str`var'')  usedisplayformat `force' // if not string (usedisplay format for chl2011)
			gen `actd`var'' = strlen(`str`var'')  // actual num of digits 
			gen `nzer`var'' = `maxd'-`actd`var''  // number of zeros
			local num ""
			foreach z of numlist 1(1)`maxd' {
				local num "`zero'`num'"
				local num`z' "`num'"
				replace `str`var'' = "`num`z''"+ `str`var'' if `nzer`var'' == `z' 
			} // z loop
		} //else 
		replace hhid = hhid + `str`var''
	} // vars loop
} // if vars exist
notes hhid: original variables used were: LLAVE_SEC and HOGAR_INEC

* Identificador del componente
* NPER  Componente del hogar   
destring  nper, replace
gen com = nper

gen double pid = nper
notes pid: original variable used was: NPER

* Factor de Ponderación
gen pondera = round(fac15_e)

* Estrato
* ESTRA: estrato
destring estra, replace
gen   strata = estra

* Unidad Primaria de Muestreo
* UNIDAD: unidad primaria de muestreo
destring unidad, replace
gen   psu = unidad  


/*(*********************************************************************************************************************************************** 
			1.3: Variables demograficas
***********************************************************************************************************************************************)*/

/* Relación con el jefe de hogar
		1:  jefe		
		2:  esposo/cónyuge
		3:  hijo/hija		(hijastro/hijastra)		
		4:  padre/madre		(suegro/suegra)
		5:  otro pariente	(nieto/yerno/nuera)
		6:  no pariente										
   
   P1: Relación de parentesco
		1 = jefe
		2 = cónyuge
		3 = hijo/a (incluye adoptivos o de crianza)
		4 = otro pariente (hermanos/nietos/tios/sobrinos/abuelos/cuñados/padres/suegros)
		5 = servicio doméstico (sirvientes/conductores/cocineras/niñeras)
		6 = otros no parientes (huéspedes y sus familias)			*/
gen     relacion = 1		if  p1==1
replace relacion = 2		if  p1==2
replace relacion = 3		if  p1==3  
replace relacion = 5		if  p1==4  
replace relacion = 6		if  p1==5 | p1==6
notes   relacion: in Panama is not possible to separate relacion = 4 (padre/madre/suegro/suegra) from relacion = 5 (otro pariente)

* Estandarizada
gen     relacion_est = "1 - Household Head                   "	if  p1==1
replace relacion_est = "2 - Spouse                           "	if  p1==2
replace relacion_est = "3 - Son/Daughter, Son/Daughter in-law"	if  p1==3
replace relacion_est = "4 - Other Relatives                  "	if  p1==4
replace relacion_est = "5 - Domestic Worker                  "	if  p1==5
replace relacion_est = "6 - Other non Relatives              "	if  p1==6

* Miembros de hogares secundarios
gen	hogarsec = 0
replace hogarsec = 1		if  p1==5
notes hogarsec: domestic workers are not included as part of the household

* Identificador de hogares
gen hogar = 1			if  relacion==1

* Hogares con miembros secundarios	
tempvar aux
egen `aux' = sum(hogarsec), by(id)
gen     presec = 0
replace presec = 1		if  `aux'>0  
replace presec = .		if  relacion!=1

* Numero de miembros del hogar
tempvar uno
gen `uno' = 1
egen miembros = sum(`uno')	if  hogarsec==0 & relacion!=., by(id)

* Años cumplidos
* P3: Años cumplidos  
gen   edad = p3
notes edad: range of the variable: 0-106

* Dummy de hombre
/* P2: Sexo
	1 = hombre
	2 = mujer									*/
destring p2, replace
gen     hombre = 0		if  p2==2
replace hombre = 1		if  p2==1	

* Dummy de estado civil 1
/* P5_CONYUGA: ¿Cuál es su estado conyugal actual?
		1 = unido(a)			
		2 = separado(a) de matrimonio
		3 = separado(a) de union	
		4 = casado(a)
		5 = divorciado(a)		
		6 = viudo(a)
		7 = soltero(a)			
		8 = menor de 15 años							*/
destring p5_conyuga, replace
gen 	casado = 0		if  p5_conyuga>=1 & p5_conyuga<=8
replace casado = 1		if  p5_conyuga==1 | p5_conyuga==4

* Dummy de estado civil 2
gen 	soltero = 0		if  p5_conyuga>=1 & p5_conyuga<=8
replace soltero = 1		if  p5_conyuga==7 | p5_conyuga==8

* Estado Civil
/* 1 = married
   2 = never married
   3 = living together
   4 = divorced/separated
   5 = widowed										*/
gen     estado_civil = 1	if  p5_conyuga==4
replace estado_civil = 2	if  p5_conyuga==7 | p5_conyuga==8
replace estado_civil = 3	if  p5_conyuga==1
replace estado_civil = 4	if  p5_conyuga==2 | p5_conyuga==3 | p5_conyuga==5
replace estado_civil = 5	if  p5_conyuga==6

* Raza o etnicidad
/* P4D_INDIGE: se considera usted indígena:
                1. Kuna               2. Ngäbe
                3. Buglé              4. Naso
                5. Teribe             6. Bokota	
                7. Emberá             8. Wounaan	
                9. Bri Bri           10. Otro
               11. Ninguno

    P4F_AFROD: se considera usted:
		1. Afro-Panameño      2. Afrodescendiente
		3. Moreno             4. Negro
		5. Afro-Colonial      6. Afro-Antillano
		7. Otro               8. Ninguno                              */
destring p4d_indige, gen(p4d)
destring p4f_afrod,  gen(p4f)

gen     raza = 1	if  p4d>=1 & p4d<=10
replace raza = 2        if  p4f>=1 & p4f<=7 & raza==.
replace raza = 4        if  raza==.

gen          raza_est = p4d     if   p4d>=1 & p4d<=10
replace      raza_est = 10+p4f  if  p4d==11 & p4f>=1 & p4f<=7
replace      raza_est = 18	if  raza_est==.
label define raza_est 1 "Kuna" 2 "Ngabe" 3 "Bugle" 4 "Naso" 5 "Teribe" 6 "Bokota" 7 "Embera" 8 "Wounaan" 9 "Bri Bri" 10 "Otro Indigena" 11 "Afro-Panameno" 12 "Afrodescendiente" 13 "Moreno" 14 "Negro" 15 "Afro-Colonial" 16 "Afro-Antillano" 17 "Otro Afro" 18 "No Indigena Ni Afro"
label values raza_est raza_est

gen   lengua = .
notes lengua: there is not information on the survey to define this variable
gen   lengua_est = .


/*(*********************************************************************************************************************************************** 
			1.4: Variables regionales  
***********************************************************************************************************************************************)*/
destring prov provinci, replace

/* REGION 
	1  =  Oriental (comprende sólo la provincia de Darién)
	2  =  Metropolitana (provincias de Panamá y Colón)
	3  =  Central (provincias de Herrera, Los Santos, Coclé y Veraguas)
	4  =  Occidental (provincias de Chiriquí y Bocas de Toro)               */
gen	region_est1 = "1 - Oriental     "	if  prov==5 | prov==10 | prov==11 
replace region_est1 = "2 - Metropolitana"	if  prov==3 | prov==8 
replace region_est1 = "3 - Central      "	if  prov==2 | prov==6 | prov==7 | prov==9
replace region_est1 = "4 - Occidental   "	if  prov==1 | prov==4 | prov==12
notes   region_est1: Region
notes   region_est1: Representative

* Desagregación 2 (Provincia)
gen     region_est2 = " 1 - Bocas del Toro     "	if  provinci==1
replace region_est2 = " 2 - Cocle              "	if  provinci==2
replace region_est2 = " 3 - Colon              "	if  provinci==3
replace region_est2 = " 4 - Chiriqui           " 	if  provinci==4
replace region_est2 = " 5 - Darien             "	if  provinci==5
replace region_est2 = " 6 - Herrera            "	if  provinci==6
replace region_est2 = " 7 - Los Santos         " 	if  provinci==7
replace region_est2 = " 8 - Panama             "	if  provinci==8
replace region_est2 = " 9 - Veraguas           "	if  provinci==9
replace region_est2 = "10 - Comarca Kuna Yala  "	if  provinci==10
replace region_est2 = "11 - Comarca Embera     "	if  provinci==11
replace region_est2 = "12 - Comarca Ngobe-Bugle"	if  provinci==12
replace region_est2 = "13 - Panama-Oeste       "	if  provinci==13
notes   region_est2: Provincia
notes   region_est2: Representative (we should confirm it)

* Desagregación 3
gen	     region_est3 = .
label define region_est3 1 "" 2 ""
label values region_est3 region_est3


*************************************************************************************************************
* Desagregación 1 (Región):	
gen     region_est1_prev = region_est1
replace region_est1_prev = "."		if  prov>=10 & prov<=12
notes   region_est1_prev: Region
notes   region_est1_prev: Representative

* Desagregación 2 (Provincia)
gen     region_est2_prev = region_est2
replace region_est2_prev = "."		if  prov>=10 & prov<=12
notes   region_est2_prev: Provincia
notes   region_est2_prev: Representative (we should confirm it)

* Desagregación 3 (Comuna)
gen	region_est3_prev = .
notes   region_est3_prev: the survey does not include information on this variable

* Small Level Representative
gen     region_survey = provinci
notes   region_survey: dominios de estudio para los cuales la muestra es representativa: Nacional, Regiones y Provincias


*************************************************************************************************************

*** GAUL VARIABLES

******* GAUL 1 (Administrative: Provincia)
gen     gaul_1 = 2280		if  provinci==1
replace gaul_1 = 2281		if  provinci==4
replace gaul_1 = 2282		if  provinci==2
replace gaul_1 = 2283		if  provinci==3
replace gaul_1 = 2284		if  provinci==10
replace gaul_1 = 2285		if  provinci==5 | provinci==11
replace gaul_1 = 2286           if  provinci==6
replace gaul_1 = 2287		if  provinci==7
replace gaul_1 = 2288		if  provinci==8 | provinci==13
replace gaul_1 = 2289		if  provinci==9  
notes   gaul_1: missing values for observations belonging to Comarca Ngobe-Bugle
			
******* GAUL 2 (Administrative: ?)
gen     gaul_2 = .
			
******* GAUL 3 (Administrative: ?)
gen     gaul_3 = .

* Dummy urbano-rural
* areareco
gen  	urbano = 1		if  areareco=="U"
replace urbano = 0		if  areareco=="R" 

* Dummies regionales 
* Oriental
gen     oriental = 1		if  prov==5 | prov==10 | prov==11
replace oriental = 0		if  oriental==.
notes   oriental: Dummy Region Oriental

* Metropolitana
gen     metro = 1		if  prov==3 | prov==8 
replace metro = 0		if  metro==.
notes   metro: Dummy Region Metropolitana

* Central
gen     central = 1		if  prov==2 | prov==6 | prov==7 | prov==9
replace central = 0		if  central==.
notes   central: Dummy Region Central

* Oriental
gen     occidental = 1		if  prov==1 | prov==4 | prov==12
replace occidental = 0		if  occidental==.
notes   occidental: Dummy Region Occidental

* Areas no incluidas en años previos
gen     nuevareg = 1		if  prov>=1 & prov<=9
replace nuevareg = 2		if  prov>=10 & prov<=12


****************************************************************************************************************************************************
* Migrante
* P6_RESIDIA: dónde residía en agosto del año pasado?
destring p6_residia, replace
gen 	migrante = 0		if  p6_residia==14
replace migrante = 1		if (p6_residia>=1 & p6_residia<=13) | (p6_residia>=105 & p6_residia<=568) 
notes migrante: there is not information of the place of birth
notes migrante: this variable is based on information about the province or country where the individual lived a year ago

* Migrantes extranjeros
gen     migra_ext = 0		if    (p6_residia>=1  & p6_residia<=13) & migrante==1
replace migra_ext = 1		if  (p6_residia>=105 & p6_residia<=546) & migrante==1

* Migrantes internos (urbano-rural)
gen   migra_rur = .
notes migra_rur: the survey does not include information on this variable

* Años de residencia del migrante:
gen   anios_residencia = .
notes anios_residencia: the survey does not include information on this variable

* Migrante reciente
gen   migra_rec = .
notes migra_rec: the survey does not include information on this variable


/*(************************************************************************************************************************************************ 
			1.5: Vivienda e infraestructura  
*************************************************************************************************************************************************)*/

* Propiedad de la vivienda
/* V1: ¿La vivienda que habita este hogar es?
		1 = Alquilada	
		2 = Hipotecada
		3 = Propia	
		4 = Cedida
		5 = Condenada	
		6 = Otra								*/
destring v1_tenen, gen(v1)
gen	propieta = 1	if  v1==2 | v1==3
replace propieta = 0	if  v1==1 | v1==4 | v1==5 | v1==6
replace propieta = .	if  relacion!=1

* Habitaciones, contando baño y cocina
gen   habita = .
notes habita: the survey does not include information on this variable

* Dormitorios de uso exclusivo
gen   dormi = .
notes dormi: the survey does not include information on this variable

* Vivienda en lugar precario
gen   precaria = .
notes precaria: the survey does not include information on this variable

* Material de construcción precario
gen   matpreca = .
notes matpreca: the survey does not include information on this variable

* Instalacion de agua corriente
gen   agua = .
notes agua: the survey does not include information on this variable

* Improved Water Recommended
gen   imp_wat_rec = .
notes imp_wat_rec: the survey does not include information on this variable

* Improved Water Underestimate
gen   imp_wat_underest = .
notes imp_wat_underest: the survey does not include information on this variable

* Improved Water Overestimate
gen   imp_wat_overest = .
notes imp_wat_overest: the survey does not include information on this variable

* All piped classification
gen   piped = . 
notes piped: the survey does not include information on this variable

* Piped to premises classification 
gen   piped_to_prem = .
notes piped_to_prem: the survey does not include information on this variable

* Water Source
gen   water_source = .
notes water_source: the survey does not include information on this variable
	
* Water Original
gen   water_original = ""	
notes water_original: the survey does not include information on this variable

label var      imp_wat_rec "Access to improved drinking water-MPI & WGP - Recommended"
label var imp_wat_underest "Access to improved drinking water-MPI & WGP - Underestimate"
label var  imp_wat_overest "Access to improved drinking water-MPI & WGP - Overestimate"
label var            piped "Access to piped water"
label var    piped_to_prem "Piped water to premises"
label var     water_source "Source of drinking water"
label var   water_original "Original water variable"

* Banio
gen   banio = .
notes banio: the survey does not include information on this variable

* Cloacas
gen   cloacas = .
notes cloacas: the survey does not include information on this variable

* Improved Sanitation Recommended
gen   imp_san_rec = .
notes imp_san_rec: the survey does not include information on this variable

* Improved Sanitation Underestimate
gen   imp_san_underest = .
notes imp_san_underest: the survey does not include information on this variable

* Improved Sanitation Overestimate
gen   imp_san_overest = .
notes imp_san_overest: the survey does not include information on this variable

* SEWER
gen   sewer = .
notes sewer: the survey does not include information on this variable

* OPEN DEFECATION
gen   open_def = .
notes open_def: the survey does not include information on this variable

* Sanitation Source
gen   sanitation_source = .
notes sanitation_source: the survey does not include information on this variable

* Sanitation Original
gen   sanitation_original = ""	
notes sanitation_original: the survey does not include information on this variable

label var         imp_san_rec "Access to improved sanitation facilities - Recommended"
label var    imp_san_underest "Access to improved sanitation facilities - Underestimate"
label var     imp_san_overest "Access to improved sanitation facilities - Overestimate"
label var               sewer "Access to toilet facility with sewer connection"
label var            open_def "Open defecation"
label var   sanitation_source "Source of sanitation"
label var sanitation_original "Original sanitation variable"

* Electricidad en la vivienda
gen   elect = .
notes elect: the survey does not include information on this variable

* Teléfono
gen   telef = .
notes telef: the survey does not include information on this variable


* Types of Dwelling
/*	 1 = Detached house
	 2 = Multi-family house
	 3 = Separate apartment 
	 4 = Communal apartment 
	 5 = Room in a larger dwelling 
	 6 = Several buildings connected 
	 7 = Several separate buildings 
	 8 = Improvised housing unit 
	99 = Other									*/
gen   dweltyp = .
notes dweltyp: the survey does not include information on this topic

* Techo
/*	 1 = Adobe, zarzo, lodo
	 2 = Paja
	 3 = Madera
	 4 = Hierro/Láminas de metal
	 5 = Cemento
	 6 = Mosaicos/Ladrillos                    
	 7 = Asbesto
	99 = Other									*/
gen   techo = .
notes techo: the survey does not include information on this topic

* Pared
/*	 1 = Adobe, zarzo, lodo                      
	 2 = Paja
	 3 = Madera
	 4 = Hierro/Láminas de metal
	 5 = Cemento                                      
	 6 = Ladrillos                                        
	 7 = Asbesto
	99 = Other									*/
gen   pared = .
notes pared: the survey does not include information on this topic

* Piso
/*	 1 = Tierra
	 3 = Madera
	 4 = Madera pulida/mosaicos
	 5 = Cemento                                      
	 6 = Ladrillos
	 7 = Asbesto
	99 = Other									*/
gen   piso = .
notes piso: the survey does not include information on this topic

* Kitchen (yes/no)
gen   kitchen = .
notes kitchen: the survey does not include information on this topic

* Bath (yes/no)
gen   bath = .
notes bath: the survey does not include information on this topic

* Rooms
gen   rooms = .
notes rooms: the survey does not include information on this topic

* Acquisition of House 
/*	 1 = Comprada – totalmente pagada
	 2 = Comprada - pagando
	 3 = Heredada
	 4 = Alquilada/rentada
	 5 = Regalada/cedida
	 6 = Recibida por servicios de trabajo
	99 = Other									

  V1: ¿La vivienda que habita este hogar es?
		1 = Alquilada	
		2 = Hipotecada
		3 = Propia	
		4 = Cedida
		5 = Condenada	
		6 = Otra								*/
gen     adq_house = .
replace adq_house = 1		if  v1==3 
replace adq_house = 2		if  v1==2 
replace adq_house = 4		if  v1==1 
replace adq_house = 5		if  v1==4 
replace adq_house = 99		if  v1==6 | v1==5
notes   adq_house: other includes "condenada" and "otra"
notes   adq_house: it is not possible to identify who are the ones who inherited the house

* Acquisition of Residential Land 
/*	 1 = Comprada – totalmente pagada
	 2 = Comprada - pagando
	 3 = Heredada
	 4 = Alquilada/rentada
	 5 = Regalada/cedida
	 6 = Recibida por servicios de trabajo
	99 = Other									*/
gen   adq_land = .
notes adq_land: the survey does not include information on this topic

* Legal Title of Ownership
gen   dwelownlti = .
notes dwelownlti: the survey does not include information on this topic

* Legal Title of Ownership - Female
gen   fem_dwelownlti = .
notes fem_dwelownlti: the survey does not include information on this topic

* Type of ownership title
gen   dwelownti	= .
notes dwelownti: the survey does not include information on this topic

* Right to sell dwelling
gen   selldwel = .
notes selldwel: the survey does not include information on this topic	

* Right to transfer dwelling
gen   transdwel = .
notes transdwel: the survey does not include information on this topic	

* Ownership of land
gen   ownland = .
notes ownland: the survey does not include information on this topic

* Legal documentation for residential land
gen   doculand = .
notes doculand: the survey does not include information on this topic

* Legal documentation for residential land - Female
gen   fem_doculand = .
notes fem_doculand: the survey does not include information on this topic	

* Land ownership
gen   landownti = .
notes landownti: the survey does not include information on this topic

* Right to sell land
gen   selland = .
notes selland: the survey does not include information on this topic

* Right to transfer land
gen   transland = .
notes transland: the survey does not include information on this topic

* Types of living quarters
gen   typlivqrt = .
notes typlivqrt: the survey does not include information on this topic	

* Year the dwelling was built
gen   ybuilt = .
notes ybuilt: the survey does not include information on this topic

* Area (square meters)
gen   areaspace = .
notes areaspace: the survey does not include information on this topic

* Main Types of Solid Waste Disposal
/*	 1 = Solid waste collected on a regular basis by authorized collectors
	 2 = Solid waste collected on an irregular basis by authorized collectors
	 3 = Solid waste collected by self-appointed collectors
	 4 = Occupants dispose of solid waste in a local dump supervised by authorities
	 5 = Occupants dispose of solid waste in a local dump not supervised by authorities
	 6 = Occupants burn solid waste
	 7 = Occupants bury solid waste
	 8 = Occupants dispose solid waste into river, sea, creek, pond
	 9 = Occupants compost solid waste
	10 = Other arrangement								*/
gen   waste = .
notes waste: the survey does not include information on this topic 

* Connection to Gas
/*	0 = No 
	1 = Yes, piped gas (LNG)
	2 = Yes, bottled gas (LPG)
	3 = Yes, but don't know or other						*/
gen   gas = .
notes gas: the survey does not include information on this topic 

* Main Cooking Fuel
/*	1 = Firewood
	2 = Kerosene
	3 = Charcoal
	4 = Electricity
	5 = Gas
	9 = Other									*/
gen   cooksource = .
notes cooksource: the survey does not include information on this topic

* Main Source of Lighting
/*	1 = Electricity 
	2 = Kerosene
	3 = Candles
	4 = Gas
	9 = Other									*/
gen   lightsource = .
notes lightsource: the survey does not include information on this topic 

* Connection to Electricity
/*	1 = Yes, public/quasi public
	2 = Yes, private 
	3 = Yes, source unstated
	4 = No										*/
gen   elec_acc = .
notes elec_acc: the survey does not include information on this topic 

* Electricity Availability
gen   elechr_acc = .
notes elechr_acc: the survey does not include information on this topic 

* Type of Lightning/Electricity
/*	1 = Electricity 
	2 = Gas 
	3 = Lamp
	4 = Others									*/
gen   electyp = .
notes electyp: the survey does not include information on this topic 


/*(*************************************************************************************************************************************************
			1.6: Bienes durables y servicios 
*************************************************************************************************************************************************)*/

* Heladera (con o sin freezer)
gen   heladera = .
notes heladera: the survey does not include information on this variable

* Lavarropas
gen   lavarropas = .
notes lavarropas: the survey does not include information on this variable

* Aire acondicionado
gen   aire = .
notes aire: the survey does not include information on this variable

* Calefacción fija
gen   calefaccion_fija = .
notes calefaccion_fija: the survey does not include information on this variable

* Teléfono fijo
gen   telefono_fijo = .
notes telefono_fijo: the survey does not include information on this variable

* Teléfono móvil (hogar)
gen   celular = .	
notes celular: the survey does not include information on this variable

* Teléfono movil (individual)
gen   celular_ind = .
notes celular_ind: the survey does not include information on this variable

* Televisor
gen   televisor = .
notes televisor: the survey does not include information on this variable

* TV por cable o satelital
gen   tv_cable = .   
notes tv_cable: the survey does not include information on this variable

* VCR o DVD
gen   video = .
notes video: the survey does not include information on this variable

* Computadora
gen   computadora = .
notes computadora: the survey does not include information on this variable

* Conexión a Internet en la casa
gen   internet_casa = .
notes internet_casa: the survey does not include information on this variable

* Uso de Internet
gen   uso_internet = .
notes uso_internet: the survey does not include information on this variable

* Auto 
gen   auto = .   
notes auto: the survey does not include information on this variable

* Antiguedad del auto (en años)
gen   ant_auto = .
notes ant_auto: the survey does not include information on this variable

* Auto nuevo (5 o menos años)
gen   auto_nuevo = .
notes auto_nuevo: the survey does not include information on this variable

* Moto
gen   moto = .
notes moto: the survey does not include information on this variable

* Bicicleta
gen   bici = .
notes bici: the survey does not include information on this variable

* Sewing Machine
gen   sewmach = .
notes sewmach: the survey does not include information on this topic

* Stove or Cooker
gen   stove = .
notes stove: the survey does not include information on this topic

* Rice Cooker
gen   ricecook = .
notes ricecook: the survey does not include information on this topic

* Fan
gen   fan = .
notes fan: the survey does not include information on this topic

* Electronic Tablet
gen   etablet = .
notes etablet: the survey does not include information on this topic

* Electric Water Pump
gen   ewpump = .
notes ewpump: the survey does not include information on this topic

* Animal Cart/Oxcart
gen   oxcart = .
notes oxcart: the survey does not include information on this topic

* Boat
gen   boat = .
notes boat: the survey does not include information on this topic

* Canoes
gen   canoe = .
notes canoe: the survey does not include information on this topic


/*(**********************************************************************************************************************************************
			1.7: Variables educativas 
**********************************************************************************************************************************************)*/

* Alfabeto
/* P8: ¿Que nivel y que grado o año escolar más alto aprobó?   
	 0 = no aplicable (menores de 4 años)
	 1 = ningún grado 			 2 = preescolar 
	 3 = kinder				 4 = enseñanza especial			
	1_ = primaria				2_ = vocacional
	3_ = secundaria				4_ = Superior no universitaria
	5_ = Superior universitaria		6_ = Especialidad (postgrado)
	7_ = Maestria				8_ = Doctorado				*/
gen	alfabeto = 0	if  p8==1 | p8==2 | p8==11 
replace alfabeto = 1	if  p8>=12 & p8<=84
notes   alfabeto: variable defined for individuals 4-years-old and older
notes   alfabeto: special education is not included

* Asiste a la educación formal
* P7: Asiste a la escuela actualmente
gen	asiste = 0	if  p7==2  
replace asiste = 1	if  p7==1
notes   asiste: variable defined for individuals 4-years-old and older

* Establecimiento educativo público
/* P7_TIPO: Tipo de escuela a la que asiste
		3 = Pública (Oficial)
		4 = Privada (Particular)						*/
destring p7_tipo, replace
gen     edu_pub = 0	if  asiste==1 & p7_tipo==4
replace edu_pub = 1	if  asiste==1 & p7_tipo==3

* Educación en años
/* P8: ¿Que nivel y que grado o año escolar más alto aprobó?   
	 0 = no aplicable (menores de 4 años)
	 1 = ningún grado 			 2 = preescolar 
	 3 = kinder				 4 = enseñanza especial			
	1_ = primaria				2_ = vocacional
	3_ = secundaria				4_ = Superior no universitaria
	5_ = Superior universitaria		6_ = Especialidad (postgrado)
	7_ = Maestria				8_ = Doctorado				*/
gen	aedu = .            
replace aedu = 0	if  p8==1 | p8==2 | p8==3 
replace aedu = 1	if  p8==11 
replace aedu = 2	if  p8==12 
replace aedu = 3	if  p8==13 
replace aedu = 4	if  p8==14 
replace aedu = 5	if  p8==15 
replace aedu = 6	if  p8==16 
replace aedu = 7	if  p8==31 | p8==21
replace aedu = 8	if  p8==32 | p8==22
replace aedu = 9	if  p8==33 | p8==23
replace aedu = 10	if  p8==34 
replace aedu = 11	if  p8==35
replace aedu = 12	if  p8==36
replace aedu = 13	if  p8==51 | p8==41
replace aedu = 14	if  p8==52 | p8==42 
replace aedu = 15	if  p8==53 | p8==43
replace aedu = 16	if  p8==54 | p8==44 | p8==45 | p8==46
replace aedu = 17	if  p8==55 | p8==61
replace aedu = 18	if  p8==56 | p8==62 | p8==71
replace aedu = 19	if  p8==57 | p8==58 | p8==63 | p8==72 | p8==81 
replace aedu = 20	if  p8==82 | p8==64 | p8==65 | p8==66 | p8==73 | p8==74
replace aedu = 21	if  p8==83
replace aedu = 22	if  p8==84
notes   aedu: variable defined for individuals 4-years-old and older
notes   aedu: special education is not included

* Nivel educativo
/*   0 = nunca asistió        1 = primario incompleto
     2 = primario completo    3 = secundario incompleto
     4 = secundario completo  5 = superior incompleto 
     6 = superior completo								*/
gen	nivel = 0	if  p8==1 | p8==2 | p8==3
replace nivel = 1	if  p8>=11 & p8<16
replace nivel = 2	if  p8==16
replace nivel = 3	if  p8>=31 & p8<36  
replace nivel = 3	if  p8>=21 & p8<23
replace nivel = 4	if  p8==36 
replace nivel = 4	if  p8==23
replace nivel = 5	if  p8>=51 & p8<=54
replace nivel = 5	if  p8>=55 & p8<60  & p7==1
replace nivel = 5	if  p8>=41 & p8<43
replace nivel = 5	if  p8>=43 & p8<=46 & p7==1
replace nivel = 6	if  p8>=43 & p8<=46 & p7==2
replace nivel = 6	if  p8>=55 & p8<60  & p7==2
replace nivel = 6	if  p8>=61 & p8<=84 
notes   nivel: variable defined for individuals 4-years-old and older
notes   nivel: special education is not included

 
/*(**********************************************************************************************************************************************
			1.8: Variables Salud 
**********************************************************************************************************************************************)*/

* Seguro de salud
/* P4: ¿TIENE USTED ACTUALMENTE SEGURO SOCIAL COMO:... 
		1 = Asegurado(a) directo(a)?
		2 = Beneficiario(a)?
		3 = Jubilado(a)?
		4 = Pensionado(a)?
		5 = Jubilado(a) o Pensionado(a) de otro país?
		6 = No tiene?								*/
gen     seguro_salud = 1	if  p4>=1 & p4<=5
replace seguro_salud = 0	if  p4==6

* Tipo de seguro de salud:		tipo_seguro
gen   tipo_seguro = .
notes tipo_seguro: the survey does not include information on this topic

* Estuvo enfermo en últimas 4 semanas?:	enfermo 
gen   enfermo = . 
notes enfermo: the survey does not include information on this topic

* Visitó médico en últimas 4 semanas?:	visita 
gen   visita = . 
notes visita: the survey does not include information on this topic


/*(********************************************************************************************************************************************* 
			1.9: Variables laborales 
*********************************************************************************************************************************************)*/

* Ocupado
/* P10_18: Condición de actividad    
		 1,2,3,4,5,8 = ocupado
		       6,7,9 = desocupado
     10,11,12,13,14,15,16,17 = inactivo							
     
   P27A_COND: Definición oficial de condición actividad (no coincide 100% con la nuestra) */
gen	ocupado = 0	if  p10_18>=1 & p10_18<=17
replace ocupado = 1	if (p10_18>=1 & p10_18<=5) | p10_18==8
notes   ocupado: people aged 10 and older
notes   ocupado: period of reference: last week

* Desocupado
gen	desocupa = 0	if  p10_18>=1 & p10_18<=17
replace desocupa = 1	if  p10_18==6 | p10_18==7 | p10_18==9
notes   desocupa: people aged 10 and older
notes   desocupa: period of reference: last week

* Población económicamente activa
rename  pea pea_encuesta
gen	pea = 0		if  ocupado==0 & desocupa==0
replace pea = 1		if  ocupado==1 | desocupa==1
notes   pea: people aged 10 and older
notes   pea: period of reference: last week

/* Razon por la que no pertenece a la fuerza de trabajo
	 1 = Student					 2 = Housekeeping
	 3 = Retired					 4 = Disabled 
	 5 = Waiting for the work season		 6 = Do not have the economic means 
	 7 = Do not have the legal means / Illegal	 8 = Too old/young to work
	 9 = Do not have the need to work		10 = Forbidden by a family member
	11 = Illness					12 = Exhausted to be looking for a job
	13 = Believe none will give him/her a job       14 = Wages are too low
	99 = Other									
   P10_18:
		10. Se canso de buscar trabajo
		11. Jubilado
		12. Pensionado
		13. Estudiante
		14. Ama de casa o trabajador del hogar
		15. Incapacitado permanente para trabajar
		16. Edad avanzada
		17. Otros inactivos
      P20: Porque no estuvo buscando ni piensa buscar trabajo?
		 1. Cree que no existe trabajo de su especialidad en el lugar donde vive
		 2. No puede encontrar trabajo
		 3. Carece de formacion, calificacion o experiencia necesaria
		 4. Los empleadores lo consideran demasiado joven o demasiado viejo
		 5. No tiene quien se ocupe de los niños
		 6. Otras responsabilidades familiares
		 7. Asiste a un centro de enseñanza
		 8. Cree que la edad es un impedimento para conseguir trabajo
		 9. Mala salud
	        10. Embarazo
	        11. No desea trabajar
	        12. Jubilado o pensionado
		13. Otro
		14. No sabe								*/
gen     nfl = .
replace nfl = 1         if  p10_18==13
replace nfl = 2         if  p10_18==14
replace nfl = 3         if  p10_18==11 | p10_18==12
replace nfl = 4         if  p10_18==15
replace nfl = 8         if  p10_18==16
replace nfl = 12	if  p10_18==10
replace nfl = 99        if  p10_18==17
replace nfl = .		if  pea!=0
replace nfl = 1		if  p20==7
replace nfl = 2		if  p20==5 | p20==6
replace nfl = 3		if  p20==12
replace nfl = 8		if  p20==4 | p20==8
replace nfl = 9		if  p20==11
replace nfl = 11	if  p20==9 | p20==10
replace nfl = 12	if  p20==2
replace nfl = 13	if  p20==3 | p20==1
replace nfl = 99	if  p20==13 | p20==14

* Numero Total de Trabajos
/* P44: Tuvo algun otro trabajo la semana pasada, como independiente o asalariado en: 
		1. Actividades agropecuarias, silvicultura y pesca?
		2. Actividades no agropecuarias? 
		3. No tuvo otro trabajo?						*/
gen     njobs = .
replace njobs = 1	if  ocupado==1
replace njobs = 2	if  ocupado==1 & (p44==1 | p44==2)

* Edad mínima de preguntas laborales
gen   edad_min = 10
notes edad_min: people aged 10 and older answer the labor module

* Duración del desempleo (en meses)
* P21: Cuánto tiempo hace que esta buscando trabajo(meses) 
gen	durades = p21	        if  p21<299
replace durades = durades-100	if  durades==100
replace durades = durades-200	if  durades>=200 
replace durades = .		if  desocupa!=1

* Horas en el trabajo principal
* P43:  Total horas trabajadas en ocupacion principal
* P48:  Horas trabajadas en la ocupacion secundaria en la semana de referencia 
gen	hstrp = p43
replace hstrp = .	if  hstrp<=0
replace hstrp = .	if  hstrp>150
replace hstrp = .	if  ocupado!=1

destring p48, replace
gen	hstrs = p48
replace hstrs = .	if  hstrs<=0
replace hstrs = .	if  ocupado!=1

* Horas en todos los empleos
egen	hstrt = rsum(hstrp hstrs), missing 
replace hstrt = .	if  hstrt>150
replace hstrt = .	if  ocupado!=1

* Deseo otro trabajo o más horas
* P50:  Deseaba trabajar mas horas de las que trabajó la semana pasada? 
* P53:  Buscó trabajo adicional o pudo haber trabajado más horas durante la semana pasada? 
gen	deseo_emp = 1	if  p50==1 | p53==1
replace deseo_emp = 0	if  p50==2 & p53==2
replace deseo_emp = .	if  ocupado!=1

* Antiguedad en el trabajo (años)
* P40: ¿Qué tiempo tiene de trabajar en ese negocio, empresa o institución? 
destring p40, replace
gen	aux1 = p40
replace aux1 = .		if  p40==999 | p40==0
gen	p40m = aux1-100		if  aux1<200
gen	p40a = aux1-200		if  aux1>=200 & aux1!=.
replace p40a = .		if (p40a>edad & p40a!=.) | p40a<0
replace p40m = .		if  p40m>12 | p40m<0

gen	antigue = p40a
replace antigue = p40m/12	if  aux1<200
replace antigue = .		if  ocupado!=1
drop aux1 p40m p40a 

* Relacion laboral
/*		1 = empleador (patron)
		2 = empleado asalariado
		3 = independiente (cuentapropista)
		4 = sin salario
		5 = desocupado							

 P33: Donde usted trabaja o trabajó por última vez lo hizo como 
		 1 = empleado del gobierno 
		 2 = empleado de una organización sin fines de lucro 
		 3 = empleado de una cooperativa
		 4 = empleado de empresa privada 
		 5 = empleado del servicio doméstico  
		 6 = empleado de la comisión del Canal o sitios de defensa
		 7 = por cuenta propia 
		 8 = patrono (dueño) 
		 9 = miembro de una cooperativa de producción 
		10 = trabajador familiar					*/  
gen	relab = 1	if  p33==8
replace relab = 2	if  p33>=1 & p33<=6
replace relab = 3	if  p33==7 | p33==9
replace relab = 4	if  p33==10 
replace relab = .	if  ocupado!=1
replace relab = 5	if  desocupa==1

/* P46A: TRABAJÓ LA SEMANA PASADA EN SU OTRO TRABAJO COMO... 
		 1 = empleado del gobierno 
		 2 = empleado de una organización sin fines de lucro 
		 3 = empleado de una cooperativa
		 4 = empleado de empresa privada 
		 5 = empleado del servicio doméstico  
		 6 = empleado de la comisión del Canal o sitios de defensa
		 7 = por cuenta propia 
		 8 = patrono (dueño) 
		 9 = miembro de una cooperativa de producción 
		10 = trabajador familiar					*/  
destring p46a, replace
gen	relab_s = 1	if  p46a==8 
replace relab_s = 2	if  p46a>=1 & p46a<=6
replace relab_s = 3	if  p46a==7 | p46a==9
replace relab_s = 4	if  p46a==10 
replace relab_s = .	if  njobs!=2
replace relab_s = 5	if  desocupa==1 

gen   relab_o = .
notes relab_o: the survey does not include information on this variable

* Sector of Activity
/*	1 = Public Sector, Central Government, Army
	2 = Private, NGO
	3 = State Owned 
	4 = Public or State-owned, but cannot distinguish				*/
* Main Job
gen     occusec = .
replace occusec = 1	if  p33==1
replace occusec = 2	if (p33>=2 & p33<5) | (p33>=7 & p33<=10)
replace occusec = 3	if  p33==6
*eplace occusec = 4	if
replace occusec = .	if  ocupado!=1

* Secondary Job
gen     occusec_s = .
replace occusec_s = 1	if  p46a==1
replace occusec_s = 2	if (p46a>=2 & p46a<5) | (p46a>=7 & p46a<=10)
replace occusec_s = 3	if  p46a==6
*eplace occusec_s = 4	if
replace occusec_s = .	if  ocupado!=1

* Other Job
gen     occusec_o = .
notes   occusec_o: the survey does not include information on this topic

* Tipo de empresa
*	1 = Grande			(+ de 5 empleados)
*	2 = Chica			(5 o menos empleados)
*	3 = Estatal o sector publico
/* P31: Cuantas personas trabajan en el establecimiento, empresa o institución donde usted trabaja o trabajó
		1 = menos de 5 
		2 = 5-10 
		3 = 11-19 
		4 = 20-49 
		5 = 50 y más										*/
gen	empresa = 1	if  p31==2 | p31==3 | p31==4 | p31==5
replace empresa = 2	if  p31==1
replace empresa = 3	if  p33==1 
replace empresa = .	if  ocupado!=1 
notes   empresa: defined for all employed individuals (2 missing observations)

** Firm size (lower bracket)
* Main Job
gen     firmsize_l = .
replace firmsize_l = 1		if  p31==1
replace firmsize_l = 5		if  p31==2
replace firmsize_l = 11		if  p31==3
replace firmsize_l = 20		if  p31==4
replace firmsize_l = 50		if  p31==5
replace firmsize_l = .		if  ocupado!=1

* Secondary Job
gen     firmsize_l_s = .
notes   firmsize_l_s: the survey does not include information on this topic

* Other Job
gen     firmsize_l_o = .
notes   firmsize_l_o: the survey does not include information on this topic
 
** Firm size (upper bracket)
* Main Job
gen     firmsize_u = .
replace firmsize_u = 4		if  p31==1
replace firmsize_u = 10		if  p31==2
replace firmsize_u = 19		if  p31==3
replace firmsize_u = 49		if  p31==4
replace firmsize_u = .		if  p31==5
replace firmsize_u = .		if  ocupado!=1

* Secondary Job
gen     firmsize_u_s = .
notes   firmsize_u_s: the survey does not include information on this topic

* Other Job
gen     firmsize_u_o = .
notes   firmsize_u_o: the survey does not include information on this topic

* Sector de actividad:			sector1d
/* P30RECO: Clasificación Industrial Nacional Uniforme (CINU), elaborada con base en la (CIIU)
	1. Agricultura, ganadería, caza, silvicultura, pesca y actividades de servicio conexas
	2. Explotación de minas y canteras
	3. Industria Manufacturera
	4. Suministro de electricidad, gas, vapor y aire acondicionado 
	5. Suministro de Agua, alcantarillado, gestión de desechos y actividades de saneamiento
	6. Construccion 
	7. Comercio al por mayor y al por menor (incluye zonas francas), reparacion de vehiculos de motor y motocicletas
	8. Transporte, Almacenamiento y correo
	9. Hoteles y restaurantes 
	10. Información y comunicación
	11. Actividades financieras y de seguros
	12. Actividades inmobiliarias
	13. Actividades profesionales, cientificas y tecnicas
	14. Actividades Adm. y Ss de Apoyo
	15. Adm. Pública y Defensa. Planes de seguridad social de Afiliacion obligatoria
	16. Enseñanza
	17. Ss. Sociales y relacionados con la salud humana
	18. Artes, Entretenimiento y Creatividad
	19. Otras Actividades de Servicios
	20. Actividades de los hogares en calidad de empleadores. Actividades indiferenciadas de produccion de bienes y servicios de los hogares para uso propio
	21. Actividades de organizaciones y organos extraterritoriales y actividades no declaradas

sector1d = 1       A -  Agricultura, ganadería, caza y silvicultura 
sector1d = 2       B -  Pesca 
sector1d = 3       C -  Explotación de minas y canteras 
sector1d = 4       D -  Industrias manufactureras 
sector1d = 5       E -  Suministro de electricidad, gas y agua 
sector1d = 6       F -  Construcción 
sector1d = 7       G -  Comercio al por mayor y menor; reparación de vehículos automotores, motocicletas, efectos personales y enseres domésticos 
sector1d = 8       H -  Hoteles y restaurantes 
sector1d = 9       I -  Transporte, almacenamiento y comunicaciones 
sector1d = 10      J -  Intermediación financiera 
sector1d = 11      K -  Actividades inmobiliarias, empresariales y de alquiler 
sector1d = 12      L -  Administración publica y defensa; planes de seguridad social de afiliación  obligatoria 
sector1d = 13      M -  Enseñanza 
sector1d = 14      N -  Servicios sociales y de salud 
sector1d = 15      O -  Otras actividades de servicios comunitarios, sociales y personales 
sector1d = 16      P -  Hogares privados con servicio doméstico 
sector1d = 17      Q -  Organizaciones y órganos extraterritoriales 

En esta encuesta no se puede identificar el sector1d==2 porque la clasificación de ocupaciones está a un dígito			*/

* Sector de actividad a un dígito del CIIU
destring p30reco, gen(rama) 

gen	sector1d = .
replace sector1d = 1	if  rama==1
*eplace sector1d = 2	if  rama==1 
replace sector1d = 3	if  rama==2 
replace sector1d = 4	if  rama==3
replace sector1d = 5	if  rama==4 | rama==5
replace sector1d = 6	if  rama==6
replace sector1d = 7	if  rama==7
replace sector1d = 8	if  rama==9
replace sector1d = 9	if  rama==8 | rama==10
replace sector1d = 10	if  rama==11
replace sector1d = 11	if  rama==12 | rama==13 | rama==14
replace sector1d = 12	if  rama==15
replace sector1d = 13	if  rama==16
replace sector1d = 14	if  rama==17
replace sector1d = 15	if  rama==18 | rama==19
replace sector1d = 16	if  rama==20
replace sector1d = 17	if  rama==21
replace sector1d = .	if  ocupado!=1
notes sector1d: it is not possible to distinguish workers from fishing sector (sector1d==2) from workers on other primary activities. They are included in sector1d==1

* Secondary Job
destring p46reco, gen(ramasec) 

gen	sector1d_s = .
replace sector1d_s = 1	if  ramasec==1
replace sector1d_s = 3	if  ramasec==2 
replace sector1d_s = 4	if  ramasec==3
replace sector1d_s = 5	if  ramasec==4 | ramasec==5
replace sector1d_s = 6	if  ramasec==6
replace sector1d_s = 7	if  ramasec==7
replace sector1d_s = 8	if  ramasec==9
replace sector1d_s = 9	if  ramasec==8 | ramasec==10
replace sector1d_s = 10	if  ramasec==11
replace sector1d_s = 11	if  ramasec==12 | ramasec==13 | ramasec==14
replace sector1d_s = 12	if  ramasec==15
replace sector1d_s = 13	if  ramasec==16
replace sector1d_s = 14	if  ramasec==17
replace sector1d_s = 15	if  ramasec==18 | ramasec==19
replace sector1d_s = 16	if  ramasec==20
replace sector1d_s = 17	if  ramasec==21
replace sector1d_s = .	if  ocupado!=1

* Other Job
gen   sector1d_o = .
notes sector1d_o: the survey does not include information on this topic


* Country-Specific Industry Codes
* Main Job
gen   sector_orig = p30reco

* Secondary Job
gen   sector_orig_s = p46reco
notes sector_orig_s: the survey does not include information on this topic

* Other Job
gen   sector_orig_o = .
notes sector_orig_o: the survey does not include information on this topic

/* Sector de actividad (clasificacion propia)
1 = agricola, actividades primarias
2 = industrias de baja tecnologia (industria alimenticia, bebidas y tabaco, textiles y confecciones) 
3 = resto de industria manufacturera
4 = construccion
5 = comercio minorista y mayorista, restaurants, hoteles, reparaciones
6 = electricidad, gas, agua, transporte, comunicaciones
7 = bancos, finanzas, seguros, servicios profesionales
8 = administracion publica y defensa
9 = educacion, salud, servicios personales 
10 = servicio domestico 

En 2014 Se utilizó también la clasificación nacional de ocupaciones a 3 dígitos (p28_3dig=rama_ocup) para 
distinguir industria de baja tecnología y el resto de industria manufacturera. 
En esta encuesta no se puede identificar industria de baja tecnología porque la clasificación de ocupaciones está a un dígito		*/
gen     sector = 1	if  sector1d>=1 & sector1d<=3
replace sector = 3	if  sector1d==4
replace sector = 4	if  sector1d==6
replace sector = 5	if  sector1d==7  |  sector1d==8
replace sector = 6	if  sector1d==5  |  sector1d==9
replace sector = 7	if  sector1d==10 | sector1d==11
replace sector = 8	if  sector1d==12 | sector1d==17 
replace sector = 9	if  sector1d>=13 & sector1d<=15
replace sector = 10	if  sector1d==16 
replace sector = .	if  ocupado!=1
notes sector: It is not possible to distinguish high-tech (sector==3) and low-tech (sector==2) industries. All workers in manufacturing industries are included in sector==3

* Ocupación realiza
* P28: ¿Qué ocupación, oficio o trabajo realizó la semana pasada o la última vez que trabajó? 
destring p28reco, gen(oficio_prim)
destring p45reco, gen(oficio_secu)

gen	tarea = oficio_prim
replace tarea = . if ocupado!=1

* Occupational Classification
/*	 1 = Managers 
	 2 = Professionals 
	 3 = Technicians and associate professionals 
	 4 = Clerical support workers 
	 5 = Service and sales workers 
	 6 = Skilled agricultural, forestry and fishery workers
	 7 = Craft and related trades workers
	 8 = Plant and machine operators, and assemblers 
	 9 = Elementary occupations 
	10 = Armed forces occupations 
	99 = Other/unspecified								
  
  OFICIO_PRIM/SECU: Cual es su ocupación u oficio?
	1 = Miembros del Poder Ejecutivo y de los Cuerpos Legislativos
	2 = Profesionales, Científicos e Intelectuales
	3 = Técnicos Profesionales de Nivel Medio
	4 = Empleados de Oficina
	5 = Trabajadores de los Servicios y Vendedores de Comercios
	6 = Agricultores y Trabajadores Calificados Agropecuarios y Pesqueros
	7 = Oficiales, Operarios y Artesanos de Artes Mecánicas
	8 = Operadores de Instalaciones y Máquinas y Montadores
	9 = Trabajadores no Calificados							*/
* Main Job
gen     occup = .
replace occup = 1	if  oficio_prim==1
replace occup = 2	if  oficio_prim==2
replace occup = 3	if  oficio_prim==3
replace occup = 4	if  oficio_prim==4
replace occup = 5	if  oficio_prim==5
replace occup = 6	if  oficio_prim==6
replace occup = 7	if  oficio_prim==7
replace occup = 8	if  oficio_prim==8
replace occup = 9	if  oficio_prim==9
replace occup = .	if  ocupado!=1

* Secondary Job
gen     occup_s = .
replace occup_s = 1	if  oficio_secu==1
replace occup_s = 2	if  oficio_secu==2
replace occup_s = 3	if  oficio_secu==3
replace occup_s = 4	if  oficio_secu==4
replace occup_s = 5	if  oficio_secu==5
replace occup_s = 6	if  oficio_secu==6
replace occup_s = 7	if  oficio_secu==7
replace occup_s = 8	if  oficio_secu==8
replace occup_s = 9	if  oficio_secu==9
replace occup_s = .	if  ocupado!=1

* Other Job
gen   occup_o = .
notes occup_o: the survey does not include information on this topic

* Trabajador con contrato
/* P34: ¿es o era empleado:
	  1 = permanente 
	  2 = contrato por obra determinada 
	  3 = contrato definido 
	  4 = contrato indefinido 
	  5 = sin contrato escrito?							*/
gen	contrato = 1	if  p34==2 | p34==3 | p34==4
replace contrato = 0	if  p34==1 | p34==5
replace contrato = .	if  ocupado!=1  
notes   contrato: defined only for salaried workers

* Ocupación permanente
gen	ocuperma = 1	if  p34==1
replace ocuperma = 0	if  p34>=2 & p34<=5
replace ocuperma = .	if  ocupado!=1
notes   ocuperma: defined only for salaried workers

* Derecho a jubilación
* P4K_FONDO: está usted afiliado a algún fondo privado de jubilación o pensión
gen   djubila = .
notes djubila: the survey does not include information on this variable
notes djubila: the variable P4K_FONDO does not refer to right to a pension connected with employment

* Seguro de salud del empleo
gen   dsegsale = . 
notes dsegsale: the survey does not include information on this variable

* Derecho a aguinaldo
* P56H: Cuánto RECIBIÓ USTED EL MES PASADO POR décimo tercer mes?
gen	daguinaldo = 0  if  relab==2
replace daguinaldo = 1	if  relab==2 & p56_h>0 & p56_h<5000 
notes   daguinaldo: defined only for salaried workers

* Derecho a vacaciones pagas 
gen   dvacaciones = .
notes dvacaciones: the survey does not include information on this variable

* Sindicalizado
gen   sindicato = .
notes sindicato: the survey does not include information on this variable

* Programa de empleo
gen prog_empleo = .

* Numero de miembros ocupados en el hogar principal
gen     aux = ocupado
replace aux = 0			if  hogarsec==1
egen n_ocu_h=sum(aux),		by(id)
drop aux



/*(********************************************************************************************************************************************** 
			1.10: Programas sociales 
**********************************************************************************************************************************************)*/				
	
* Plan asistencia social
* P56_G1: Cuánto RECIBIÓ USTED EL MES PASADO POR Transferencia Monetaria Condicionada?
* P56_G2: Cuánto RECIBIÓ USTED EL MES PASADO POR Bono Familiar para Alimentos (SENAPAN)?
* P56_G5: Cuánto RECIBIÓ USTED EL MES PASADO POR 120 a los 65? 
* P56_G6: Cuánto RECIBIÓ USTED EL MES PASADO POR Angel Guardián?  
sort id com
egen aux = rsum(p56_g1 p56_g2 p56_g5 p56_g6)
sort id com
egen aux_h = sum(aux), by(id) 

gen	asistencia = 0
replace asistencia = 1 if aux_h>0
drop aux aux_h


/*(**********************************************************************************************************************************************
			1.11: Variables de ingresos 
**********************************************************************************************************************************************)*/	

* VARIABLES ORIGINALES DE LA ENCUESTA
/* P42: ¿Cual fue su salario o ingreso mensual en su trabajo?
	 P421 = salario en efectivo (bruto, sin deducir impuestos ni contribuciones al Seguro Social) 
	 P422 = en especie 
	 P423 = ingreso neto (entradas menos gastos en la actividad) por trabajo independiente 
	 P424 = en especie 
	 P425 = autoconsumo o autosuministro (sector agropecuario)
	 
	 P56_H = decimotercer mes
	 P56_I = ingresos agropecuarios							*/
replace p421 = .				if  p421>=99998
replace p422 = .				if  p422>=99998
replace p423 = .				if  p423>=99998
replace p424 = .				if  p424>=99998
replace p425 = .				if  p425>=99998
replace p56_h = .				if  p56_h>=99998
replace p56_i = .				if  p56_i>=99998

****   i)  ASALARIADOS
* Monetario	
egen  iasalp_m = rsum(p421 p56_h p56_i)		if  relab==2
notes iasalp_m:  relab = 2: 75 zero incomes

* No monetario
gen     iasalp_nm = p422			if  relab==2
replace iasalp_nm = .				if  iasalp_nm==0
notes iasalp_nm: relab = 2: 10,222 missing observations


*****  ii)  CUENTA PROPIA
* Monetario	
egen  ictapp_m = rsum(p423 p56_h p56_i)		if  relab==3
notes ictapp_m:  relab = 3: 795 zero incomes 

* No monetario
egen  ictapp_nm = rsum(p424 p425)		if  relab==3 
notes ictapp_m:  relab = 3: 4927 zero incomes 


***** iii)  PATRON
* Monetario	
egen  ipatrp_m = rsum(p423 p56_h p56_i)		if  relab==1
notes ipatrp_m:  relab = 1: 19 zero incomes 

* No monetario
egen  ipatrp_nm = rsum(p424 p425)		if  relab==1
notes ipatrp_m:  relab = 1: 393 zero incomes 



***** iii)  OTROS NO ESPECIFICADOS (SIN RELACION LABORAL)
* Monetario	
egen    iolp_m = rsum(p56_h p56_i)		if  relab==4 | relab==5 | relab==.
replace iolp_m=.				if  iolp_m==0
notes   iolp_m: includes labor earnings (during the last month) of some few unpaid workers

* No monetario
gen iolp_nm = .


***** v)   EXTRAORDINARIOS
gen ila_extraord = .


** Last wage payment
*  P421 = salario en efectivo (bruto, sin deducir impuestos ni contribuciones al SS) 
*  P423 = ingreso en efectivo por trabajo independiente (ingreso neto, entradas menos gastos en la actividad, incluye autoconsumo)
* P56_I = ingresos agropecuarios							
egen    wage_base = rsum(p421 p423 p56_i), missing
replace wage_base = 0		if  relab==4

** Bonos
*  P422 = en especie 
*  P424 = en especie 
* P425 = autoconsumo o autosuministro
* P56_H = decimotercer mes
egen bonos = rsum(p422 p56_h p424 p425), missing


****** A.2.OCUPACION NO PRINCIPAL ******
* P49: ¿Cuál fue su ingreso mensual en su otro trabajo?
destring p49, replace
replace  p49 = .	if  p49>=99998

****   i)  ASALARIADOS
* Monetario	
gen iasalnp_m = p49	if  relab_s==2

* No monetario
gen iasalnp_nm = . 


****  ii)  CUENTA PROPIA
* Monetario	
gen ictapnp_m = p49	if  relab_s==3
	
* No monetario
gen ictapnp_nm = .


**** iii)  PATRON
* Monetario	
gen ipatrnp_m  = p49	if  relab_s==1

* No monetario
gen ipatrnp_nm = .

				
****  iv) SIN RELACION (todo aquel ingreso  laboral que no se pueda clasificar con las categorias anteriores)
* Monetario
gen     iolnp_m = p49		if relab_s==4 | relab_s==.  
replace iolnp_m = .		if iolnp_m==0
    
* No monetario
gen iolnp_nm = .			


** Last wage payment
gen     wage_base_s = p49		
replace wage_base_s = .		if  njobs!=2
notes   wage_base_s: it reflects all income sources in the secondary job

gen   wage_base_o = .
notes wage_base_o: the survey does not include information on this topic

** Bonos
gen   bonos_s = .
notes bonos_s: the survey does not include information on this topic

gen   bonos_o = .
notes bonos_o: the survey does not include information on this topic


********** B.INGRESOS NO LABORALES  ****

***** B.1. INGRESOS NO LABORALES POR FUENTE *****
local lista "a b c1 c2 c3 c4 c5 c6 c7 c8 d f1 f2 f3 f4 g1 g2 g3 g4 g5 g6 k l"
foreach i in `lista' {
		     replace p56_`i' = .  if  p56_`i'>=99998 
		     }

****   i)  JUBILACIONES Y PENSIONES 
*  P56_A: por jubilación o pensión por vejez
*  P56_B: por pensión (por accidente, enfermedad, sobreviviente u otra)
* P56_G5: por subsidios - 120 a los 65	

* Contributivas
gen     ijubi_con = p56_a 
replace ijubi_con = .		if ijubi_con==0

* No Contributivas
gen     ijubi_ncon = p56_g5
replace ijubi_ncon = .		if  ijubi_ncon==0

* No Identificables
gen     ijubi_o = p56_b
replace ijubi_o = .		if  ijubi_o==0	
	

****  ii)  CAPITAL, INTERESES, ALQUILERES, RENTAS, BENEFICIOS, DIVIDENDOS 
* P56_D: alquileres, rentas, intereses o beneficios
gen     icap = p56_d
replace icap = .		if  icap==0

	
**** iii)  PROGRAMAS DE ALIVIO A LA POBREZA y TRANSFERENCIAS ESTATALES
/* P56_F1: becas de institución pública
   P56_F2: becas universales
   P56_G1: subsidios - transferencia monetaria condicionada (Red de Oportunidades)
   P56_G2: subsidios - bono familiar para alimentos (SENAPAN)
   P56_G3: subsidios - suplementos alimenticios              
   P56_G4: subsidios - insumos agropecuarios	
   P56_G5: subsidios - angel guardian
    P56_K: asistencia habitacional							*/

* CCT		
egen    icct = rsum(p56_g1 p56_g2 p56_g6), missing
replace icct = .		if  icct==0

* No CCT monetarias
egen    inocct_m = rsum(p56_f1 p56_f2), missing
replace inocct_m = .		if  inocct_m==0

* No CCT no monetarias
egen    inocct_nm = rsum(p56_g3 p56_g4 p56_k), missing
replace inocct_nm = .		if  inocct_nm==0

* Ingreso por transferencias estatales no identificable en las categorias anteriores 
gen     itrane_ns = .


**** iv)  TRANSFERENCIAS PRIVADAS 
/* P56_C: ayuda de instituciones u otras personas que no viven en el hogar:
     P56_C1:  pensión alimenticia		
     P56_C2:  dinero
     P56_C3:  alimentación escolar          
     P56_C4:  alimentos
     P56_C5:  articulos escolares        
     P56_C6:  otros
     P56_C7:  ropa/calzado			
     P56_C8:  regalos
     P56_F3:  becas institución privada	
     P56_F4:  otra									*/

* Del extranjero Monetario (remesas) 	 	
gen   itranext_m = .
notes itranext_m: there is not specific information on the survey to define this variable

* Del extanjero No Monetario
gen itranext_nm = .

* Del interior Monetario 		
egen    itranint_m = rsum(p56_c2 p56_f3 p56_f4), missing 
replace itranint_m = .			if  itranint_m==0 
	
* Del interior No Monetario
egen    itranint_nm = rsum(p56_c1 p56_c3 p56_c4 p56_c5 p56_c6 p56_c7 p56_c8), missing
replace itranint_nm = .			if  itranint_nm==0 

* No clasificable en las anteriores del punto iv
gen itranp_ns = .


****  v)  OTROS INGRESOS NO LABORALES
* P56_L: otros ingresos (camarones)                                            
gen     inla_otro = p56_l
replace inla_otro = .		if  inla_otro==0

* NO SE INCLUYE P56_E: por premios de loteria u otros juegos de azar


/*(********************************************************************************************************************************************** 
			1.12: INGRESO OFICIAL  
***********************************************************************************************************************************************)*/

**** Linea de Pobreza Oficial
gen lp_extrema = .
gen lp_moderada	= .   


**** Ingreso Oficial
gen ing_pob_ext = .
gen ing_pob_mod = .
gen ing_pob_mod_lp = ing_pob_mod / lp_moderada


/*(********************************************************************************************************************************************** 
			1.13: PRECIOS  
***********************************************************************************************************************************************)*/

* Mes en el que están expresados los ingresos de cada observación
gen mes_ingreso = 7

* IPC del mes base (Julio de 2019)
gen ipc = 122.444826488990003 		

* CPI periodo de referencia
gen cpiperiod = "2019m07" 
  
* Factor de ajuste para cada observación
gen     ipc_rel =   1
replace ipc_rel = 122.444826488990003 / ipc	if  mes_ingreso==7
	
* Ajuste por precios regionales 
gen     p_reg = 1
replace p_reg = 0.8695				if  urbano==0
	
foreach i of varlist iasalp_m iasalp_nm ictapp_m ictapp_nm ipatrp_m ipatrp_nm iolp_m iolp_nm iasalnp_m iasalnp_nm ictapnp_m ictapnp_nm ipatrnp_m ipatrnp_nm iolnp_m iolnp_nm  ijubi_con ijubi_ncon ijubi_o icap  icct inocct_m inocct_nm itrane_ns itranext_m itranext_nm itranint_m itranint_nm itranp_ns inla_otro	{
		       replace `i' = `i' / p_reg 
		       replace `i' = `i' / ipc_rel 
		       }


/*================================================================================================================================================
			2: Preparacion de los datos: Variables de segundo orden
==================================================================================================================================================*/
*quietly include "`do_file_aspire'"
quietly include "`do_file_1_variables'"
quietly include "`do_file_renta_implicita'"
quietly include "`do_file_2_variables'"
quietly include "`do_file_label'"
compress


/*==============================================================================================================================================
			3: Resultados
===============================================================================================================================================*/

/*(********************************************************************************************************************************************** 
			3.1 Ordena y Mantiene las Variables a Documentar Base de Datos CEDLAS 
**********************************************************************************************************************************************)*/
order pais ano encuesta id com pondera strata psu relacion relacion_est hombre edad gedad1 jefe conyuge hijo nro_hijos hogarsec hogar presec miembros casado soltero estado_civil raza raza_est lengua lengua_est region_est1 region_est2 region_est3 urbano oriental metro central occidental nuevareg migrante migra_ext migra_rur anios_residencia migra_rec propieta habita dormi precaria matpreca agua banio cloacas elect telef heladera lavarropas aire calefaccion_fija telefono_fijo celular celular_ind televisor tv_cable video computadora internet_casa uso_internet auto ant_auto auto_nuevo moto bici alfabeto asiste edu_pub aedu nivel nivedu prii pric seci secc supi supc exp seguro_salud tipo_seguro ocupado desocupa pea edad_min durades hstrp hstrs hstrt deseo_emp antigue relab relab_s relab_o empresa sector1d sector tarea contrato ocuperma djubila dsegsale daguinaldo dvacaciones sindicato prog_empleo n_ocu_h asal grupo_lab categ_lab asistencia iasalp_m iasalp_nm ictapp_m ictapp_nm ipatrp_m ipatrp_nm iolp_m iolp_nm iasalnp_m iasalnp_nm ictapnp_m ictapnp_nm ipatrnp_m ipatrnp_nm iolnp_m iolnp_nm ijubi_con ijubi_ncon ijubi_o icap icct inocct_m inocct_nm itrane_ns itranext_m itranext_nm itranint_m itranint_nm itranp_ns inla_otro ipatrp iasalp ictapp iolp ip ip_m wage wage_m ipatrnp iasalnp ictapnp iolnp inp ipatr ipatr_m iasal iasal_m ictap ictap_m ila ila_m ilaho ilaho_m perila ijubi itranp itranp_m itrane itrane_m itran itran_m inla inla_m ii ii_m perii n_perila_h n_perii_h ilf_m ilf inlaf_m inlaf itf_m itf_sin_ri renta_imp itf cohi cohh coh_oficial ilpc_m ilpc inlpc_m inlpc ipcf_sr ipcf_m ipcf iea ilea_m ieb iec ied iee lp_extrema lp_moderada ing_pob_ext ing_pob_mod ing_pob_mod_lp p_reg ipc pipcf dipcf p_ing_ofi d_ing_ofi piea qiea pondera_i ipc05 ipc11 ppp05 ipcf_cpi05 ipcf_cpi11 ipcf_ppp05 ipcf_ppp11  

save "`base_out_nesstar_cedlas'", replace

     
** EXPENDITURE VARIABLES

* Total annual consumption of water supply/piped water	
gen   pwater_exp = .
notes pwater_exp: the survey does not include information on this topic

* Total annual consumption of water supply and hot water	
gen   water_exp = .
notes water_exp: the survey does not include information on this topic

* Total annual consumption of garbage collection	
gen   garbage_exp = .
notes garbage_exp: the survey does not include information on this topic

* Total annual consumption of sewage collection	
gen   sewage_exp = .
notes sewage_exp: the survey does not include information on this topic

* Total annual consumption of garbage and sewage collection	
gen   waste_exp = .
notes waste_exp: the survey does not include information on this topic

* Total annual consumption of other services relating to the dwelling	
gen   dwelothsvc_exp = .
notes dwelothsvc_exp: the survey does not include information on this topic

* Total annual consumption of electricity	
gen   elec_exp = .
notes elec_exp: the survey does not include information on this topic

* Total annual consumption of network/natural gas	
gen   ngas_exp = .
notes ngas_exp: the survey does not include information on this topic

* Total annual consumption of liquefied gas	
gen   LPG_exp = .
notes LPG_exp: the survey does not include information on this topic

* Total annual consumption of network/natural and liquefied gas	
gen   gas_exp = .
notes gas_exp: the survey does not include information on this topic

* Total annual consumption of diesel	
gen   diesel_exp = .
notes diesel_exp: the survey does not include information on this topic

* Total annual consumption of kerosene	
gen   kerosene_exp = .
notes kerosene_exp: the survey does not include information on this topic

* Total annual consumption of other liquid fuels	
gen   othliq_exp = .
notes othliq_exp: the survey does not include information on this topic

* Total annual consumption of all liquid fuels	
gen   liquid_exp = .
notes liquid_exp: the survey does not include information on this topic

* Total annual consumption of firewood	
gen   wood_exp = .
notes wood_exp: the survey does not include information on this topic

* Total annual consumption of coal	
gen   coal_exp = .
notes coal_exp: the survey does not include information on this topic

* Total annual consumption of peat	
gen   peat_exp = .
notes peat_exp: the survey does not include information on this topic

* Total annual consumption of other solid fuels	
gen   othsol_exp = .
notes othsol_exp: the survey does not include information on this topic

* Total annual consumption of all solid fuels	
gen   solid_exp = .
notes solid_exp: the survey does not include information on this topic

* Total annual consumption of all other fuels	
gen   othfuel_exp = .
notes othfuel_exp: the survey does not include information on this topic

* Total annual consumption of central heating	
gen   central_exp = .
notes central_exp: the survey does not include information on this topic

* Total annual consumption of hot water	
gen   hwater_exp = .
notes hwater_exp: the survey does not include information on this topic

* Total annual consumption of heating	
gen   heating_exp = .
notes heating_exp: the survey does not include information on this topic

* Total annual consumption of all utilities excluding telecom and other housing	
gen   utl_exp = .
notes utl_exp: the survey does not include information on this topic

* Total annual consumption of materials for the maintenance and repair of the dwelling 	
gen   dwelmat_exp = .
notes dwelmat_exp: the survey does not include information on this topic

* Total annual consumption of services for the maintenance and repair of the dwelling	
gen   dwelsvc_exp = .
notes dwelsvc_exp: the survey does not include information on this topic

* Total annual consumption of dwelling repair/maintenance 	
gen   othhousing_exp = .
notes othhousing_exp: the survey does not include information on this topic

* Total annual consumption of fuels for personal transportation	
gen   transfuel_exp = .
notes transfuel_exp: the survey does not include information on this topic

* Total annual consumption of landline phone services	
gen   landphone_exp = .
notes landphone_exp: the survey does not include information on this topic

* Total annual consumption of cell phone services	
gen   cellphone_exp = .
notes cellphone_exp: the survey does not include information on this topic

* Total consumption of all telephone services 	
gen   tel_exp = .
notes tel_exp: the survey does not include information on this topic

* Total consumption of internet services	
gen   internet_exp = .
notes internet_exp: the survey does not include information on this topic

* Total consumption of telefax services	
gen   telefax_exp = .
notes telefax_exp: the survey does not include information on this topic

* Total consumption of all telecommunication services	
gen   comm_exp = .
notes comm_exp: the survey does not include information on this topic

* Total consumption of TV broadcasting services	
gen   tv_exp = .
notes tv_exp: the survey does not include information on this topic

* Total consumption of tv, internet and telephone	
gen   tvintph_exp = .
notes tvintph_exp: the survey does not include information on this topic

