/*****INNOVATION/IMITATION*****/

EQUATION("Firm_Frontier_Productivity")
/*
The new productivity is the maximum among the previous one and the ones possibly obtained imitation and innovation.  
*/
	v[0]=VL("Firm_Frontier_Productivity", 1);       //frontier productivity of the firm in the last period
	v[1]=V("Firm_Imitation_Productivity");          //productivity achievied with imitation in that period
	v[2]=V("Firm_Innovation_Productivity");         //productivity achievied with innovation in that period
	v[3]=max(v[0],max(v[1],v[2]));             		//current frontier productivity is the maximum between the three
RESULT(v[3])


EQUATION("Firm_Quality")
/*
The new quality is the maximum among the previous one and the ones possibly obtained imitation and innovation. 
*/
	v[0]=VL("Firm_Quality", 1);       				//frontier quality of the firm in the last period
	v[1]=V("Firm_Imitation_Quality");          		//quality achievied with imitation in that period
	v[2]=V("Firm_Innovation_Quality");         		//quality achievied with innovation in that period
	v[3]=max(v[0],max(v[1],v[2]));        			//current frontier quality is the maximum between the three
RESULT(v[3])


EQUATION("Firm_Imitation_Productivity")
/*
Imitation process. The sucess depends on the amount of recources alocated to imitation. Firms search for best productivity and best quality of the sector, trying to copy if succeded.
*/
	v[0]=V("Firm_RND_Expenses");                    //firm's RND expenses
	v[1]=V("sector_innovation_proportion");    		//firm's share of RND expenses destinated to innovation
	v[2]=(v[0]*(1-v[1]));                           //amount of recources for imitation
	v[3]=1-exp(-v[2]);                   			//probability of success of the imitation depends on amount of recources available
	
	if(RND<v[3])                              		//draws a random number. if it is lower then imitation probability
     	v[4]=VL("Sector_Max_Productivity", 1);  	//imitation has succeded and the firm can copy the maximum probability of the sector in the last perio
  	else                                      		//if the random number is not lower than imitation probability
     	v[4]=0;                                 	//imitation failed and return a productivity zero
RESULT(v[4])


EQUATION("Firm_Innovation_Productivity")
/*
Innovation process. The sucess depends on the amount ou recources alocated to innovation. Firms search for new productivity and porduct quality and the result depends on a random distribution with exonegous parameters.
*/
	v[0]=V("Firm_RND_Expenses");                    //firm's RND expenses                       
	v[1]=V("sector_innovation_proportion");    		//firm's share of RND expenses destinated to innovation
	v[2]=(v[0]*v[1]);                           	//amount of recources for innovation
	v[3]=1-exp(-v[2]);                     			//probability of success of the innovation depends on the parameter and the amount of recources available  
	
	if(RND<v[3])                                	//draws a random nuumber. if it is lower then innovation probability 
		{
		v[4]=V("sector_std_dev_innovation");        //innovation standard deviation
		v[5]=V("sector_initial_productivity");		//initial frontier productivity
		v[7]=V("sector_tech_opportunity");         	//technological opportunity 
		v[8]=log(v[5])+(double)t*(v[7]);        	//the average of the innovation distribution will be the initial frontier productivity plus the opportunity parameter times the time period
		v[10]=exp(norm(v[8],v[4]));             	//the innovation productivity will be a draw from a normal distribution with average depending of the tech regime and std. dev fixed
		}
	else                                        	//if the random number is not lower then  the innovation probability
		v[10]=0;                                	//innovation failed and the productivity is zero
RESULT(v[10])


EQUATION("Firm_Imitation_Quality")
/*
Imitation process. The sucess depends on the amount of recources alocated to imitation. Firms search for best quality of the sector, trying to copy if succeded.
*/
	v[0]=V("Firm_RND_Expenses");                    //firm's RND expenses
	v[1]=V("sector_innovation_proportion");    		//firm's share of RND expenses destinated to innovation
	v[2]=(v[0]*(1-v[1]));                           //amount of recources for imitation
	v[3]=1-exp(-v[2]);                   			//probability of success of the imitation depends on amount of recources available
	
	if(RND<v[3])                              		//draws a random number. if it is lower then imitation probability
     	v[5]=VL("Sector_Max_Quality", 1);			//imitation has succeded and the firm can copy the maximum quality of the sector in the last period
  	else                                      		//if the random number is not lower than imitation probability
     	v[5]=0;										//imitation failed and return a quality zero
RESULT(v[5])


EQUATION("Firm_Innovation_Quality")
/*
Innovation process. The sucess depends on the amount ou recources alocated to innovation. Firms search for new quality and the result depends on a random distribution with exonegous parameters.
*/
	v[0]=V("Firm_RND_Expenses");                    //firm's RND expenses                       
	v[1]=V("sector_innovation_proportion");    		//firm's share of RND expenses destinated to innovation
	v[2]=(v[0]*v[1]);                           	//amount of recources for innovation
	v[3]=1-exp(-v[2]);                     			//probability of success of the innovation depends on the parameter and the amount of recources available  
	
	if(RND<v[3])                                	//draws a random nuumber. if it is lower then innovation probability 
		{
		v[4]=V("sector_std_dev_innovation");        //innovation standard deviation
		v[6]=V("sector_initial_quality");			//initial quality
		v[7]=V("sector_tech_opportunity");          //technological opportunity parameter
		v[9]=log(v[6])+(double)t*(v[7]);        	//the average of the innovation distribution will be the initial quality plus the opportunity parameter times the time period
		v[10]=exp(norm(v[9],v[4]));					//the innovation quality will be a draw from a normal distribution with average depending of the tech regime and std. dev fixed
		}
	else                                        	//if the random number is not lower then  the innovation probability
		v[10]=0;									//innovation failed and the quality is zero
RESULT(v[10])





//////////////////////////////////
// ALTERACAO IURI MONTEIRO ///////
//////////////////////////////////



///////////
///// EMISS�ES DE C02 DAS EMPRESAS COM BASE NA PRODU��O EFETIVA E DESPESAS COM P&D
//////////

EQUATION("Firm_CO2_Emissions")


/*
C�lculo das emiss�es de CO2 da empresa com base na produ��o, despesas de P&D, inova��o e imita��o.


CO2_Emissions = CO2_base * Firm_Effective_Production * 

(1 - (Firm_RND_Expenses / 100)) * (1 - Probabilidade de sucesso da inova��o) * 

(1 - Probabilidade de sucesso da imita��o)

*/

    v[0] = V("CO2_base");                              // Fator base de emiss�es de CO2 da empresa --> 1000
    v[1] = V("Firm_Effective_Production");             // Produ��o efetiva da empresa
    v[2] = V("Firm_RND_Expenses");                     // Despesas em P&D da empresa
    v[3] = V("sector_innovation_proportion");          // Propor��o de P&D destinada � inova��o
    v[8] = 100;                                        // Um valor m�ximo para normalizar o impacto do investimento em P&D

    // C�lculo da quantidade de recursos alocados para inova��o e imita��o
    v[9] = v[2] * v[3];                                // Recursos alocados para inova��o
    v[10] = v[2] * (1 - v[3]);                         // Recursos alocados para imita��o

    // C�lculo das probabilidades de sucesso
    v[11] = 1 - exp(-v[9]);                            // Probabilidade de sucesso da inova��o
    v[12] = 1 - exp(-v[10]);                           // Probabilidade de sucesso da imita��o

    // C�lculo das emiss�es de CO2 baseadas na produ��o, ajustadas por inova��o e imita��o
    v[13] = v[0] * v[1] * (1 - (v[2] / v[8])) * (1 - v[11]) * (1 - v[12]);

    v[13] = max(0, v[13]);                             // Emiss�es n�o negativas

RESULT(v[13])



///////////
///// EMISS�ES DE CO2 DAS EMPRESAS COM O IMPOSTO NA PRODU��O EFETIVA LEVANDO EM CONSIDERA��O AS EMISS�ES DE CO2
//////////


EQUATION("Firm_CO2_Emissions_Tax")
/*
C�lculo das emiss�es de CO2 da empresa com base na produ��o, despesas de P&D, inova��o e imita��o - IMPOSTO
*/
    v[0] = V("CO2_base");                                             // Fator base de emiss�es de CO2 da empresa   --> 1000
    v[1] = V("Firm_Effective_Production_Adjusted_with_CO2_Tax");      // Produ��o efetiva da empresa com o Imposto
    v[2] = V("Firm_RND_Expenses");                                    // Despesas em P&D da empresa
    v[3] = V("sector_innovation_proportion");                         // Propor��o de P&D destinada � inova��o
    v[8] = 100;                                                       // Um valor m�ximo para normalizar o impacto do investimento em P&D

    // C�lculo da quantidade de recursos alocados para inova��o e imita��o
    v[9] = v[2] * v[3];                                               // Recursos alocados para inova��o
    v[10] = v[2] * (1 - v[3]);                                        // Recursos alocados para imita��o

    // C�lculo das probabilidades de sucesso
    v[11] = 1 - exp(-v[9]);                                           // Probabilidade de sucesso da inova��o
    v[12] = 1 - exp(-v[10]);                                          // Probabilidade de sucesso da imita��o

    // C�lculo das emiss�es de CO2 baseadas na produ��o, ajustadas por inova��o e imita��o
    v[13] = v[0] * v[1] * (1 - (v[2] / v[8])) * (1 - v[11]) * (1 - v[12]);

    v[13] = max(0, v[13]);                                            // Emiss�es n�o negativas

RESULT(v[13])




EQUATION("Firm_CO2_Emissions_Subs")

/*
C�lculo das emiss�es de CO2 da empresa com base na produ��o, despesas de P&D ajustadas, inova��o e imita��o. - SUBS�DIO
*/

    v[0] = V("CO2_base");                                     // Fator base de emiss�es de CO2 da empresa
    v[1] = V("Firm_Effective_Production");                    // Produ��o efetiva da empresa
    v[2] = V("Firm_RND_Expenses_Adjusted_with_CO2_Subsidy");  // Despesas em P&D ajustadas da empresa
    v[3] = V("sector_innovation_proportion");                 // Propor��o de P&D destinada � inova��o
    v[8] = 100;                                               // Um valor m�ximo para normalizar o impacto do investimento em P&D

    // C�lculo da quantidade de recursos alocados para inova��o e imita��o
    v[9] = v[2] * v[3];                                 // Recursos alocados para inova��o
    v[10] = v[2] * (1 - v[3]);                          // Recursos alocados para imita��o

    // C�lculo das probabilidades de sucesso
    v[11] = 1 - exp(-v[9]);                             // Probabilidade de sucesso da inova��o
    v[12] = 1 - exp(-v[10]);                            // Probabilidade de sucesso da imita��o

    // C�lculo das emiss�es de CO2 baseadas na produ��o, ajustadas por inova��o e imita��o
    v[13] = v[0] * v[1] * (1 - (v[2] / v[8])) * (1 - v[11]) * (1 - v[12]);

    v[13] = max(0, v[13]);                              // Emiss�es n�o negativas

RESULT(v[13])




/*****EMISS�ES DE CO2 AJUSTADAS COM IMPOSTO E SUBS�DIO*****/ 

EQUATION("Firm_CO2_Emissions_Tax_and_Subsidy")
/*
C�lculo das emiss�es de CO2 da empresa com base na produ��o ajustada e nas despesas de P&D ajustadas com subs�dio, inova��o e imita��o. - IMPOSTO E SUBS�DIO
*/
    v[0] = V("CO2_base");                                           // Fator base de emiss�es de CO2 da empresa
    v[1] = V("Firm_Effective_Production_Adjusted_with_CO2_Tax");     // Produ��o efetiva da empresa ajustada pelo imposto
    v[2] = V("Firm_RND_Expenses_Adjusted_with_CO2_Subsidy");         // Despesas de P&D ajustadas com subs�dio da empresa
    v[3] = V("sector_innovation_proportion");                        // Propor��o de P&D destinada � inova��o
    v[8] = 100;                                                      // Um valor m�ximo para normalizar o impacto do investimento em P&D

    // C�lculo da quantidade de recursos alocados para inova��o e imita��o
    v[9] = v[2] * v[3];                                              // Recursos alocados para inova��o
    v[10] = v[2] * (1 - v[3]);                                       // Recursos alocados para imita��o

    // C�lculo das probabilidades de sucesso
    v[11] = 1 - exp(-v[9]);                                          // Probabilidade de sucesso da inova��o
    v[12] = 1 - exp(-v[10]);                                         // Probabilidade de sucesso da imita��o

    // C�lculo das emiss�es de CO2 baseadas na produ��o, ajustadas por inova��o e imita��o
    v[13] = v[0] * v[1] * (1 - (v[2] / v[8])) * (1 - v[11]) * (1 - v[12]);

    v[13] = max(0, v[13]);                                           // Emiss�es n�o negativas

RESULT(v[13])


