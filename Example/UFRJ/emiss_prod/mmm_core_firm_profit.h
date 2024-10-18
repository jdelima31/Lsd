
EQUATION("Firm_Revenue")
/*
Revenue depends on sales and price
*/
	v[0]=V("Firm_Sales");                                             //firm's sales 
	v[1]=V("Sector_Exports");                                         //sector exports
	v[2]=V("Firm_Price");                                             //firm's price
	v[4]=V("Exchange_Rate");                                          //exchange rate
	v[5]=V("Firm_Effective_Market_Share");                            //firm's effective market share
	v[6]=v[2]*(v[0]-v[5]*v[1])+v[5]*v[1]*v[2]/v[4];                   //revenue is given by firm's price multiplied by domestic sales plus exports (weighted by firm's market share) multiplied by firm's price over the exchange rate
RESULT(v[6])


EQUATION("Firm_Indirect_Tax")
/*
Indirect Tax of the firm is the revenue multiplied by the tax parameter
*/
	v[0]=V("Firm_Revenue");
	v[1]=V("sector_indirect_tax_rate");
	v[2]=v[0]*v[1];
RESULT(v[2])


EQUATION("Firm_Net_Revenue")
/*
Firm's net revenue, discounting taxes and R&D expenses.
*/
	v[0]=V("Firm_Revenue");
	v[1]=V("sector_indirect_tax_rate");
	v[2]=V("sector_rnd_revenue_proportion");
	v[4]=v[0]*(1-v[1])*(1-v[2]);
RESULT(v[4])


EQUATION("Firm_RND_Expenses")
/*
Firm's R&D expenses, subtracted from the revenue after taxes.
It will be distributed to income class as wages.
*/
	v[0]=V("Firm_Revenue");
	v[1]=V("sector_indirect_tax_rate");
	v[2]=V("sector_rnd_revenue_proportion");
	v[4]=v[0]*(1-v[1])*(v[2]);
RESULT(v[4])


EQUATION("Firm_Net_Profits")
/*
Profit of each firm, difference between revenue and costs, being revenue as a function of price and sales and cost of total inputs and labor used in production
*/
	v[0]=V("Firm_Net_Revenue");                                       //firm's net revenue
	v[1]=V("Firm_Effective_Production");                              //firm's effective production
	v[2]=V("Firm_Variable_Cost");                                     //firm's variable cost
	v[3]=VL("Firm_Stock_Debt",1);                                     //firm's stock of debt in the last period
	v[4]=V("Firm_Interest_Rate");                                     //interest rate paid by the firm
	v[6]=VL("Firm_Stock_Financial_Assets",1);                         //stock of financial assets in the last period
	v[7]=V("Basic_Interest_Rate");                                    //return rate of financial assets
	v[8]=v[0]+v[6]*v[7]-(v[3]*v[4])-(v[2]*v[1]);                      //net profits is given by net revenue plus financial assets return minus variable unit cost times effective production, depreciation expenses and interest payment.
RESULT(v[8])


EQUATION("Firm_Retained_Profits")
/*
Profit retained by the sector after being distributed to class and paid interest on the debt and separate the expense for depreciation.
*/
	v[0]=V("Firm_Net_Profits");                                        //firm's profits            
	v[1]=V("sector_profits_distribution_rate");                        //firm's profit distribution parameter                            
	if(v[0]>0)                                                         //if net profits is positive
		v[2]=(1-v[1])*v[0];                                            //retained profits
	else                                                               //if net profits is zero or negative                                                                     
		v[2]=v[0];                                                     //retained profits equals net profits                                                             
RESULT(v[2])


EQUATION("Firm_Distributed_Profits")
/*
Amount of profits distributed to the income classes
*/
	v[0]=V("Firm_Net_Profits");                                        //firm's profits            
	v[1]=V("sector_profits_distribution_rate");                        //firm's profit distribution parameter  
	if(v[0]>0)                                                         //if net profits is positive
		v[2]=v[1]*v[0];                                                //distributed profits
	else                                                               //if net profits is zero or negative                                                                     
		v[2]=0;																											
RESULT(v[2])




//////////////////////////////////
// ALTERACAO IURI MONTEIRO ///////
//////////////////////////////////




/*****AJUSTE NOS GASTOS EM P&D COM SUBSÍDIO BASEADO EM EMISSÕES DE CO2*****/


EQUATION("Firm_RND_Expenses_Adjusted_with_CO2_Subsidy")
/*
Ajusta as despesas em P&D com base em um subsídio, que é aplicado às empresas com emissões de CO2 abaixo de um determinado limite.
*/
    v[0] = V("Firm_RND_Expenses");                              // Despesas de P&D da empresa
    v[1] = V("Firm_CO2_Emissions");                             // Emissões de CO2 da empresa no período atual
    v[2] = V("CO2_Subsidy_Rate");                               // Parâmetro: taxa de subsídio baseada em emissões de CO2 --------> 0,15
    v[3] = V("CO2_subs_Threshold");                             // Limite de emissões de CO2 para qualificação do subsídio ------> 400
    v[4] = 0;                                                   // Inicializa o subsídio

    // Calcula o subsídio com base nas emissões
    if (v[1] <= v[3])                                      // Se as emissões atuais estiverem abaixo do limite
    {
        v[4] = v[0] * v[2];                                // Valor do subsídio (ex.: 20% das despesas de P&D)
    }

    // Ajusta as despesas de P&D adicionando o valor do subsídio
    v[5] = v[0] + v[4];                                    // Despesas de P&D ajustadas com o subsídio

RESULT(v[5])

