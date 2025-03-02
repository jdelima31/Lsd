#*******************************************************************************
#
# ------------------- LSD tools for sensitivity analysis ---------------------
#
#   Written by Marcelo C. Pereira, University of Campinas
#
#   Copyright Marcelo C. Pereira
#   Distributed under the GNU General Public License
#
#*******************************************************************************

# ==== Optimize meta-model (minimize or maximize) ====

model.optim.lsd <- function( model, data = NULL, lower.domain = NULL,
                             upper.domain = NULL, starting.values = NULL,
                             minimize = TRUE, pop.size = 1000,
                             max.generations = 30, wait.generations = 10,
                             precision = 1e-5, nnodes = 1 ) {

  if( ! inherits( model, "kriging.model.lsd" ) &&
      ! inherits( model, "polynomial.model.lsd" ) )
    stop( "Invalid model (not from polynomial or kriging.model.lsd())" )

  if( ! is.null( data ) ) {
    if( inherits( data, "doe.lsd" ) ) {
    	if( is.null( lower.domain ) )
    	  lower.domain <- data$facLimLo
    	if( is.null( upper.domain ) )
    	  upper.domain <- data$facLimUp
    	if( is.null( starting.values ) )
    	  starting.values <- data$facDef
    } else
      stop( "Invalid data (not from read.doe.lsd())" )
  }

  if( is.null( lower.domain ) || ! all( is.finite( lower.domain ) ) ||
      length( lower.domain ) < 1 )
    stop( "Invalid lower domain vector (lower.domain)" )

  if( is.null( upper.domain ) || ! all( is.finite( upper.domain ) ) ||
      length( upper.domain ) < 1 )
    stop( "Invalid upper domain vector (upper.domain)" )

  if( is.null( starting.values ) || ! all( is.finite( starting.values ) ) ||
      length( starting.values ) < 1 )
    stop( "Invalid starting value vector (starting.values)" )

  if( is.null( minimize ) || ! is.logical( minimize ) )
    stop( "Invalid minimization switch (minimize)" )

  if( is.null( pop.size ) || ! is.finite( pop.size ) || round( pop.size ) < 1 )
    stop( "Invalid number of parallel search paths (pop.size)" )

  if( is.null( max.generations ) || ! is.finite( max.generations ) ||
      round( max.generations ) < 1 )
    stop( "Invalid maximum number of generations (max.generations)" )

  if( is.null( wait.generations ) || ! is.finite( wait.generations ) ||
      round( wait.generations ) < 1 )
    stop( "Invalid maximum no-improvement generations (wait.generations)" )

  if( is.null( precision ) || ! is.finite( precision ) || precision <= 0 )
    stop( "Invalid tolerance level (precision)" )

  if( is.null( nnodes ) || ! is.finite( nnodes ) || round( nnodes ) < 1 )
    stop( "Invalid number of parallel computing nodes (nnodes)" )

  pop.size          <- round( pop.size )
  max.generations   <- round( max.generations )
  wait.generations  <- round( wait.generations )
  nnodes            <- round( nnodes )

  # check variables allowed to variate (lower != upper)
  varName <- varLo <- varUp <- varStart <- vector( )
  j <- 0
  for( i in 1 : length( lower.domain ) )
    if( lower.domain[ i ] < upper.domain[ i ] ) {
      j <- j + 1
      varName[ j ] <- names( lower.domain )[ i ]
      varLo[ j ] <- lower.domain[ i ]
      varUp[ j ] <- upper.domain[ i ]
      if( ! is.null( starting.values ) )
        varStart[ j ] <- starting.values[ i ]
    }
  names( varLo ) <- varName
  names( varUp ) <- varName
  if( ! is.null( starting.values ) )
    names( varStart ) <- varName
  else
    varStart <- NULL

  # function to be called by the optimizer
  f <- function( x ) {

    if( ! is.null( starting.values ) )
      X <- starting.values
    else
      X <- lower.domain

    for( ii in 1 : length( lower.domain ) )
      for( jj in 1 : length( x ) )
        if( names( lower.domain )[ ii ] == varName[ jj ] )
          X[ ii ] <- x[ jj ]

        X <- as.data.frame( t( X ) )
        return ( as.numeric( model.pred.lsd( X, model )$mean ) )
  }

  # enable multiprocessing (not working in Windows)
  if( nnodes == 0 )
    nnodes <- parallel::detectCores( ) / 2

  if( nnodes > 1 ) {
    if( .Platform$OS.type == "unix" ) {
      cluster <- parallel::makeForkCluster( min( nnodes,
                                                 parallel::detectCores( ) ) )
      parallel::setDefaultCluster( cluster )
    } else {
      #cluster <- parallel::makePSOCKcluster( min( nnodes,
      #                                            parallel::detectCores( ) ) )
      #parallel::setDefaultCluster( cluster )
      cluster <- FALSE
    }
  } else {
    cluster <- FALSE
  }

  xStar <- try( rgenoud::genoud( fn = f, nvars = j, max = ! minimize,
                                 starting.values = varStart,
                                 Domains = cbind( varLo, varUp ),
                                 boundary.enforcement = 2, pop.size = pop.size,
                                 max.generations = max.generations,
                                 wait.generations =  wait.generations,
                                 solution.tolerance = precision,
                                 gradient.check = FALSE,
                                 P1 = 39, P2 = 40, P3 = 40, P4 = 40,
                                 P5 = 40, P6 = 40, P7 = 40, P8 = 40,
                                 cluster = cluster,
                                 print.level = 0 ),
                silent = TRUE )

  # release multiprocessing cluster
  if( cluster != FALSE )
    try( parallel::stopCluster( cluster ), silent = TRUE )

  if( inherits( xStar, "try-error" ) )
    return( t( rep( NA, length( lower.domain ) ) ) )

  if( ! is.null( starting.values ) )
    opt <- starting.values
  else
    opt <- lower.domain

  # rebuilt the full parameter vector with the optimized values
  for( i in 1 : length( lower.domain ) )
    for( j in 1 : length( xStar$par ) )
      if( names( lower.domain )[ i ] == varName[ j ] )
        opt[ i ] <- xStar$par[ j ]
  opt <- as.data.frame( t( opt ) )
  rownames( opt ) <- c( "Value" )

  return( opt )
}


# ==== Compute meta-model minimum and maximum points for up to 2 factors ====

model.limits.lsd <- function( data, model, sa = NULL,
                              factor1 = 1, factor2 = 2, factor3 = 3,
                              pop.size = 1000, max.generations = 30,
                              wait.generations = 10, precision = 1e-5,
                              nnodes = 1 ) {

  if( ! inherits( data, "doe.lsd" ) )
    stop( "Invalid data (not from read.doe.lsd())" )

  if( ! inherits( model, "kriging.model.lsd" ) &&
      ! inherits( model, "polynomial.model.lsd" ) )
    stop( "Invalid model (not from polynomial or kriging.model.lsd())" )

  if( ! is.null( sa ) ) {
    if( inherits( sa, "kriging.sensitivity.lsd" ) ||
        inherits( sa, "polynomial.sensitivity.lsd" ) ) {
      factor1 <- sa$topEffect[ 1 ]
      factor2 <- sa$topEffect[ 2 ]
      factor3 <- sa$topEffect[ 3 ]
    } else
      stop( "Invalid sensitivity analysis (not from sobol.decomposition.lsd())" )
  }

  if( is.null( factor1 ) || ! is.finite( factor1 ) || round( factor1 ) < 1 )
    stop( "Invalid index for first factor (factor1)" )

  if( is.null( factor2 ) || ! is.finite( factor2 ) || round( factor2 ) < 1 )
    stop( "Invalid index for second factor (factor2)" )

  if( is.null( factor3 ) || ! is.finite( factor3 ) || round( factor3 ) < 1 )
    stop( "Invalid index for third factor (factor3)" )

  if( is.null( pop.size ) || ! is.finite( pop.size ) || round( pop.size ) < 1 )
    stop( "Invalid number of parallel search paths (pop.size)" )

  if( is.null( max.generations ) || ! is.finite( max.generations ) ||
      round( max.generations ) < 1 )
    stop( "Invalid maximum number of generations (max.generations)" )

  if( is.null( wait.generations ) || ! is.finite( wait.generations ) ||
      round( wait.generations ) < 1 )
    stop( "Invalid maximum no-improvement generations (wait.generations)" )

  if( is.null( precision ) || ! is.finite( precision ) || precision <= 0 )
    stop( "Invalid tolerance level (precision)" )

  if( is.null( nnodes ) || ! is.finite( nnodes ) || round( nnodes ) < 1 )
    stop( "Invalid number of parallel computing nodes (nnodes)" )

  factor1           <- round( factor1 )
  factor2           <- round( factor2 )
  factor3           <- round( factor3 )
  pop.size          <- round( pop.size )
  max.generations   <- round( max.generations )
  wait.generations  <- round( wait.generations )
  nnodes            <- round( nnodes )

  vars <- names( data$facDef )

  # first calculate max & min for each factor
  min1 <- max1 <- list( )
  minResp <- maxResp <- labels <- vector( )
  j <- 1
  for( i in c( factor1, factor2, factor3 ) ) {
    lo <- up <- data$facDef
    lo[ i ] <- data$facLimLo[ i ]
    up[ i ] <- data$facLimUp[ i ]

    min1[[ j ]] <- model.optim.lsd( model, lower.domain = lo, upper.domain = up,
                                    starting.values = data$facDef,
                                    minimize = TRUE, pop.size = pop.size,
                                    max.generations = max.generations,
                                    wait.generations = wait.generations,
                                    nnodes = nnodes )
    if( ! is.na( min1[[ j ]][ 1 ] ) )
      minResp[ j ] <- model.pred.lsd( min1[[ j ]], model )$mean
    else
      minResp[ j ] <- NA
    labels[ ( 2 * j ) - 1 ] <- paste( vars[ i ], "min" )

    max1[[ j ]] <- model.optim.lsd( model, lower.domain = lo, upper.domain = up,
                                    starting.values = data$facDef,
                                    minimize = FALSE, pop.size = pop.size,
                                    max.generations = max.generations,
                                    wait.generations = wait.generations,
                                    nnodes = nnodes )
    if( ! is.na( max1[[ j ]][ 1 ] ) )
      maxResp[ j ] <- model.pred.lsd( max1[[ j ]], model )$mean
    else
      maxResp[ j ] <- NA
    labels[ 2 * j ] <- paste( vars[ i ], "max" )

    j <- j + 1
  }

  # then calculate max & min for the first two factors jointly
  lo <- up <- data$facDef
  for( i in c( factor1, factor2 ) ) {
    lo[ i ] <- data$facLimLo[ i ]
    up[ i ] <- data$facLimUp[ i ]
  }

  min2 <- model.optim.lsd( model, lower.domain = lo, upper.domain = up,
                           starting.values = data$facDef,
                           minimize = TRUE, pop.size = pop.size,
                           max.generations = max.generations,
                           wait.generations = wait.generations,
                           nnodes = nnodes )
  if( ! is.na( min2[ 1 ] ) )
    min2Resp <- model.pred.lsd( min2, model )$mean
  else
    min2Resp <- NA

  max2 <- model.optim.lsd( model, lower.domain = lo, upper.domain = up,
                           starting.values = data$facDef,
                           minimize = FALSE, pop.size = pop.size,
                           max.generations = max.generations,
                           wait.generations = wait.generations,
                           nnodes = nnodes )
  if( ! is.na( max2[ 1 ] ) )
    max2Resp <- model.pred.lsd( max2, model )$mean
  else
    max2Resp <- NA
  labels[ ( 2 * j ) - 1 ] <- paste0( vars[ factor1 ], "-", vars[ factor2 ], " min" )
  labels[ 2 * j ] <- paste0( vars[ factor1 ], "-", vars[ factor2 ], " max" )

  max.min <- as.data.frame( cbind( t( min1[[ 1 ]] ), t( max1[[ 1 ]] ),
                                   t( min1[[ 2 ]] ), t( max1[[ 2 ]] ),
                                   t( min1[[ 3 ]] ), t( max1[[ 3 ]] ),
                                   t( min2 ), t( max2 ) ) )
  max.min <- rbind( max.min, c( minResp[ 1 ], maxResp[ 1 ], minResp[ 2 ],
                                maxResp[ 2 ], minResp[ 3 ], maxResp[ 3 ],
                                min2Resp, max2Resp ) )
  dimnames( max.min ) <- list( append( vars, "response" ), labels )

  return( max.min )
}
