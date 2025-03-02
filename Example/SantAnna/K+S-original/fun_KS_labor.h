/******************************************************************************

	LABOR MARKET OBJECT EQUATIONS
	-----------------------------

	Written by Marcelo C. Pereira, University of Campinas

	Copyright Marcelo C. Pereira
	Distributed under the GNU General Public License

	Equations that are specific to the Labor Market objects in the K+S LSD
	model are coded below.

 ******************************************************************************/

/*============================== KEY EQUATIONS ===============================*/

EQUATION( "Ls" )
/*
Effective work force (labor) size, increase workforce if full employment and
flagAddWorkers is set to 1
*/

v[1] = V( "delta" );							// population growth rate

// growing workforce and demand is higher than labor supply?
if ( VS( PARENT, "flagAddWorkers" ) == 1 &&
	 VS( CAPSECL1, "L1d" ) + VS( CONSECL1, "L2d" ) > CURRENT )
	v[1] += 0.02;								// lump grow in labor supply

RESULT( CURRENT * ( 1 + v[1] ) )				// grow population


EQUATION( "w" )
/*
Centralized wage imposed to all workers
Notice 'psi1' and 'psi2' are exchanged in the original paper equation
*/

v[1] = V( "psi1" );								// inflation adjust. parameter
v[2] = V( "psi2" );								// general prod. adjust. param.
v[3] = V( "psi3" );								// unemploym. adjust. parameter
v[5] = VLS( CONSECL1, "dCPIb", 1 );				// inflation variation
v[6] = VLS( PARENT, "dAb", 1 );					// general productivity variat.
v[7] = VL( "dUb", 1 );							// unemployment variation

v[0] = CURRENT * ( 1 + v[1] * v[5] + v[2] * v[6] + v[3] * v[7] );

RESULT( max( v[0], V( "w0min" ) ) )				// ensure subsistence level


EQUATION( "wU" )
/*
Unemployment benefit ("wage") paid by government
*/
RESULT( V( "phi" ) * V( "w" ) )


/*============================ SUPPORT EQUATIONS =============================*/

EQUATION( "L" )
/*
Labor aggregated demand
*/
RESULT( VS( CAPSECL1, "L1" ) + VS( CONSECL1, "L2" ) )


EQUATION( "TaxW" )
/*
Total taxes paid by workers on wages
*/
RESULT( VS( PARENT, "flagTax" ) >= 1 ? VS( PARENT, "tr" ) * V( "W" ) : 0 )


EQUATION( "U" )
/*
Unemployment rate
*/
RESULT( 1 - V( "L" ) / V( "Ls" ) )


EQUATION( "W" )
/*
Total (nominal) wages
*/
RESULT( V( "L" ) * V( "w" ) )


EQUATION( "dUb" )
/*
Notional unemployment (bounded) rate of change
Used for wages adjustment only
*/
RESULT( mov_avg_bound( THIS, "U", VS( PARENT, "mLim" ), VS( PARENT, "mPer" ) ) )


/*========================== SUPPORT LSD FUNCTIONS ===========================*/


/*============================= DUMMY EQUATIONS ==============================*/
