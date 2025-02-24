***********************************************************
*Goal: priliminary analysis of impact from mobile coverage 
*Author: Yujuan Gao
*Date: 10/25/2023
*This version: 1/23/2024
***********************************************************

	clear
	set more off,permanently
	capture log close
	set scrollbufsize 100000
	set matsize 11000
	
**# Bookmark #1 set up dir	

	*global path "C:\Users\yujuan.gao\REAP Dropbox\Gao yujuan\lightning_bolts"
	global path "C:\Users\Yujuan\REAP Dropbox\Gao yujuan\lightning_bolts"
	*global path "/Users/gaoyujuan/REAP Dropbox/Gao yujuan/lightning_bolts"
	*global path "/Volumes/Ext_Drive/Dropbox/00_Research_Shared/lightning_bolts"

	*windows
	 global productdir "$path\Interim_Data_Product\"
	 global dhsdir "$path\processed\dhs\"
	 global dofiledir "$path\scripts\"
	 global resultdir "$path\Tables\"
	

	/*mac
	global productdir "$path/Interim_Data_Product/"
	global dhsdir "$path/processed/dhs/"
	global dofiledir "$path/scripts/"
	global resultdir "$path/Tables/"
	*/
	
** Load data
	
	use "${productdir}merged_GSM_lightning_weather.dta",clear
	replace GSMYEAR = GSMYEAR-1 //Mobile Coverage is released annually in January each year. When the data release is named 2014, any operator data received up to the end of the year 2013 is included in this release.
	save "${productdir}merged_GSM_lightning_weathernew.dta",replace
	
	use "${dhsdir}DHS_2013_2018.dta",clear
	gen GSMYEAR = DHSYEAR
	rename v001 DHSCLUST
	merge m:m DHSCLUST GSMYEAR using "${productdir}merged_GSM_lightning_weathernew.dta"
	tab _merge
	keep if _merge == 3 //522 household don't have coordinate system information
	drop _merge
	save "${dhsdir}DHS_weathercov.dta",replace
	
**# Bookmark #2 process variables 
	
	use "${dhsdir}DHS_weathercov.dta",clear
	
	gen wgt = iweight/1000000
	svyset[pw=wgt],psu(v021) strata(v022)
	
	label define yesno 1"Yes" 0 "No"
	*************************************************************
	*Process outcomes and covariate from DHS Indinividual Survey*
	*************************************************************
	
	**EMPLOYMENT
	
	*******************QUESTION********************
	
	/*1. V714 Whether the respondent is currently working.
	  2. V714A Whether the respondent has a job or business from which she was absent for leave, illness, vacation, maternity leave, or any other reason for the last 7 days. //BASE: Women not currently working and women who had a job from which she was absent (V714 = 0 and V714A = 1).
	 3. V716 Respondent's occupation as collected in the country. Codes are country-specific.
	 4. V717 Standardized respondent's occupation groups. Agricultural categories also include fishermen, foresters and hunters and are not the basis for selection of agricultural/non- agricultural workers. In countries, where it is not possible to differentiate between self- employed agricultural workers and agricultural employees, no attempt has been made to use other information, and code 4 has been used for both categories. The analyst may wish to use other related information to differentiate between these two categories.
	 5. V719 Whether the respondent works for a family member, for someone else or is self-employed.BASE: Women who worked in last 12 months (V716 <> 0).
	 6. V731 Whether the respondent worked in the last 12 months.
	 7. V732 Whether the respondent works throughout the year, seasonally, or just occasionally. BASE: Women who are currently working or who have worked in the past year (V731 = 1 or V731 = 2 or V731 = 3)*/
	
	**********************************************
	
*1. V714 Whether the respondent is currently working.	
    tab v714 [iw=wgt] 
	capture drop empl_current
	recode v714 (9 .=0 "No"), gen(empl_current)
	label values empl_current v714
	label var empl_current "Woman is currently working"

*4. V717 Standardized respondent's occupation groups.
*refer: https://github.com/DHSProgram/DHS-Indicators-Stata/blob/master/Chap03_RC/RC_tables.do 
	tab v717 [iw=wgt]
	capture drop agri
	recode v717 (1/3 6/11 96/99 .=0 "Non-Agriculture") (4/5=1 "Agriculture") if inlist(v731,1,2,3), gen(agri)
	label var agri "Woman's ocupation is Agriculture"
	
*5. V719 Whether the respondent works for a family member, for someone else or is self-employed.BASE: Women who worked in last 12 months (V716 <> 0).
	tab v717 [iw=wgt]
	capture drop self_empl
	recode v719 (1/2 9 .=0 "No") (3=1 "Yes") if inlist(v731,1,2,3), gen(self_empl)
	label var self_empl "Woman is self-employed"
	
*6. V731 Whether the respondent worked in the last 12 months.	
	tab v731 [iw=wgt] 
	capture drop empl_year
	recode v731 (9 .=0 "No") (1 2 3 =1 "Yes"), gen(empl_year)
	label var empl_year "Woman worked in the last 12 months"

* 7. V732 Whether the respondent works throughout the year, seasonally, or just occasionally.	
* refer: https://github.com/DHSProgram/DHS-Indicators-Stata/blob/master/Chap03_RC/RC_CHAR.do
	tab v732 [iw=wgt]
	capture drop empl_cont
	gen empl_cont=v732 if inlist(v731,1,2,3) & v732!=9
	label values empl_cont V732
	label var empl_cont "Continuity of employment among those employed in the past 12 months"
	
	global emply empl_current empl_year empl_cont self_empl
	

	**COVARIATE
	
	*age i.highest_education v191
	
	rename v191 wealth_index
	
		*The wealth index is a composite measure of a household's cumulative living standard. The wealth index is calculated using easy-to-collect data on a household's ownership of selected assets, such as televisions and bicycles; materials used for housing construction; and types of water access and sanitation facilities.
		*Generated with a statistical procedure known as principal components analysis, the wealth index places individual households on a continuous scale of relative wealth. DHS separates all interviewed households into five wealth quintiles to compare the influence of wealth on various population, health and nutrition indicators. The wealth index is presented in the DHS Final Reports and survey datasets as a background characteristic.
		*Wealth index for urban/rural. As a response to criticism that a single wealth index (as provided by HV270 and HV271) is too urban in its construction and not able to distinguish the poorest of the poor from other poor households, this variable provides an urban- and rural-specific wealth index.

	recode v025 (2=0 "rural"),gen(place)
	label value place v025
	label var place "type of place of resident"
		
		*De facto type of place of residence. Type of place of residence where the respondent was interviewed as either urban or rural. Note that this is not the respondent's own categorization, but was created based on whether the cluster or sample point number is defined as urban or rural. 
	
	
	global vcov age i.highest_education wealth_index place
	
	*************************************************************
		*Process mobile own and information receiving*
	*************************************************************
	
	recode own_phone  (7 9 =.) ,gen (own_phone _dum)
		label values own_phone _dum own_phone 
		label var own_phone _dum "Has mobile phone"
	 
	 recode v171a (1/2=1 "Yes") (0=0 "No"), gen (use_internet_dum)
 		label var use_internet_dum "Has used internet"

	recode reading_newspaper listening_radio watch_tv (1/2 =1)(9 . =0),gen(reading_newspaper_d listening_radio_d watch_tv_d)
		label var reading_newspaper_d "Reading newspaper or magzaine (1=Yes)"
		label var listening_radio "Listening to radio (1=Yes)"
		label var watch_tv "Watching television (1=Yes)"
	
	global infor_receive reading_newspaper_d listening_radio_d watch_tv_d
	
	*************************************************************
		*Process GSM coverage and internet coverage*
	*************************************************************
	
	foreach bfd in 10 30 50{
		
	 gen GSMCOVER_dist`bfd'_dum= 0 if GSMCOVER_dist`bfd'<=0.1
		replace GSMCOVER_dist`bfd'_dum =1 if GSMCOVER_dist`bfd'>0.1
	
	 gen GSMCOVER_2G_dist`bfd'_dum= 0 if GSMCOVER_2G_dist`bfd'<=0.9
		replace GSMCOVER_2G_dist`bfd'_dum =1 if GSMCOVER_2G_dist`bfd'>0.9
	}
	
	label var ltcovm_1021_dist10 "Average Lightning Coverage"

	*************************************************************
				*Process covariates for weather*
	*************************************************************
	
	global cov wind_m_l1 Precipatation_s_l1 vapour_m_l1 solar_m_l1 temair_m_l1 rain_s_l1 Elevation  //lagged weather variables
	
	
	***********************************************************
	                 *Reproduction*
	***********************************************************
	*v137 v201 v202 v203 v204 v205 v208 v209 v212 v213 v217 v218 v219 v220 v221 v228 v238 v244 
	*v137 Number of children resident in the household and aged 5 and under. Visiting children are not included.
	clonevar childnum_under5=v137
	*v201 Total number of children ever born
	clonevar childnum=v201
	*v202 Total number of sons living at home
	clonevar sons_livehome_num=v202
	*v203 Total number of daughters living at home
	clonevar daughters_livehome_num=v203
	*v204 Total number of sons living away from home
	clonevar sons_liveaway_num=v204
	*v205 Total number of daughters living away from home
	clonevar daughters_liveaway_num=v205
	*v208 Total number of births in the last five years is defined as all births in the months 0 to 59 prior to the month of interview, where month 0 is the month of interview.
    clonevar birthnum_5y=v208
	*v209 Total number of births in the past year is defined as all births in the months 0 to 12 (not 0 to 11) prior to the month of interview.
	clonevar birthnum_1y=v209
	*v212 Age of the respondent at first birth is calculated from the CMC of the date of first birth and the CMC of the date of birth of the respondent.BASE: All respondents with one or more births (V201 > 0).
	clonevar firstbirth_age=v212
	
	*V213 Whether the respondent is currently pregnant.
	clonevar pregnt=v213
	*v217 Knowledge of the ovulatory cycle indicates when during her monthly cycle the respondent thinks a woman has the greatest chance of becoming pregnant. middle of the cycle is correct. Wilcox J. The timing of the "fertile window" in the menstrual cycle: day specific estimates from a prospective study. BMJ. 2000;321:1259–1262. doi: 10.1136/bmj.321.7271.1259. ////https://www.frontiersin.org/articles/10.3389/fpubh.2022.828967/full
	
	recode v217 (3=1)(1 2 4 5 6 8=0)(9=.), gen (ovulatory_know)
		label values ovulatory_know yesno
		label var ovulatory_know "Know when has the greatest chance of becoming pregnant during ovulatory cycle"
	*v218 Total number of living children
	clonevar child_live_num=v218
	*v219 total number of living children including current pregnancy
	clonevar child_pregnt_num=v219
	*v220 Total number of living children including current pregnancy is a grouping of the previous variable, truncating the number to 6 if it was greater than 6.
	recode v220 (1/5 = 0)(6=1)(7=.), gen (childpregnt_live_numdum)
		label var childpregnt_live_numdum "Total number of living children and current pregnancy >=6"
	*V221 Interval between the first marriage and first birth in months. 
	*If the first birth was prior to the first marriage then this variable is coded 996 "Negative interval." //BASE: Ever-married women who have had one or more births (V501 > 0 & V201 > 0).
	recode v221 (996 = .), gen (first_birth_marri)
		label var first_birth_marri "Interval between the first marriage and first birth in months"
	recode v221 (996 = 1) (1/310=0), gen (birth_before_marri)
		label var birth_before_marri "The first birth was prior to the first marriage"
		label values birth_before_marri yesno
	recode v221 (996 0/8=1)(9/310=0),gen(pregnt_before_marri)
	
	*v228 Whether the respondent ever had a pregnancy that terminated in a miscarriage, abortion, or still birth, i.e., did not result in a live birth.
	clonevar terminated_pregnt = v228 
		recode v228(9=.)
	*Total live sons
	gen sons_live = v202+v204
	*Total live daughters
	gen daughter_live = v203+v205
	*v238 Total number of births in the last three years is defined as all births in the months 0 to 35 prior to the month of interview, where month 0 is the month of interview.	
	clonevar birthnum_3y = v238
	*v244 can women get pregnant after birth and before period
	clonevar period_know = v244
	recode period_know (8=.)
	
	gen birthnum_5y_dum=0 if birthnum_5y ==0
		replace birthnum_5y_dum=1 if birthnum_5y>0 & birthnum_5y!=.
		label var birthnum_5y_dum "Have births in the last five years"
	gen birthnum_3y_dum=0 if birthnum_3y ==0
		replace birthnum_3y_dum=1 if birthnum_3y>0 & birthnum_3y!=.
		label var birthnum_3y_dum "Have births in the last three years"
	gen birthnum_1y_dum=0 if birthnum_1y ==0
		replace birthnum_1y_dum=1 if birthnum_1y>0 & birthnum_1y!=.
		label var birthnum_1y_dum "Have births in the last years"

	gen childnum_under5_dum=0 if childnum_under5==0
		replace childnum_under5_dum=1 if childnum_under5 >0 & childnum_under5!=. 
		label var childnum_under5_dum "Have children under 5"
	gen childnum_dum=0 if childnum==0
		replace childnum_dum=1 if childnum>0 & childnum!=. 
		label var childnum_dum "Have children"
	gen child_live_num_dum=0 if child_live_num==0
		replace child_live_num_dum=1 if child_live_num>0 & child_live_num!=. 
	    label var child_live_num_dum "Have living children" 
	 
	 recode childnum (0=.)(1=0)(2/18=1),gen (child_1st)
		label var child_1st "Have second or higher-order child"
		label values child_1st yesno
	
	*risk fertility behaviors:
		*mothers age less than 18 years at the time of childbirth or mothers age over 34 years at the time of childbirth
		*latest child born less than 24 months after the previous birth
		*latest child's birth order 3 or higher

	global repro childnum_under5 childnum child_live_num pregnt terminated_pregnt child_pregnt_num childpregnt_live_numdum daughter_live daughters_livehome_num daughters_liveaway_num sons_live sons_livehome_num sons_liveaway_num birthnum_5y birthnum_3y birthnum_1y firstbirth_age first_birth_marri birth_before_marri ovulatory_know period_know childnum_dum childnum_under5_dum child_live_num_dum birthnum_5y_dum birthnum_3y_dum birthnum_1y_dum child_1st
	
	***********************************************************
						*Contraception*
	***********************************************************
	recode v301(2 3 = 1), gen (know_contra_dum)
		label values know_contra_dum yesno
		label var know_contra_dum "Knows any contraception method"
	
	recode v301(1/2=0)(3=1), gen (know_contra_modern)
		label values know_contra_modern yesno
		label var know_contra_modern "Knows modern method"
	*V3O2A
	*Ever used anything or tried to delay or avoid getting pregnant. This variable was added to replace variable V302, which is no longer part of the DHS VII core questionnaire where the questions on ever use by method are no longer part of the contraceptive table. V302A is based on the question on ever use of any way to avoid getting pregnant and the calendar.
	recode v302a (2=1),gen (avoid_pregnant_dum)
		label values avoid_pregnant_dum yesno
		label var avoid_pregnant_dum "Ever used anything or tried to delay or avoid getting pregnant"
	
	*v312 Current contraceptive method. Pregnant women are coded 0 "Not currently using."
	recode v312 (2/18=1), gen (contra_use)
		label values contra_use yesno
		label var contra_use "Currently use contaception"
	
	*V313 Type of contraceptive method categorizes the current contraceptive method as either a modern method, a traditional method, or a folkloric method.
	recode v313(1/2=0)(3=1), gen (contra_modern_current)
		label values contra_modern_current yesno
		label var contra_modern_current "Currently use modern contraception method"
		
	global contra contra_modern avoid_pregnant_dum contra_use contra_modern_current
	
	*V327 The last source visited for users of modern methods in standard coding groups constructed from V326. //BASE: Respondents currently using a modern method (V312 >= 1 & V312 <= 7 or V312 = 11 or V312 >= 14 & V312 <= 18).
	
	 recode v327 (1 4 5 =1)(2 3 6 7 9=0), gen (contra_modern_source)
		label values contra_modern_source yesno
		label var contra_modern_current "Last source visited for users of modern methods is from clinic or pharmacy"
	
	*v337 Months of use of the current contraceptive method. BASE: Current users of contraception (V312 <> 0).
	recode v337 (95 = .), gen (contra_current_month)
		label var contra_current_month "Months of use of the current contraceptive method."
	
	*v362 Intention to use a contraceptive method in the future
	*Intention to use a contraceptive method in the future is based on two questions, and classifies those intending to use a method in the future by whether they intend to use that method in the next twelve months or not. The two "Unsure" categories correspond to replies of unsure about using a method in the future (unsure about use) or, for those intending to use a method in the future, unsure about whether they intend to use that method in the next twelve months (unsure about timing). //BASE: All respondents not currently using contraception (V312 = 0).
	recode v362 (2=1)(4 5 9=0), gen (contra_intention)
		label var contra_intention "Intention to use a contraceptive method in the future"
	*v367 Whether the last child born in the last three/five years was wanted at that time, later or not at all. BASE: Women who gave birth to a child in the last three/five years (V417 > 0).
	recode v367(2 3 =0)(9=.),gen (lastchild_want)
		label var lastchild_want "Whether the last child born in the last three/five years was wanted at that time"
		label values lastchild_want yesno
	*V380 Source of any method of contraception coded in standard coding categories is created from V379.
	recode v380 (1 4 5 =1)(2 3 6 7 8=0), gen (contra_source)
		label values contra_source yesno
		label var contra_source "Last source visited for users of any contraception methods is from clinic or pharmacy"
	
	*V384A Heard about FP on the radio in the last few months
	*V384B Heard about FP on the TV in the last few months
	*V384C Heard about FP from a newspaper or magazine in the last few months
	*V384D Heard about FP from a voice or text message on a mobile phone in the last few months
	recode v384a v384b v384c v384d (9=.),gen (fp_radio fp_TV fp_newspaper fp_voice_text)
		label var fp_radio "Heard about family plan on the radio in the last few months"
		label var fp_TV "Heard about family plan on the TV in the last few months"
		label var fp_newspaper "Heard about family plan on the newspaper in the last few months"
		label var fp_voice_text "Heard about family plan from a voice or text message on a mobile phone in the last few months"
		label values fp_radio fp_TV fp_newspaper fp_voice_text yesno
	
	global contra avoid_pregnant_dum contra_use contra_source ///
	know_contra_modern contra_use contra_modern_current contra_modern_source contra_intention ///
	       fp_radio fp_TV fp_newspaper lastchild_want
	
	**********************************************************
				*Section W61: Fertility Preferences*
	**********************************************************
	*v603 v605 v613 v614
	*v602 Women who respond that they want another child
	/*The "Fertility preferences" come primarily from a single question in the DHS V and DHS
VII questionnaires. Women who respond that they want another child, but when asked when
they would like the next child, respond that they cannot get pregnant, are classified in the
"declared infecund category", and not in the "Wants another" category. These women can be
identified in variable V616, where the original response to the question asking how long they
would like to wait before having another child is recorded. In some countries, women who
had never had sexual intercourse were not asked the questions relating to desire for future
children, and are coded 6 on V602.*/

	recode v602 (2 3 = 0)(4 5 9 =.),gen (another_child)
	 label values another_child yesno
	 label var another_child "Women want another child"
	
	*v604 Preferred waiting time before the birth of another child
	 recode v604 (0 1 =0) (2/7=1) (8 9 = .), gen (another_child_1year)
		label values another_child_1year yesno
		label var another_child_1year "Preferred waiting time before the birth of another child<=1 Year"
	 recode v604 ( 0 1 2=0)(3/7=1)(8 9 =.), gen (another_child_2year)
		label values another_child_2year yesno
		label var another_child_2year "Preferred waiting time before the birth of another child<=2 Year"
	
	*V613 ideal number of children
	
	/*The ideal number of children that the respondent would have liked to have in her whole life, irrespective of the number she already has. In many countries it was possible for a respondent to reply to this question with a range of values, in which case this variable contains the midpoint between these values. If the midpoint is not an exact number then the number is rounded up in half the cases and rounded down for the other half. In situations where a range of values was collected, the original variables are included as country-specific variables. In some countries, additional country-specific categories are included, such as "It depends on God" or "As many as I can support" and are given country-specific codes.*/
	recode v613 (96 99 =.),gen (ideal_childnum)
		label var ideal_childnum "Ideal number of children"
	
	*v614
	*This variable groups the preceding variable such that 6 or more children are in one category 6+ and all non-numeric responses are coded 7.
	recode v614 (1/5 = 0)(6=1)(7=.), gen (ideal_num_dum)
		label values ideal_num_dum yesno
		label var ideal_num_dum "Ideal number of children >=6"
	
	*v627 Ideal number of boys
	recode v627 (96 9 = .), gen (ideal_boynum)
		label var ideal_boynum "Ideal number of boys"
	*v628 Ideal number of girls
	recode v628 (96 9 = .), gen (ideal_girlnum)
		label var ideal_girlnum "Ideal number of girls" 

	*v632 Women in union and using contraception are asked who decided on the use of contraception. BASE: V502 = 1 and V312 <> 0
	recode v632 (3=1)(2=0)(6 9 =.),gen (decide_use_conctra)
		label values decide_use_conctra yesno
		label var decide_use_conctra "Woman decided use of contraception or decided with hudband jointly"	
	*v632a Women in union, not using contraception and not pregnant are asked who decided on the non-use of contraception. BASE: V502 = 1 and V312 = 0 and V213 <> 1
	recode v632a (3=1)(2=0)(6 9 =.),gen (decide_use_conctra_nopregnt)
		label values decide_use_conctra_nopregnt yesno
		label var decide_use_conctra_nopregnt "Woman decided use of contraception or decided with hudband jointly"

	global fertility another_child another_child_2year ideal_childnum ideal_num_dum ideal_boynum ideal_girlnum decide_use_conctra decide_use_conctra_nopregnt
	
	**********************************************************
				*Marriage*
	**********************************************************
	*v502 Whether the respondent is currently, formerly or never married (or lived with a partner). Currently married includes married women and women living with a partner, and formerly married includes widowed, divorced, separated women and women who have lived with a partner but are not now living with a partner.
	recode v502 (2=1), gen(union)
		label var union " currently/formerly in union"
		label values union yesno
	
	**********************************************************
				*Section WG1: Female gential cutting*
	**********************************************************
	*G100 Ever heard of female circumcision.
	clonevar circumcision_hear = g100
		recode circumcision_hear (9=.)
	
	*G102 Respondent circumcised. BASE: Ever heard of female circumcision.
	clonevar circumcised = g102
	   recode circumcised (8 9 =.)
	
	*G105 Genital area sewn closed. BASE: Ever heard of female circumcision.
	clonevar sewn =g105
	   recode sewn (8 9 =.)
	 
	 *G106 Age at circumcision BASE: Ever heard of female circumcision.
	 clonevar circumcision_age = g106
		recode circumcision_age(95=0)(98 99 =.)
	
	*G107 Who performed circumcision BASE: Ever heard of female circumcision.
	clonevar circumciser_profess = g107
		recode circumciser_profess (11 12 16 =1)(21 22 26=0)(98 99 =.)
	
	*G108 Number of daughters circumcised BASE: Ever heard of female circumcision.
	clonevar daughter_circumcised_num = g108
	
	*G118 Circumcision is required by religion. BASE: Ever heard of female circumcision.
	clonevar circumcised_religion = g118
		recode circumcised_religion (3 8 =.)
	
	*G119 Circumcision should continue or be stopped. BASE: Ever heard of female circumcision.
	recode g119 (1 3 =0)(2=1)(8 9 =.),gen (circumcised_stop)
		label values circumcised_stop yesno
		label var circumcised_stop "Circumcision should be stopped"
	global fgc circumcision_hear circumcised sewn circumcision_age daughter_circumcised_num circumcised_religion circumcised_stop
	***********************************************************
	               *SAMPLE
	***********************************************************
	
	gen northern=0 
	replace northern =1 if admin1Name=="Kebbi" | admin1Name=="Zamfara" | admin1Name=="Kaduna" | admin1Name=="Bauchi" | admin1Name=="Gombe" | admin1Name=="Sokoto" | admin1Name=="Katsina" | admin1Name=="Kano" | admin1Name=="Jigawa" | admin1Name=="Yobe" | admin1Name=="Borno"

	bysort DHSCLUST DHSYEAR: gen cluster_id=_n
	
	*svyset[pw=wgt],psu(v021) strata(v022)

	save "${dhsdir}analysis.dta",replace
	
	***********************************************************
	     *Should we include 2g coverage in the regression?
	***********************************************************
	
	/*The other thing we might check is whether lightning predicts 2G coverage in 2018. If the IV affects 2G coverage, and 2G coverage affects our outcomes, controlling for 2G in our IV models as they do in the Goldberg paper will not solve the problem if 2G coverage is endogenous. But if the IV doesn't affect 2G, we don't have an issue.*/
	* all significant, so controlling 2g coverage is not correct
	
	use "${dhsdir}analysis.dta",replace
	global cov wind_m_l1 Precipatation_s_l1 vapour_m_l1 solar_m_l1 temair_m_l1 rain_s_l1 Elevation  //lagged weather variables

	*********************************
	*regression in 2013 2018*
	********************************
	
	local date : di %tcDD-NN-CCYY c(current_date)
	
	local m=0

	foreach y in 2013 2018{
	
		local n = 0
		
		local m =`m'+1
		
		*Full sample: Panel A of table A1, table A2, table A3 
		
		est clear
		
		foreach bfd in 10 30 50{
			
			local n = `n' + 1
			
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y', noabsorb cluster(cluster_id) 
				est store a`n'
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y', a(admin1Pcod) cluster(cluster_id)
				est store b`n'
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y', noabsorb cluster(admin2Pcod cluster_id)
				est store c`n'
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y', a(admin1Pcod) cluster(admin2Pcod cluster_id)
				est store d`n'		
		}
		
		outreg2 [*1 *2 *3] using "${resultdir}2g_lt_regression_`y'new_`date'.xls", dec(3) replace label keep (ltcovm_1021_dist10) stats(coef se tstat) nocons title (Table A`m': Regression between 2g coverage and lightning coverage in `y') ///
		addnote ("Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature")
		
		*Excluding northern: Panel B of table A1, table A2, table A3
		
		local n = 0
		
		est clear
		
		foreach bfd in 10 30 50{
			
			local n = `n' + 1
			
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & northern ==0, noabsorb cluster(cluster_id)
				est store a`n'
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & northern ==0, a(admin1Pcod) cluster(cluster_id)
				est store b`n'
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & northern ==0, noabsorb cluster(admin2Pcod cluster_id) 
				est store c`n'
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & northern ==0, a(admin1Pcod) cluster(admin2Pcod cluster_id)
				est store d`n'		
		}
		
		local m =`m'+1
		
		outreg2 [*1 *2 *3] using "${resultdir}2g_lt_regression_`y'new_`date'.xls", dec(3) replace label keep (ltcovm_1021_dist10) stats(coef se tstat) nocons title (Table B`m': Regression between 2g coverage and lightning coverage in `y', exclusing northern part) ///
		addnote ("Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature")
		
	}

	***************************************
	*regression when pooling 2013 and 2018*
	***************************************
	
	*Full sample: Panel A of table 4
	
	local n = 0
		
		est clear
		
		foreach bfd in 10 30 50{
			
			local n = `n' + 1
			
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018) , noabsorb cluster(cluster_id)
				est store a`n'
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018) , a(admin1Pcod DHSYEAR) cluster(cluster_id)
				est store b`n'
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018) , noabsorb cluster(admin2Pcod cluster_id) 
				est store c`n'
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018) ,  a(admin1Pcod GSMYEAR) cluster(admin2Pcod cluster_id) 
				est store d`n'	
			reghdfe GSMCOVER_2G_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018) , noabsorb cluster(cluster_id)
				est store e`n'
			reghdfe GSMCOVER_2G_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018) , a(admin1Pcod DHSYEAR) cluster(cluster_id) 
				est store f`n'
			reghdfe GSMCOVER_2G_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  , noabsorb cluster(admin2Pcod cluster_id) 
				est store g`n'
			reghdfe GSMCOVER_2G_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018) ,  a(admin1Pcod GSMYEAR) cluster(admin2Pcod cluster_id) 
				est store h`n'
		}
		
		outreg2 [*1 *2 *3] using "${resultdir}2g_lt_regression_poolnew_`date'.xls", dec(3) replace label keep (ltcovm_1021_dist10 c.ltcovm_1021_dist10#c.GSMYEAR) stats(coef se tstat) nocons title (Table A4: Regression between 2g coverage and lightning coverage in 2013 and 2018) ///
	   addnote ("Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature")
		
		
		
		*Excluding northern part: Panel B of table 4
		
		
		
		local n = 0
		
		est clear
		
		foreach bfd in 10 30 50{
			
			local n = `n' + 1
			
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0, noabsorb cluster(cluster_id)
				est store a`n'
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0, a(admin1Pcod DHSYEAR) cluster(cluster_id)
				est store b`n'
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0, noabsorb cluster(admin2Pcod cluster_id) 
				est store c`n'
			reghdfe GSMCOVER_2G_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0,  a(admin1Pcod GSMYEAR) cluster(admin2Pcod cluster_id) 
				est store d`n'	
			reghdfe GSMCOVER_2G_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0, noabsorb cluster(cluster_id)
				est store e`n'
			reghdfe GSMCOVER_2G_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0, a(admin1Pcod DHSYEAR) cluster(cluster_id)
				est store f`n'
			reghdfe GSMCOVER_2G_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0, noabsorb cluster(admin2Pcod cluster_id) 
				est store g`n'
			reghdfe GSMCOVER_2G_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0,  a(admin1Pcod GSMYEAR) cluster(admin2Pcod cluster_id) 
				est store h`n'	
		}
		
		outreg2 [*1 *2 *3] using "${resultdir}2g_lt_regression_poolnew_`date'.xls", dec(3) replace label keep (ltcovm_1021_dist10 c.ltcovm_1021_dist10#c.GSMYEAR) stats(coef se tstat) nocons title (Table B4: Regression between 2g coverage and lightning coverage in 2013 and 2018,exclusing northern part) ///
	   addnote ("Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature")		
		
**#Bookmark #2 first stage regression

	*********************************
	*regression in 2013 2018*
	********************************
	
	use "${dhsdir}analysis.dta",replace
	global cov wind_m_l1 Precipatation_s_l1 vapour_m_l1 solar_m_l1 temair_m_l1 rain_s_l1 Elevation  //lagged weather variables

	local date : di %tcDD-NN-CCYY c(current_date)
	
	local m=0

	foreach y in 2013 2018{
	
		local n = 0
		
		local m =`m'+1
		
		*Full sample
		
		est clear
		
		foreach bfd in 10 30 50{
			
			local n = `n' + 1
			
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y' , noabsorb cluster(cluster_id)
				est store a`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y' , a(admin1Pcod) cluster(cluster_id)
				est store b`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y' , noabsorb cluster(admin2Pcod cluster_id)
				est store c`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y' , a(admin1Pcod) cluster(admin2Pcod cluster_id)
				est store d`n'		
		}
		
		
		outreg2 [*1 *2 *3] using "${resultdir}first_stage_regression_`y'new_`date'.xls", dec(3) replace label keep (ltcovm_1021_dist10 c.ltcovm_1021_dist10#c.GSMYEAR) stats(coef se tstat) nocons title (Table `m': First stage regression between mobile internet coverage and lightning coverage in `y') addnote ("Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature")
		
		*Excluding northern
		
		local n = 0
		
		est clear
		
		foreach bfd in 10 30 50{
			
			local n = `n' + 1
			
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & northern ==0, noabsorb cluster(cluster_id)
				est store a`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & northern ==0, a(admin1Pcod) cluster(cluster_id)
				est store b`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & northern ==0, noabsorb cluster(admin2Pcod cluster_id) 
				est store c`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & northern ==0, a(admin1Pcod) cluster(admin2Pcod cluster_id)
				est store d`n'		
		}
		
		local m =`m'+1
		
		outreg2 [*1 *2 *3] using "${resultdir}first_stage_regression_subset_`y'new_`date'.xls", dec(3) replace label keep (ltcovm_1021_dist10 c.ltcovm_1021_dist10#c.GSMYEAR) stats(coef se tstat) nocons title (Table `m': First stage regression between mobile internet coverage and lightning coverage in `y' (excluding northern part)) addnote ("Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature")
		
	
	
	*rural vs urban 
	
	local n = 0
		
		est clear
		
		foreach bfd in 10 30 50{
			
			local n = `n' + 1
			
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==0, noabsorb cluster(cluster_id)
				est store a`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==0, a(admin1Pcod) cluster(cluster_id)
				est store b`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==0, noabsorb cluster(admin2Pcod cluster_id) 
				est store c`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==0, a(admin1Pcod) cluster(admin2Pcod cluster_id)
				est store d`n'		
		}
		
		local m =`m'+1
		
		outreg2 [*1 *2 *3] using "${resultdir}first_stage_regression_rural_`y'new_`date'.xls", dec(3) replace label keep (ltcovm_1021_dist10 c.ltcovm_1021_dist10#c.GSMYEAR) stats(coef se tstat) nocons title (Table `m': First stage regression between mobile internet coverage and lightning coverage in `y' (rural)) addnote ("Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature")
		
	
	
	local n = 0
		
		est clear
		
		foreach bfd in 10 30 50{
			
			local n = `n' + 1
			
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==1, noabsorb cluster(cluster_id)
				est store a`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==1, a(admin1Pcod) cluster(cluster_id)
				est store b`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==1, noabsorb cluster(admin2Pcod cluster_id) 
				est store c`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==1, a(admin1Pcod) cluster(admin2Pcod cluster_id)
				est store d`n'		
		}
		
		local m =`m'+1
		
		outreg2 [*1 *2 *3] using "${resultdir}first_stage_regression_urban_`y'new_`date'.xls", dec(3) replace label keep (ltcovm_1021_dist10 c.ltcovm_1021_dist10#c.GSMYEAR) stats(coef se tstat) nocons title (Table `m': First stage regression between mobile internet coverage and lightning coverage in `y' (urban)) addnote ("Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature")
		
	}
	
	
	***************************************
	*regression when pooling 2013 and 2018*
	***************************************
	
	*Full sample
	
	local n = 0
		
		est clear
		
		foreach bfd in 10 30 50{
			
			local n = `n' + 1
			
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018) , noabsorb cluster(cluster_id)
				est store a`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018) , a(admin1Pcod DHSYEAR) cluster(cluster_id)
				est store b`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018) , noabsorb cluster(admin2Pcod cluster_id) 
				est store c`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018) ,  a(admin1Pcod GSMYEAR) cluster(admin2Pcod cluster_id) 
				est store d`n'	
			reghdfe GSMCOVER_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018) , noabsorb cluster(cluster_id)
				est store e`n'
			reghdfe GSMCOVER_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018) , a(admin1Pcod DHSYEAR) cluster(cluster_id) 
				est store f`n'
			reghdfe GSMCOVER_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  , noabsorb cluster(admin2Pcod cluster_id) 
				est store g`n'
			reghdfe GSMCOVER_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018) ,  a(admin1Pcod GSMYEAR) cluster(admin2Pcod cluster_id) 
				est store h`n'
		}
		
		outreg2 [*1 *2 *3] using "${resultdir}first_stage_regression_poolnew_`date'.xls", dec(3) replace label keep (ltcovm_1021_dist10 c.ltcovm_1021_dist10#c.GSMYEAR) stats(coef se tstat) nocons ///
							 title ("Table 7: First stage regression between mobile internet coverage and lightning coverage") ///
							 addnote ("Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature")	
		
		*Excluding northern part
		
		local n = 0
		
		est clear
		
		foreach bfd in 10 30 50{
			
			local n = `n' + 1
			
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0, noabsorb cluster(cluster_id)
				est store a`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0, a(admin1Pcod DHSYEAR) cluster(cluster_id)
				est store b`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0, noabsorb cluster(admin2Pcod cluster_id) 
				est store c`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0,  a(admin1Pcod GSMYEAR) cluster(admin2Pcod cluster_id) 
				est store d`n'	
			reghdfe GSMCOVER_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0, noabsorb cluster(cluster_id)
				est store e`n'
			reghdfe GSMCOVER_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0, a(admin1Pcod DHSYEAR) cluster(cluster_id)
				est store f`n'
			reghdfe GSMCOVER_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0, noabsorb cluster(admin2Pcod cluster_id) 
				est store g`n'
			reghdfe GSMCOVER_dist`bfd' c.ltcovm_1021_dist10#c.GSMYEAR $cov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018)  & northern ==0,  a(admin1Pcod GSMYEAR) cluster(admin2Pcod cluster_id) 
				est store h`n'	
		}
		
		outreg2 [*1 *2 *3] using "${resultdir}first_stage_regression_pool_subsetnew_`date'.xls", dec(3) replace label keep (ltcovm_1021_dist10 c.ltcovm_1021_dist10#c.GSMYEAR) stats(coef se tstat) nocons ///
							 title ("Table 8: First stage regression between mobile internet coverage and lightning coverage (excluding northern part)") ///
							addnote ("Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature")
		
	
	*rural vs urban 
	
	local n = 0
		
		est clear
		
		foreach bfd in 10 30 50{
			
			local n = `n' + 1
			
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==0, noabsorb cluster(cluster_id)
				est store a`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==0, a(admin1Pcod) cluster(cluster_id)
				est store b`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==0, noabsorb cluster(admin2Pcod cluster_id) 
				est store c`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==0, a(admin1Pcod) cluster(admin2Pcod cluster_id)
				est store d`n'		
		}
		
		local m =`m'+1
		
		outreg2 [*1 *2 *3] using "${resultdir}first_stage_regression_rural_poolnew_`date'.xls", dec(3) replace label keep (ltcovm_1021_dist10 c.ltcovm_1021_dist10#c.GSMYEAR) stats(coef se tstat) nocons title (Table `m': First stage regression between mobile internet coverage and lightning coverage in `y' (rural)) addnote ("Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature")
		
	
	
	local n = 0
		
		est clear
		
		foreach bfd in 10 30 50{
			
			local n = `n' + 1
			
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==1, noabsorb cluster(cluster_id)
				est store a`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==1, a(admin1Pcod) cluster(cluster_id)
				est store b`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==1, noabsorb cluster(admin2Pcod cluster_id) 
				est store c`n'
			reghdfe GSMCOVER_dist`bfd' ltcovm_1021_dist10 $cov [aw= wgt] if DHSYEAR==`y'  & place ==1, a(admin1Pcod) cluster(admin2Pcod cluster_id)
				est store d`n'		
		}
		
		local m =`m'+1
		
		outreg2 [*1 *2 *3] using "${resultdir}first_stage_regression_urban_poolnew_`date'.xls", dec(3) replace label keep (ltcovm_1021_dist10 c.ltcovm_1021_dist10#c.GSMYEAR) stats(coef se tstat) nocons title (Table `m': First stage regression between mobile internet coverage and lightning coverage in `y' (urban)) addnote ("Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature")
		
	
	
**# Bookmark #3 2SLS

	*************************************************************
				*Effect on Phone own and Internet use*
	*************************************************************	
	
	use "${dhsdir}analysis.dta",replace
	global vcov age i.highest_education wealth_index place
	global cov wind_m_l1 Precipatation_s_l1 vapour_m_l1 solar_m_l1 temair_m_l1 rain_s_l1 Elevation  //lagged weather variables

	local date : di %tcDD-NN-CCYY c(current_date)
	 
	*********************************
	 *regression in 2013 
	********************************
	
	*Full sample 
		
		est clear
		
		local n = 0
		
		foreach bfd in 10 30 50{
		
			local n = `n' + 1	
			
			reghdfe own_phone GSMCOVER_dist`bfd' $cov $vcov if GSMYEAR==2013, a(admin1Pcod) cluster(cluster_id)
			est store a`n'
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov if GSMYEAR==2013, a(admin1Pcod)  cluster(cluster_id) first savefirst savefprefix(st1)
			est store b`n'
			mat list e(first)
			local F2 = e(first)[4,1]	
			su own_phone  if e(sample)==1 & GSMCOVER_dist`bfd' ==0
			local control_mean = r(mean)
			
			if `n'==1{
			
				outreg2 [a`n' b`n']  using "${resultdir}ols&2sls_2013_`date'.xls", dec(3) replace label keep (GSMCOVER_dist`bfd') stats(coef se) nocons ///
								   title ("Table 1: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2013") ///
								   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
								   addstat(F_value, `F2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			}
			
			else{
				outreg2 [a`n' b`n'] using "${resultdir}ols&2sls_2013_`date'.xls", dec(3) append label keep (GSMCOVER_dist`bfd') stats(coef se) nocons ///
								   title ("Table 1: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2013") ///
								   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
								   addstat(F_value, `F2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			
			}
			
		}
		
		**esttab st1*, scalar (F2)
	
	
	*Excluding northern part
		
	preserve
	
	keep if northern ==0
				
		est clear
		
		local n = 0
		
		foreach bfd in 10 30 50{
		
			local n = `n' + 1	
			
			reghdfe own_phone GSMCOVER_dist`bfd' $cov $vcov if GSMYEAR==2013, a(admin1Pcod) cluster(cluster_id)
			est store a`n'
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov if GSMYEAR==2013, a(admin1Pcod) cluster(cluster_id) first savefirst savefprefix(st1)
			est store b`n'
			mat list e(first)
			local F2 = e(first)[4,1]	
			su own_phone  if e(sample)==1 & GSMCOVER_dist`bfd' ==0
			local control_mean = r(mean)
			if `n'==1{
			
				outreg2 [*`n']  using "${resultdir}ols&2sls_2013subset_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
								   title ("Table 1: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2013, exclusing northern part") ///
								   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
								   addstat(F_value, `F2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			}
			
			else{
				outreg2 [*`n'] using "${resultdir}ols&2sls_2013subset_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
								   title ("Table 1: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2013, exclusing northern part") ///
								   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
								   addstat(F_value, `F2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			
			}
			
		}
		
		**esttab st1*, scalar (F2)
	
	restore
	
	preserve
	
	keep if place ==0
				
		est clear
		
		local n = 0
		
		foreach bfd in 10 30 50{
		
			local n = `n' + 1	
			
			reghdfe own_phone GSMCOVER_dist`bfd' $cov $vcov if GSMYEAR==2013, a(admin1Pcod) cluster(cluster_id)
			est store a`n'
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov if GSMYEAR==2013, a(admin1Pcod)  cluster(cluster_id) first savefirst savefprefix(st1)
			est store b`n'
			mat list e(first)
			local F2 = e(first)[4,1]	
			su own_phone  if e(sample)==1 & GSMCOVER_dist`bfd' ==0
			local control_mean = r(mean)
			if `n'==1{
			
				outreg2 [*`n']  using "${resultdir}ols&2sls_2013rural_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
								   title ("Table 1: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2013, rural") ///
								   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
								    addstat(F_value, `F2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			}
			
			else{
				outreg2 [*`n'] using "${resultdir}ols&2sls_2013rural_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
								   title ("Table 1: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2013, rural") ///
								   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
								    addstat(F_value, `F2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			
			}
			
		}
		
		**esttab st1*, scalar (F2)
	
	restore
	
	preserve
	
	keep if place ==1
					
		est clear
		
		local n = 0
		
		foreach bfd in 10 30 50{
		
			local n = `n' + 1	
			
			reghdfe own_phone GSMCOVER_dist`bfd' $cov $vcov if GSMYEAR==2013, a(admin1Pcod) cluster(cluster_id)
			est store a`n'
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov if GSMYEAR==2013, a(admin1Pcod)  cluster(cluster_id) first savefirst savefprefix(st1)
			est store b`n'
			mat list e(first)
			local F2 = e(first)[4,1]	
			su own_phone  if e(sample)==1 & GSMCOVER_dist`bfd' ==0
			local control_mean = r(mean)
			if `n'==1{
			
				outreg2 [*`n']  using "${resultdir}ols&2sls_2013urban_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
								   title ("Table 1: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2013, rural") ///
								   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
								    addstat(F_value, `F2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			}
			
			else{
				outreg2 [*`n'] using "${resultdir}ols&2sls_2013urban_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
								   title ("Table 1: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2013, rural") ///
								   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
								    addstat(F_value, `F2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			
			}
			
		}
	
	restore
	*********************************
	 *regression in 2018
	********************************
	
	*Full sample
		
		est clear
		
		local n = 0
		
		foreach bfd in 10 30 50{
		
			local n = `n' + 1	
			
			reghdfe own_phone GSMCOVER_dist`bfd' $cov $vcov if GSMYEAR==2018, a(admin1Pcod) cluster(cluster_id)
			est store a`n'			
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov if GSMYEAR==2018, a(admin1Pcod) cluster(cluster_id) first savefirst savefprefix(st1)
			est store b`n'
			mat list e(first)
			local F2_1 = e(first)[4,1]	
			
			reghdfe use_internet_s GSMCOVER_dist`bfd' $cov $vcov if GSMYEAR==2018, a(admin1Pcod) cluster(cluster_id)
			est store c`n'
			ivreghdfe use_internet_s (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov if GSMYEAR==2018, a(admin1Pcod) cluster(cluster_id) first savefirst savefprefix(st1)
			est store d`n'
			mat list e(first)
			local F2_2 = e(first)[4,1]	
			su own_phone  if e(sample)==1 & GSMCOVER_dist`bfd' ==0
			local control_mean = r(mean)
			
			
			if `n'==1{
				outreg2 [*`n'] using "${resultdir}ols&2sls_2018_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table 2: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2018") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						   addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			}
			else{
			   outreg2 [*`n'] using "${resultdir}ols&2sls_2018_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table 2: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2018") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						   addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			}
		}

		
		
	*esttab st1* , scalar (F2)
	
	
	*Excluding northern part 
	
	preserve
	
	keep if northern ==0
				
				est clear
		
		local n = 0
		
		foreach bfd in 10 30 50{
		
			local n = `n' + 1	
			
			reghdfe own_phone GSMCOVER_dist`bfd' $cov $vcov if GSMYEAR==2018, a(admin1Pcod) cluster(cluster_id)
			est store a`n'			
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov if GSMYEAR==2018, a(admin1Pcod) cluster(cluster_id) first savefirst savefprefix(st1)
			est store b`n'
			mat list e(first)
			local F2_1 = e(first)[4,1]	
			su own_phone  if e(sample)==1 & GSMCOVER_dist`bfd' ==0
			local control_mean = r(mean)
			reghdfe use_internet_s GSMCOVER_dist`bfd' $cov $vcov if GSMYEAR==2018, a(admin1Pcod) cluster(cluster_id)
			est store c`n'
			ivreghdfe use_internet_s (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov if GSMYEAR==2018, a(admin1Pcod) cluster(cluster_id) first savefirst savefprefix(st1)
			est store d`n'
			mat list e(first)
			local F2_2 = e(first)[4,1]	
			su own_phone  if e(sample)==1 & GSMCOVER_dist`bfd' ==0
			local control_mean = r(mean)
			if `n'==1{
				outreg2 [*`n'] using "${resultdir}ols&2slssubset_2018_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table 2: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2018, exclusing northern part") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						   addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			}
			else{
			   outreg2 [*`n'] using "${resultdir}ols&2slssubset_2018_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table 2: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2018, exclusing northern part") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						   addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			}
		}

		
	*esttab st1* , scalar (F2)
	restore
	
	preserve
	
	keep if place ==0
				
		est clear
		
		local n = 0
		
		foreach bfd in 10 30 50{
		
			local n = `n' + 1	
			
			reghdfe own_phone GSMCOVER_dist`bfd' $cov $vcov if GSMYEAR==2018, a(admin1Pcod) cluster(cluster_id)
			est store a`n'
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov if GSMYEAR==2018, a(admin1Pcod) cluster(cluster_id) first savefirst savefprefix(st1)
			est store b`n'
			mat list e(first)
			local F2_1 = e(first)[4,1]	
			mat list e(first)
			local F2_2 = e(first)[4,1]	
			su own_phone  if e(sample)==1 & GSMCOVER_dist`bfd' ==0
			local control_mean = r(mean)
			if `n'==1{
			
				outreg2 [a`n' b`n']  using "${resultdir}ols&2sls_2018rural_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
								   title ("Table 1: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2018, rural") ///
								   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
								   addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			}
			
			else{
				outreg2 [a`n' b`n'] using "${resultdir}ols&2sls_2018rural_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
								   title ("Table 1: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2018, rural") ///
								   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
								   addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			
			}
			
		}
		
		**esttab st1*, scalar (F2)
	
	restore
	
	preserve
	
	keep if place ==1
				
		est clear
		
		local n = 0
		
		foreach bfd in 10 30 50{
		
			local n = `n' + 1	
			
			reghdfe own_phone GSMCOVER_dist`bfd' $cov $vcov  if GSMYEAR==2018, a(admin1Pcod) cluster(cluster_id)
			est store a`n'
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov if GSMYEAR==2018, a(admin1Pcod) cluster(cluster_id) first savefirst savefprefix(st1)
			est store b`n'
			mat list e(first)
			local F2_1 = e(first)[4,1]	
			mat list e(first)
			local F2_2 = e(first)[4,1]	
			su own_phone  if e(sample)==1 & GSMCOVER_dist`bfd' ==0
			local control_mean = r(mean)
			if `n'==1{
			
				outreg2 [a`n' b`n']  using "${resultdir}ols&2sls_2018urban_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
								   title ("Table 1: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2018, urban") ///
								   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
								   addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			}
			
			else{
				outreg2 [a`n' b`n'] using "${resultdir}ols&2sls_2018urban_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
								   title ("Table 1: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage in 2018, urban") ///
								   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
								  addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
			
			}
			
		}
		
		**esttab st1*, scalar (F2)
	
	restore
	
	***************************************
	*regression when pooling 2013 and 2018
	***************************************
	
	*Full sample 

		est clear
		
		local n = 0
		
		foreach bfd in 10 30 50{
		
		local n = `n' + 1	
						
			reghdfe own_phone GSMCOVER_dist`bfd' $cov $vcov if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod DHSYEAR) cluster(cluster_id)
			est store a`n'			
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod DHSYEAR) cluster(cluster_id) first savefirst savefprefix(st1)
			est store b`n'
			mat list e(first)
			local F2_1 = e(first)[4,1]	
			su own_phone  if e(sample)==1 & GSMCOVER_dist`bfd' ==0
			local control_mean = r(mean)
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=c.ltcovm_1021_dist10#c.GSMYEAR) $cov $vcov if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod  GSMYEAR) cluster(cluster_id) first savefirst savefprefix(st2)
			est store c`n'
			mat list e(first)
			local F2_2 = e(first)[4,1]	
			
		
		if `n'==1{
		
		outreg2 [a`n' b`n' c`n'] using "${resultdir}ols&2sls_pool_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table 3: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect and year fixed-effect are included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						   addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
		}
		
		else{
		outreg2 [a`n' b`n' c`n'] using "${resultdir}ols&2sls_pool_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table 3: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect and year fixed-effect are included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						  addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
		}
	
	}
	*esttab st1*, scalar (F2_1 F2_2)
		
		
	*Excluding northern part
		
	preserve
		
	keep if northern ==0
			

		est clear
		
		local n = 0
		
		foreach bfd in 10 30 50{
		
		local n = `n' + 1	
						
			reghdfe own_phone GSMCOVER_dist`bfd' $cov $vcov if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod DHSYEAR)
			est store a`n'			
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod DHSYEAR) first savefirst savefprefix(st1)
			est store b`n'
			mat list e(first)
			local F2_1 = e(first)[4,1]	
			su own_phone  if e(sample)==1 & GSMCOVER_dist`bfd' ==0
			local control_mean = r(mean)
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=c.ltcovm_1021_dist10#c.GSMYEAR) $cov $vcov if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod  GSMYEAR) cluster(cluster_id) first savefirst savefprefix(st2)
			est store c`n'
			mat list e(first)
			local F2_2 = e(first)[4,1]	
			
		
		if `n'==1{
		
		outreg2 [a`n' b`n' c`n'] using "${resultdir}ols&2sls_pool_subset`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table 3: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage, exclusing northern part") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect and year fixed-effect are included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						   addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
		}
		
		else{
		outreg2 [a`n' b`n' c`n'] using "${resultdir}ols&2sls_pool_subset`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table 3: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage, exclusing northern part") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect and year fixed-effect are included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						  addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
		}
	
	}
	*esttab st1*, scalar (F2_1 F2_2)
	restore
	
	preserve
	
	keep if place ==0
				
		est clear
		
		local n = 0
		
		foreach bfd in 10 30 50{
		
		local n = `n' + 1	
						
			reghdfe own_phone GSMCOVER_dist`bfd' $cov $vcov if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod DHSYEAR) cluster(cluster_id)
			est store a`n'			
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod DHSYEAR) cluster(cluster_id) first savefirst savefprefix(st1)
			est store b`n'
			mat list e(first)
			local F2_1 = e(first)[4,1]	
			su own_phone  if e(sample)==1 & GSMCOVER_dist`bfd' ==0
			local control_mean = r(mean)
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=c.ltcovm_1021_dist10#c.GSMYEAR) $cov $vcov if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod  GSMYEAR) cluster(cluster_id) first savefirst savefprefix(st2)
			est store c`n'
			mat list e(first)
			local F2_2 = e(first)[4,1]	
			
		
		if `n'==1{
		
		outreg2 [a`n' b`n' c`n'] using "${resultdir}ols&2sls_pool_rural_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table 3: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage,rural") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect and year fixed-effect are included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						   addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
		}
		
		else{
		outreg2 [a`n' b`n' c`n'] using "${resultdir}ols&2sls_pool_rural_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table 3: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage,rural") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect and year fixed-effect are included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						  addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
		}
	
	}
		
		**esttab st1*, scalar (F2)
	
	restore
	
	preserve
	
	keep if place ==1
				
		est clear
		
		local n = 0
		
		foreach bfd in 10 30 50{
		
		local n = `n' + 1	
						
			reghdfe own_phone GSMCOVER_dist`bfd' $cov $vcov if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod DHSYEAR) cluster(cluster_id)
			est store a`n'			
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod DHSYEAR) cluster(cluster_id) first savefirst savefprefix(st1)
			est store b`n'
			mat list e(first)
			local F2_1 = e(first)[4,1]	
			su own_phone  if e(sample)==1 & GSMCOVER_dist`bfd' ==0
			local control_mean = r(mean)
			ivreghdfe own_phone (GSMCOVER_dist`bfd'=c.ltcovm_1021_dist10#c.GSMYEAR) $cov $vcov if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod  GSMYEAR) cluster(cluster_id) first savefirst savefprefix(st2)
			est store c`n'
			mat list e(first)
			local F2_2 = e(first)[4,1]	
			
		
		if `n'==1{
		
		outreg2 [a`n' b`n' c`n'] using "${resultdir}ols&2sls_pool_urban_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table 3: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage, urban") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect and year fixed-effect are included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						   addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
		}
		
		else{
		outreg2 [a`n' b`n' c`n'] using "${resultdir}ols&2sls_pool_urban_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table 3: Imapct of Mobile Internet Coverage on Mobile Phone and Internet Usage, urban") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect and year fixed-effect are included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						  addstat(F_value1, `F2_1',F_value2, `F2_2',control_mean(GSMCOVER=0),`control_mean') ctitle("bfd=`bfd'")
		}
	
	}
		
		**esttab st1*, scalar (F2)
	
	restore

	*************************************************************
				*Effect on outcomes*
	*************************************************************	
		
	use "${dhsdir}analysis.dta",replace
	global vcov age i.highest_education wealth_index place
	global cov wind_m_l1 Precipatation_s_l1 vapour_m_l1 solar_m_l1 temair_m_l1 rain_s_l1 Elevation  //lagged weather variables

	local date : di %tcDD-NN-CCYY c(current_date)
	
	*global repro childnum_dum childnum_under5_dum child_live_num_dum daughter_live daughters_livehome_num daughters_liveaway_num sons_live sons_livehome_num sons_liveaway_num birthnum_5y_dum birthnum_3y_dum birthnum_1y_dum child_1st

	*infor_receive emply contra repro fertility fgc
	*********************************
	 *regression in 2013 or 2018
	********************************
	
	*Full sample 
		
		est clear

		foreach y in 2013 2018{
	
		local n = 0
		
		local i = 0
		
			foreach m in  repro {
		
				foreach bfd in 50{
				
					local n = `n' + 1	
					
					foreach v in $`m'{
						
					local i =`i'+1
								
					reghdfe `v' GSMCOVER_dist`bfd' $cov $vcov [aw= wgt] if DHSYEAR==`y', a(admin1Pcod) cluster(cluster_id)
					est store a_`v'`n'
					ivreghdfe `v' (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov [aw= wgt] if DHSYEAR==`y', a(admin1Pcod) cluster(cluster_id) first savefirst savefprefix(st`n')
					est store b_`v'`n'
					*mat list e(first)
					local F2 = e(first)[4,1]
				
				
				if `i'==1{
					
						outreg2 [*`v'`n']  using "${resultdir}ols&2sls_`m'`y'new_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
										   title ("Table: Imapct of Mobile Internet Coverage on `m' in `y'") ///
										   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature; The model also controls for respondent's characteristics, including age, education level, household income level, and resident place is rural or urban.") ///
										   addstat(F_value, `F2')
					}
					
					else{
						outreg2 [*`v'`n'] using "${resultdir}ols&2sls_`m'`y'new_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
										   title ("Table: Imapct of Mobile Internet Coverage on `m' in `y'") ///
										   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature; The model also controls for respondent's characteristics, including age, education level, household income level, and resident place is rural or urban.") ///
										   addstat(F_value, `F2')
					
					}		
			}
		}
	}
 }	
	
	
	*Excluding northern part
		
	preserve
	keep if northern ==0

			est clear

		foreach y in 2013 2018{
	
		local n = 0
		
		local i = 0
		
			foreach m in repro{
		
				foreach bfd in 50{
				
					local n = `n' + 1	
					
					foreach v in $`m'{
						
					local i =`i'+1
								
					reghdfe `v' GSMCOVER_dist`bfd' $cov $vcov [aw= wgt] if DHSYEAR==`y', a(admin1Pcod) cluster(cluster_id)
					est store a_`v'`n'
					ivreghdfe `v' (GSMCOVER_dist`bfd'=ltcovm_1021_dist10) $cov $vcov [aw= wgt] if DHSYEAR==`y', a(admin1Pcod) cluster(cluster_id) first savefirst savefprefix(st`n')
					est store b_`v'`n'
					*mat list e(first)
					local F2 = e(first)[4,1]
				
				
				if `i'==1{
					
						outreg2 [*`v'`n']  using "${resultdir}ols&2slssubset_`m'`y'new_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
										   title ("Table: Imapct of Mobile Internet Coverage on `m' in `y'") ///
										   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature; The model also controls for respondent's characteristics, including age, education level, household income level, and resident place is rural or urban.") ///
										   addstat(F_value, `F2')
					}
					
					else{
						outreg2 [*`v'`n'] using "${resultdir}ols&2slssubset_`m'`y'new_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
										   title ("Table `m': Imapct of Mobile Internet Coverage on `m' in `y'") ///
										   addnote ("Standard Error is clustered at cluster level; State fixed-effect is included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature; The model also controls for respondent's characteristics, including age, education level, household income level, and resident place is rural or urban.") ///
										   addstat(F_value, `F2')
					
					}		
			}
		}
	}
 }	
	
	
	restore
	
	***************************************
	*regression when pooling 2013 and 2018
	***************************************
	
	*Full sample

		est clear
		
		local i =0 	
		 
		foreach m in repro{
		
			foreach v in $`m'{
				
				local i = `i'+1
				
				reghdfe `v' GSMCOVER_dist50 $cov $vcov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod DHSYEAR) cluster(cluster_id)
				est store a`v'`n'			
				ivreghdfe `v' (GSMCOVER_dist50=ltcovm_1021_dist10) $cov $vcov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod DHSYEAR) cluster(cluster_id) first savefirst savefprefix(st`n'_1)
				est store b`v'`n'
				*mat list e(first)
				local F2_1 = e(first)[4,1]	
				ivreghdfe `v' (GSMCOVER_dist50=c.ltcovm_1021_dist10#c.GSMYEAR) $cov $vcov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod  GSMYEAR) cluster(cluster_id) first savefirst savefprefix(st`n'_2)
				est store c`v'`n'
				*mat list e(first)
				local F2_2 = e(first)[4,1]
				
			if `i'==1 {
		
		outreg2 [*`v'`n'] using "${resultdir}ols&2sls_`m'_poolnew_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table: Imapct of Mobile Internet Coverage on `m'") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect and year fixed-effect are included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						   addstat(F_value1, `F2_1',F_value2, `F2_2')
		}
		
		else{
		outreg2 [*`v'`n'] using "${resultdir}ols&2sls_`m'_poolnew_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table: Imapct of Mobile Internet Coverage on `m'") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect and year fixed-effect are included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						   addstat(F_value1, `F2_1',F_value2, `F2_2')
			}
	
		}
	}
		
		
		
	*Excluding northern part
		
	preserve
		
	keep if northern ==0
		
		est clear
		
		local i =0 	
		 
		foreach m in repro{
		
			foreach v in $`m'{
				
				local i = `i'+1
				
				reghdfe `v' GSMCOVER_dist50 $cov $vcov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod DHSYEAR) cluster(cluster_id)
				est store a`v'`n'			
				ivreghdfe `v' (GSMCOVER_dist50=ltcovm_1021_dist10) $cov $vcov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod DHSYEAR) cluster(cluster_id) first savefirst savefprefix(st`n'_1)
				est store b`v'`n'
				*mat list e(first)
				local F2_1 = e(first)[4,1]	
				ivreghdfe `v' (GSMCOVER_dist50=c.ltcovm_1021_dist10#c.GSMYEAR) $cov $vcov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod  GSMYEAR) cluster(cluster_id) first savefirst savefprefix(st`n'_2)
				est store c`v'`n'
				*mat list e(first)
				local F2_2 = e(first)[4,1]
				
			if `i'==1 {
		
		outreg2 [*`v'`n'] using "${resultdir}ols&2slssubset_`m'_poolnew_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table: Imapct of Mobile Internet Coverage on `m'") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect and year fixed-effect are included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						   addstat(F_value1, `F2_1',F_value2, `F2_2')
		}
		
		else{
		outreg2 [*`v'`n'] using "${resultdir}ols&2slssubset_`m'_poolnew_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table: Imapct of Mobile Internet Coverage on `m'") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect and year fixed-effect are included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						   addstat(F_value1, `F2_1',F_value2, `F2_2')
			}
	
		}
	}
		
		
	*esttab st*, scalar (F2_1 F2_2)
	restore


	
	*final tables
	use "${dhsdir}analysis.dta",replace
	global vcov age i.highest_education wealth_index place
	global cov wind_m_l1 Precipatation_s_l1 vapour_m_l1 solar_m_l1 temair_m_l1 rain_s_l1 Elevation  //lagged weather variables

	local date : di %tcDD-NN-CCYY c(current_date)

	global var own_phone _dum $infor_receive ideal_num_dum decide_use_conctra empl_current empl_year self_empl  circumcised_stop
	
	
	est clear
				
		local n =0 
		local i =0 	
		 
		 foreach v in var {
		 
		 local n = `n'+1

			foreach bfd in 10 30 50{ 	
				
				local i=`i'+1
				
				reghdfe `v' GSMCOVER_dist`bfd' $cov $vcov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod DHSYEAR) cluster(cluster_id)
				est store a_`v'`n'		
				ivreghdfe `v' (GSMCOVER_dist`bfd' =ltcovm_1021_dist10) $cov $vcov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod DHSYEAR) cluster(cluster_id) first savefirst savefprefix(st`n'_1)
				est store b_`v'`n'
				*mat list e(first)
				local F2_1 = e(first)[4,1]	
				ivreghdfe `v' (GSMCOVER_dist`bfd' =c.ltcovm_1021_dist10#c.GSMYEAR) $cov $vcov [aw= wgt] if (DHSYEAR==2013|DHSYEAR==2018), a(admin1Pcod  GSMYEAR) cluster(cluster_id) first savefirst savefprefix(st`n'_2)
				est store c_`v'`n'
				*mat list e(first)
				local F2_2 = e(first)[4,1]
				
			if `i'==1 {
		
		outreg2 [*`v'`n'] using "${resultdir}ols&2sls_var_poolnew_`date'.xls", dec(3) replace label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table: Imapct of Mobile Internet Coverage on `var'") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect and year fixed-effect are included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						   addstat(F_value1, `F2_1',F_value2, `F2_2')
		}
		
		else{
		outreg2 [*`v'`n'] using "${resultdir}ols&2sls_var_poolnew_`date'.xls", dec(3) append label keep (GSMCOVER_dist*) stats(coef se) nocons ///
						   title ("Table: Imapct of Mobile Internet Coverage on `var'") ///
						   addnote ("Standard Error is clustered at cluster level; State fixed-effect and year fixed-effect are included; Climate covariates include precipitation, solar radiation, wind speed, vapour pressure, and temperature") ///
						   addstat(F_value1, `F2_1',F_value2, `F2_2')
			}
	
		}
	}
}	

*************************************************************
				*Descriptive Figs*
*************************************************************
******************************************************
*mobile phone ownship and GSM scatter in 2013 and 2018
*****************************************************
use "${dhsdir}analysis.dta",replace
local date : di %tcDD-NN-CCYY c(current_date)
rename v024 region
bysort region: egen own_phone _rate = mean(own_phone _dum)
bysort region: egen GSMCOVER_dist10_s = total (own_phone _dum)

twoway ///
    (scatter GSMCOVER_dist10_s own_phone _rate if DHSYEAR==2013, mlabel(region) subtitle(2013)) ///
    (lfit GSMCOVER_dist10_s own_phone _rate if DHSYEAR==2013), ///
    ytitle("Number of Mobile Cellular Tower within 10") ///
	xtitle("Rate of Mobile Phone Ownership") ///
    legend(off) ///
	scale(.8)
graph save "${resultdir}graph1.gph",replace

twoway ///
    (scatter GSMCOVER_dist10_s own_phone _rate if DHSYEAR==2018, mlabel(region) subtitle(2018)) ///
    (lfit GSMCOVER_dist10_s own_phone _rate if DHSYEAR==2018), ///
    ytitle("Number of Mobile Cellular Tower within 10") ///
	xtitle("Rate of Mobile Phone Ownership") ///
    legend(off) ///
	scale(.8)
graph save "${resultdir}graph2.gph",replace 

gr combine "${resultdir}graph1.gph" "${resultdir}graph2.gph", ycommon note("Source: DHS and GSMA in 2013 and 2018", size(vsmall)) 
gr save "${results}comb.gph", replace
gr export "${results}comb.png", replace

*****************************************************
*mobile phone ownship and GSM scatter in 2013 and 2018
*****************************************************
use "${dhsdir}analysis.dta",replace
local date : di %tcDD-NN-CCYY c(current_date)
rename v024 region
bysort region: egen own_phone _rate = mean(own_phone _dum)
bysort region: egen GSMCOVER_dist10_s = total (own_phone _dum)

twoway ///
    (scatter GSMCOVER_dist10_s own_phone _rate if DHSYEAR==2013, mlabel(region) subtitle(2013)) ///
    (lfit GSMCOVER_dist10_s own_phone _rate if DHSYEAR==2013), ///
    ytitle("Number of Mobile Cellular Tower within 10") ///
	xtitle("Rate of Mobile Phone Ownership") ///
    legend(off) ///
	scale(.8)
graph save "${resultdir}graph1.gph",replace

twoway ///
    (scatter GSMCOVER_dist10_s own_phone _rate if DHSYEAR==2018, mlabel(region) subtitle(2018)) ///
    (lfit GSMCOVER_dist10_s own_phone _rate if DHSYEAR==2018), ///
    ytitle("Number of Mobile Cellular Tower within 10") ///
	xtitle("Rate of Mobile Phone Ownership") ///
    legend(off) ///
	scale(.8)
graph save "${resultdir}graph2.gph",replace 

gr combine "${resultdir}graph1.gph" "${resultdir}graph2.gph", ycommon note("Source: DHS and GSMA in 2013 and 2018", size(vsmall)) 
gr save "${resultdir}comb.gph", replace
gr export "${resultdir}comb.png", replace

*****************************************************
*mobile phone ownship and GSM scatter in 2018
*****************************************************
use "${dhsdir}analysis.dta",replace
	global vcov age i.highest_education wealth_index place
	global cov wind_m_l1 Precipatation_s_l1 vapour_m_l1 solar_m_l1 temair_m_l1 rain_s_l1 Elevation  //lagged weather variables

local date : di %tcDD-NN-CCYY c(current_date)
rename v024 region
bysort region DHSYEAR: egen own_phone _rate = mean(own_phone _dum)
bysort region DHSYEAR: egen GSMCOVER_dist10_s = total (GSMCOVER_dist10)
bysort region DHSYEAR: gen n=_n
keep if n==1

twoway ///
    (scatter GSMCOVER_dist10_s own_phone _rate if DHSYEAR==2013, mlabel(region) mlabsize(small) mlabposition (12) subtitle(2013)) ///
    (lfit GSMCOVER_dist10_s own_phone _rate if DHSYEAR==2013), ///
    ytitle("Number of Mobile Cellular Tower within 10 km") ///
	xtitle("Rate of Mobile Phone Ownership") ///
    legend(off) ///
	scale(.7)
graph save "${resultdir}own_phone _2013.gph",replace

twoway ///
    (scatter GSMCOVER_dist10_s own_phone _rate if DHSYEAR==2018, mlabel(region) mlabsize(small)  mlabposition (12) subtitle(2018)) ///
    (lfit GSMCOVER_dist10_s own_phone _rate if DHSYEAR==2018), ///
    ytitle("Number of Mobile Cellular Tower within 10 km") ///
	xtitle("Rate of Mobile Phone Ownership") ///
    legend(off) ///
	scale(.7)
graph save "${resultdir}own_phone _2018.gph",replace 

gr combine "${resultdir}own_phone _2013.gph" "${resultdir}own_phone _2018.gph", ycommon note("Source: DHS and GSMA in 2013 and 2018", size(vsmall)) 
gr save "${resultdir}own_phone .gph", replace
gr export "${resultdir}own_phone .png", replace

*****************************************************
*Internet use and GSM scatter in 2018
*****************************************************
use "${dhsdir}analysis.dta",replace
	global vcov age i.highest_education wealth_index place
	global cov wind_m_l1 Precipatation_s_l1 vapour_m_l1 solar_m_l1 temair_m_l1 rain_s_l1 Elevation  //lagged weather variables

local date : di %tcDD-NN-CCYY c(current_date)
keep if DHSYEAR==2018
rename v024 region
bysort region: egen use_internet_rate = mean(use_internet_dum)
bysort region: egen GSMCOVER_dist10_s = total (GSMCOVER_dist10)
bysort region: gen n=_n
keep if n==1

twoway ///
    (scatter GSMCOVER_dist10_s use_internet_rate, mlabel(region)) ///
    (lfit GSMCOVER_dist10_s use_internet_rate), ///
    ytitle("Number of Mobile Cellular Tower within 10 km") ///
	xtitle("Rate of Internet Usage") ///
	caption("Source: DHS and GSMA in 2018", size(small)) ///
	subtitle(2018) ///
    legend(off) ///
	scale(.8)

graph save "${resultdir}use_internet.gph",replace 
gr export "${resultdir}use_internet.png", replace

****************************************************************
***Descriptive************
****************************************************************
use "${dhsdir}analysis.dta",replace
gen no_edu= 0
	replace no_edu =1 if highest_education==0
	label var no_edu "No education"
gen pri_edu=0
	replace pri_edu =1 if highest_education==1
	label var pri_edu "Primary School"
gen sec_edu=0
	replace sec_edu=1 if highest_education==2
	label var sec_edu "Secondary School"
gen hig_edu=0
	replace hig_edu=1 if highest_education==3
	label var hig_edu "Higher School"

gen north_central =0
	replace north_central =1 if v024==1
	label var north_central "North Central"
gen north_east =0
	replace north_east =1 if v024==2
	label var  north_east "North East"
gen north_west =0
	replace north_west =1 if v024==3
	label var north_west "North West"
gen south_east =0
	replace  south_east =1 if v024==4
	label var south_east "South East"
gen south =0
	replace south =1 if v024==5
	label var south "South"
gen south_west =0
	replace south_west =1 if v024==6
	label var south_west "South West"
	
recode v119 v120 v121 v122 v123 v124 v125 (7=.), gen(v119_d v120_d v121_d v122_d v123_d v124_d v125_d)
label var v119_d "Electricity"
label var v120_d "Radio"
label var v121_d "Television"
label var v122_d "Refrigerator"
label var v123_d "Bicycle"
label var v124_d "Motorcycle"
label var v125_d "Car/Truck"

recode hv243a (9=.), gen (family_own_phone )
label var family_own_phone  "Household has mobile phone"
rename place urban
label var urban urban

svyset caseid [pweight=iweight], strata(cluster_id)
asdoc svy: sum age no_edu pri_edu sec_edu hig_edu v119_d v120_d v121_d v122_d v123_d v124_d v125_d own_phone _dum family_own_phone  north_central north_east north_west south_east south south_west use_internet_dum  if urban ==0, stat(mean sd max min) replace label dec(3) ///
	 save(${resultdir}feb28_table1.doc) title(Table 1. Descriptive statistics) ///
	 add(Data Sources: Source: Author's survey)
asdoc svy: sum age no_edu pri_edu sec_edu hig_edu v119_d v120_d v121_d v122_d v123_d v124_d v125_d own_phone _dum family_own_phone  north_central north_east north_west south_east south south_west use_internet_dum if urban ==1, stat(mean sd max min) append label dec(3) ///
	 save(${resultdir}feb28_table1.doc) title(Table 1. Descriptive statistics) ///
	 add(Data Sources: Source: Author's survey)

*******************************************
		*online activity*
******************************************
*mobile app
*v169a v169b v171a v171b V384D MV169A MV169B MV171A MV171B MV384D
  codebook v169b v171a v171b v384d 
  codebook v384d h32n_3 h32n_3 h32n_4 h32n_5 h32n_6 v762ad v762an v762bd v762bn v770d v770n v784d v784n
*health intervention
*online

 *******************************************
		*effect on rural/urban*
 *******************************************
 *own mobile phone
 *household own mobile phone
 *use internet
 *knowledge
 