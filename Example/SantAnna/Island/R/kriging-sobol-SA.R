#*******************************************************************************
#
# --------- Island Model: NOLH Kriging Sobol sensitivity analysis -------------
#
#   Written by Marcelo C. Pereira, University of Campinas
#
#   Copyright Marcelo C. Pereira
#   Distributed under the GNU General Public License
#
#   The default configuration assumes that the supplied LSD
#   main simulation configuration (basename sobol):
#     R/sa-sobol/sobol.lsd
#   is used with the also supplied sensitivity analysis (SA) set:
#     R/sa-sobol/sobol.sa
#   to generate a set of configurations which must be executed
#   before this script is used
#
#   To generate the configuration set, (1) open LSD Model Manager
#   (LMM), (2) in LSD Model Browser, open the model which contains
#   this script (double click), (3) in LMM, compile and run the
#   model (menu Model>Compile and Run), (4) in LSD Model Browser,
#   load the desired configuration (menu File>Load), (5) load the
#   desired SA set (menu File>Load Sensitivity), (6) generate the
#   configuration set (menu Data>Sensitivity Analysis>NOLH Sampling),
#   accepting all the default options, (7) create an out-of-sample
#   set of samples when asked by LSD, accepting the proposed number
#   of samples.
#
#   To execute the simulation set, (8) create a parallel processing
#   batch (menu Run>Parallel Batch), accepting to use the configura-
#   tion set just created and the default options, (9) execute the
#   created batch, accepting the option offered, (10) confirm opening
#   the background run monitor, (11) wait until all simulation runs
#   in the background run monitor finish.
#
#   Several files are required to run:
#       folder/baseName_XX_YY.csv       : DoE specification from LSD
#       folder/baseName_YY+1_ZZ.csv     : external validation from LSD (optional)
#       folder/baseName_XX_YY_WWW.csv   : DoE response from R
#       folder/baseName_YY+1_ZZ_WWW.csv : ext. validation response from R (optional)
#       folder/baseName.lsd             : LSD configuration with default values
#       folder/baseName.sa              : factor sensitivity test ranges from LSD
#
#   Run this script ONLY after producing the required data in LSD
#
#*******************************************************************************

library( LSDsensitivity )


folder   <- "sa-sobol"                # data files folder
baseName <- "sobol"                   # data files base name (same as .lsd file)
varName <- "gM"                       # variable to perform the sensitivity analysis on
iniDrop <- 0                          # initial time steps to drop from analysis (0=none)
nKeep <- -1                           # number of time steps to keep (-1=all)

plotRows <- 1                         # number of plots per row in a page
plotCols <- 1  	                      # number of plots per column in a page
plotW <- 12                           # plot window width
plotH <- 8                            # plot window height
raster <- FALSE                       # raster or vector plots
res <- 600                            # resolution of raster mode (in dpi)

grid3d <- 25                          # density for 3D wireframe plots
theta3d <- 320                        # horizontal view angle
phi3d <- 20                           # vertical view angle


# ==== LSD variables to use (all, the ones to be used in log and new) ====

lsdVars <- c( "Q", "g", "l", "m", "J" )
logVars <- c( )
newVars <- c( "gM" )


# ====== Optional function to evaluate the selected variables ======

eval.vars <- function( dataSet, allVars ) {
  tsteps <- nrow( dataSet )        # number of timesteps in simulated data set

  # ---- Calculate values of new variables (added to LSD dataset) ----

  if ( dataSet[ tsteps, "Q" ] > 0 )
    dataSet[ , "gM" ] <- log( dataSet[ tsteps, "Q" ] ) / tsteps
  else
    dataSet[ , "gM" ] <- 0

  return( dataSet )
}


# ==== Process LSD set of result files (an experimental data set) ====

dataSet <- read.doe.lsd( folder,                 # data files relative folder
                         baseName,               # data files base name (same as .lsd file)
                         varName,				         # variable name to perform the sensitivity analysis
                         does = 2,               # number of experiments (data + external validation)
                         iniDrop = iniDrop,      # initial time steps to drop from analysis (0=none)
                         nKeep = nKeep,          # number of time steps to keep (-1=all)
                         saveVars = lsdVars,     # LSD variables to keep in dataset
                         addVars = newVars,      # new variables to add to the LSD dataset
                         eval.vars = eval.vars,  # function to evaluate/adjust/expand the dataset
                         rm.temp = FALSE,        # remove temporary speedup files?
                         rm.outl = FALSE,        # remove outliers from dataset
                         lim.outl = 10 )         # limit non-outlier deviation (number of std. devs.)


# ====== Estimate Kriging meta-models and select the best one ======

mModel <- kriging.model.lsd( dataSet,            # LSD experimental data set
                             ext.wgth = 0.5,     # weight of external errors on model selection (0-1)
                             trendModel = 0,     # trend model (0=auto, 1=constant, 2=1st order polynomial)
                             covModel = 0,       # covariance kernel (0=auto, 1=Matern5/2,
                                                 # 2=Matern3/2, 3=Gaussian, 4=expon., 5=power exp.
                             digits = 3 )        # precision digits


# ====== Sobol sensitivity analysis on meta-model ======

sSA <- sobol.decomposition.lsd( dataSet,         # LSD experimental data set
                                mModel,          # estimated meta-model
                                krig.sa = FALSE, # use alternative kriging-specific SA algorithm
                                sa.samp = 5000 ) # number of samples in sensitivity analysis


# ====== Generate response surface 3D data for plotting ======

mResp <- response.surface.lsd( dataSet,          # LSD experimental data set
                               mModel,           # estimated meta-model
                               sSA,              # Sobol sensitivity analysis results
                               gridSz = 25,      # density for 3D wireframe (grid) plots
                               defPos = 2,       # default settings position in plot set (1, 2 or 3)
                               factor1 = 0,      # first factor (0=auto or # according to DoE factor order)
                               factor2 = 0,      # second factor (0=auto or # according to DoE factor order)
                               factor3 = 0 )     # third factor (0=auto or # according to DoE factor order)


# ===== Find maximum and minimum response values for top factors =====

maxMin <- model.limits.lsd( dataSet,             # LSD experimental data set
                            mModel,              # estimated meta-model
                            sSA )                # use auto factor order



#*******************************************************************************
#
# ----------------------- Analysis results presentation -----------------------
#
#*******************************************************************************

library( gplots )           # package for plotting tables
#library( rgl )              # package for 3D GL model (may not work with Rstudio server)


tryCatch( {    # enter error handling mode so PDF can be closed in case of error/interruption

  # create a daily output directory
  outDir <- format( Sys.time(), "%Y-%m-%d" )
  if( ! dir.exists( paste0( folder, "/", outDir ) ) )
    dir.create( paste0( folder, "/", outDir ) )

  cat( paste( "\nSaving results and data to:", paste0( folder, "/", outDir ), "\n" ) )

  # Select type of output
  if( raster ){
    # Open PNG (bitmap) files for output
    png( paste0( folder, "/", outDir, "/", baseName, "_kriging_sobol_%d.png" ),
         width = plotW, height = plotH, units = "in", res = res )

  } else {
    # Open PDF plot file for output
    pdf( paste0( folder, "/", outDir, "/", baseName, "_kriging_sobol_plots.pdf" ),
         width = plotW, height = plotH )
    par( mfrow = c ( plotRows, plotCols ) )             # define plots per page
  }

  # ====== Present meta-model selection details ======

  # ------ Model comparison table ------

  textplot( signif( mModel$comparison, 4 ), rmar = 1 )
  title( main = "Comparison of alternative kriging models",
         sub = "Q2: cross validation Q2 ( higher is better )\nRMSE/MAE/RMA: external validation RMSE/MAE/RMA ( lower is better )" )

  # ------ Model estimation table ------

  textplot( mModel$estimation.std, show.colnames = FALSE, cmar = 2, rmar = 1 )
  title( main = "Kriging meta-model estimation (standardized)",
         sub = paste0( "All variables rescaled to [ 0, 1 ] / Average 95% CI = +/- ",
                       round( mResp$avgCIdev, digits = 2 ), "\nPredicted output at defaults: ",
                       dataSet$saVarName, " = ", round( mResp$default$mean, digits = 2 ), " / 95% CI = [",
                       round( mResp$default$lower, digits = 2 ), ",",
                       round( mResp$default$upper, digits = 2 ), "]" ) )


  # ====== Sobol sensitivity analysis results ======

  # ------ Sobol sensitivity analysis table ------

  textplot( signif( sSA$sa, 4 ) )
  title( main = "Sobol decomposition sensitivity analysis" )

  # ------ Sobol sensitivity analysis chart ------

  barplot( t( sSA$sa ), col = c( "white", "gray" ), las = 2, ylim = c( 0, 1 ),
           legend.text = c( "main effects", "interactions" ) )
  title( main = "Sobol decomposition sensitivity analysis", ylab = "Sobol Index" )


  # ====== Plot 2D response surface ======

  # plot 2D charts for top factors (around defaut parameter configuration)
  for( i in 1 : 3 ) {
    plot( mResp$grid[[ i ]], mResp$factor[[ i ]]$mean,
          ylim = c( min( mResp$calib[[ 2 ]]$lower ),
                    max( mResp$calib[[ 2 ]]$upper ) ),
          type = "l", xlab = colnames( dataSet$doe )[ sSA$topEffect[ i ] ],
          ylab = dataSet$saVarName,
          main = paste0( "Meta-model response for parameter '",
                         colnames( dataSet$doe )[ sSA$topEffect[ i ] ], "'" ),
          sub = "Dotted lines at 95% confidence interval" )
    lines( mResp$grid[[ i ]], mResp$factor[[ i ]]$lower, col = "black", lty = 2 )
    lines( mResp$grid[[ i ]], mResp$factor[[ i ]]$upper, col = "black", lty = 2 )
    points( as.numeric( dataSet$facDef[ sSA$topEffect[ i ] ] ), mResp$default$mean,
            col = "red", pch = 19, cex = 1.5 )
    points( maxMin[ sSA$topEffect[ i ], ( i * 2 ) - 1 ],
            maxMin[ "response", ( i * 2 ) - 1 ],
            col = "green", pch = 18, cex = 1.5 )
    points( maxMin[ sSA$topEffect[ i ], i * 2 ],
            maxMin[ "response", i * 2 ],
            col = "blue", pch = 18, cex = 1.5 )
  }


  # ====== 3D response surface (wireframe & shaded) ======

  if( sSA$topEffect[ 1 ] > sSA$topEffect[ 2 ] ) {      # check if we have to swap x and y axis
    swapXY <- TRUE
  } else
    swapXY <- FALSE

  for( i in 1 : length( mResp$grid[[ 4 ]] ) ) {        # do for each top factor

    # plot 3D grid charts
    zMat <- matrix( mResp$calib[[ i ]]$mean, grid3d, grid3d, byrow = swapXY )

    # handle flat surfaces
    zlim <- range( zMat, na.rm = TRUE )
    if( zlim[ 1 ] == zlim[ 2 ] )
      if( zlim[ 1 ] != 0 ) {
        zlim <- zlim + c( - abs( zlim[ 1 ] ), abs( zlim[ 2 ] ) )
      } else
        zlim <- c( -1, 1 )

    vt <- persp( mResp$grid[[ 1 ]], mResp$grid[[ 2 ]], zMat, col = "gray90",
                 xlab = colnames( dataSet$doe )[ sSA$topEffect[ 1 ] ], zlim = zlim,
                 ylab = colnames( dataSet$doe )[ sSA$topEffect[ 2 ] ], zlab = dataSet$saVarName,
                 theta = theta3d, phi = phi3d, ticktype = "detailed" )

    if( length( mResp$grid[[ 4 ]] ) == 1 ||
        ( length( mResp$grid[[ 4 ]] ) == 3 && i == 2 ) ) {
      points( trans3d( as.numeric( dataSet$facDef[ sSA$topEffect[ 1 ] ] ),
                       as.numeric( dataSet$facDef[ sSA$topEffect[ 2 ] ] ),
                       mResp$default$mean, vt ), col = "red", pch = 19, cex = 1.0 )
      points( trans3d( maxMin[ sSA$topEffect[ 1 ], 7 ],
                       maxMin[ sSA$topEffect[ 2 ], 7 ],
                       maxMin[ "response", 7 ], vt ), col = "green", pch = 18, cex = 1.0 )
      points( trans3d( maxMin[ sSA$topEffect[ 1 ], 8 ],
                       maxMin[ sSA$topEffect[ 2 ], 8 ],
                       maxMin[ "response", 8 ], vt ), col = "blue", pch = 18, cex = 1.0 )
      subTitle <- paste0( "95% confidence interval: ", dataSet$saVarName, " = [",
                          round( mResp$default$lower, 2 ),
                          ",", round( mResp$default$upper, 2 ),
                          "] at defaults (red dot)" )
    } else
      subTitle <- paste0( "All other parameters are at default settings" )

    title( main = paste( paste( "Meta-model response surface (",
                                colnames( dataSet$doe )[ sSA$topEffect[ 3 ] ],
                                "=", mResp$grid[[ 4 ]][ i ], ")" ) ),
           sub = subTitle )

    # ------ 3D response surface (shaded) ------

  #  persp3d( mResp$grid[[ 1 ]], mResp$grid[[ 2 ]],
  #           matrix( mResp$calib[[ i ]]$mean, grid3d, grid3d ), col = "lightgray",
  #           xlab = colnames( dataSet$doe )[ sSA$topEffect[ 1 ] ],
  #           ylab = colnames( dataSet$doe )[ sSA$topEffect[ 2 ] ], zlab = dataSet$saVarName )
  }


  # ====== 3D response surface (isolevels) ======

  for( i in 1 : length( mResp$grid[[ 4 ]] ) ) {
    zMat <- matrix( mResp$calib[[ i ]]$mean, grid3d, grid3d, byrow = swapXY )
    contour( mResp$grid[[ 1 ]], mResp$grid[[ 2 ]], zMat, nlevels = 12 )
    if( length( mResp$grid[[ 4 ]] ) == 1 ||
        ( length( mResp$grid[[ 4 ]] ) == 3 && i == 2 ) ) {
      points( dataSet$facDef[ sSA$topEffect[ 1 ] ], dataSet$facDef[ sSA$topEffect[ 2 ] ],
              col = "red", pch = 19, cex = 1.5 )
      points( maxMin[ sSA$topEffect[ 1 ], 7 ],
              maxMin[ sSA$topEffect[ 2 ], 7 ],
              col = "green", pch = 18, cex = 1.5 )
      points( maxMin[ sSA$topEffect[ 1 ], 8 ],
              maxMin[ sSA$topEffect[ 2 ], 8 ],
              col = "blue", pch = 18, cex = 1.5 )
      subTitle <- paste0( "95% confidence interval: ", dataSet$saVarName, " = [",
                          round( mResp$default$lower, 2 ),
                          ",", round( mResp$default$upper, 2 ),
                          "] at defaults (red dot)" )
    } else
      subTitle <- paste0( "All other parameters are at default settings" )

    title( main = paste( "Meta-model response surface (",
                         colnames( dataSet$doe )[ sSA$topEffect[ 3 ] ], "=",
                         mResp$grid[[ 4 ]][ i ], ")" ),
           sub = subTitle, xlab = colnames( dataSet$doe )[ sSA$topEffect[ 1 ] ],
           ylab = colnames( dataSet$doe )[ sSA$topEffect[ 2 ] ] )
  }

  cat( "\nDone...\n" )

  #******************************************************************
  #
  # ------------- Exception handling code (tryCatch) -------------
  #
  #******************************************************************

}, interrupt = function( ex ) {
  cat( "An interrupt was detected.\n" )
  print( ex )
  textplot( "Report incomplete due to interrupt." )
}, error = function( ex ) {
  cat( "An error was detected.\n" )
  print( ex )
  textplot( "Report incomplete due to processing error." )
}, finally = {
  options( warn = 0 )
  # Close PDF plot file
  dev.off( )
} )
