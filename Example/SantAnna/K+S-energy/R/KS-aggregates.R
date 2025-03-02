#******************************************************************
#
# ----------------- K+S Aggregates analysis ---------------------
#
#   Written by Marcelo C. Pereira, University of Campinas
#
#   Copyright Marcelo C. Pereira
#   Distributed under the GNU General Public License
#
#   The default configuration assumes that the supplied LSD
#   simulation configurations (basename Sim):
#     R/data/Sim1.lsd
#     R/data/Sim2.lsd
#   are executed before this script is used.
#
#   To execute the simulations, (1) open LSD Model Manager (LMM),
#   (2) in LSD Model Browser, open the model which contains this
#   script (double click), (3) in LMM, compile and run the model
#   (menu Model>Compile and Run), (4) in LSD Model Browser, load
#   the desired configuration (menu File>Load), (5) execute the
#   configuration (menu Run>Run or Run> Parallel Run), accepting
#   the defaults (parallel run is optional but typically saves
#   significant execution time).
#
#   IMPORTANT: this script assumes the R working directory is set
#   to the R subfolder where this script file is stored. This can
#   be done automatically in RStudio if a project is created at
#   this subfolder, or using the command setwd(). The "folder"
#   variable below must always point to a (relative) subfolder
#   of the R working directory.
#
#******************************************************************

#******************************************************************
#
# ------------ Read Monte Carlo experiment files ----------------
#
#******************************************************************

folder    <- "data"                 # data files folder
baseName  <- "Sim"                  # data files base name (same as .lsd file)
nExp      <- 2                      # number of experiments
iniDrop   <- 0                      # initial time steps to drop (0=none)
nKeep     <- -1                     # number of time steps to keep (-1=all)
mcStat    <- "mean"                 # Monte Carlo statistic ("mean", "median")
mcDist    <- ""                     # distance metric to find MC typical run
CI        <- 0.95                   # confidence level
bootR     <- 999                    # bootstrap replicates (bootCI != NULL)
bootCI    <- NULL                   # bootstrap confidence interval method (SLOW)
                                    # (NULL (no bootstrap), "basic", or "bca")


expVal <- c( "Baseline", "Monopolistic power" )   # case parameter values

# aggregated variables to use
logVars <- c( "Creal", "GDPreal", "GDPnom", "G", "Gbail", "Tax", "Deb", "Def",
              "DefP", "dN", "Ireal", "EI", "A", "A1", "A2", "Ade", "Se", "S1",
              "S2", "DebE", "Deb1", "Deb2", "NWb", "NWe", "NW1", "NW2", "We",
              "W1", "W2", "wReal", "BadDeb", "TC", "Loans", "CD", "CS", "Aee",
              "Aef", "Em", "EmE", "Em1", "Em2", "En" )
aggrVars <- append( logVars, c( "dGDP", "dCPI", "dA", "dw", "CPI", "Q2u",
                                "Fe", "F1", "F2", "entryE", "entry1", "entry2",
                                "entryEexit", "entry1exit", "entry2exit",
                                "exitE", "exit1", "exit2", "exitEfail",
                                "exit1fail", "exit2fail", "imi", "inn", "innDE",
                                "innGE", "HHe", "HH1", "HH2", "muEavg", "mu2avg",
                                "U", "V", "r", "Bda", "Bfail", "DebGDP",
                                "DefGDP", "DefPgdp", "CO2a", "EnGDP","Tm", "dEm",
                                "dEn","fGE", "fKge", "pE", "shockAavg" ) )


# ==== Process LSD result files ====

# load support packages and functions
source( "KS-support-functions.R" )

# remove warnings for saved data
# !diagnostics suppress = mc, mcP, mcX, P, X, S, M, m, C, c

# ---- Read data files ----

# Function to read one experiment data (to be parallelized)
readExp <- function( exper ) {
  if( nExp > 1 )
    myFiles <- list.files.lsd( folder, paste0( baseName, exper ) )
  else
    myFiles <- list.files.lsd( folder, baseName )

  cat( "Data files: ", myFiles, "\n" )

  # Read data from text files and format it as a 3D array with labels
  mc <- read.3d.lsd( myFiles, aggrVars, skip = iniDrop, nrows = nKeep, nnodes = 1 )

  # Get dimensions information
  nTsteps <- dim( mc )[ 1 ]              # number of time steps
  nVar <- dim( mc )[ 2 ]                 # number of variables
  nSize  <- dim( mc )[ 3 ]               # Monte Carlo sample size

  # Compute Monte Carlo averages and std. deviation and store in 2D arrrays
  stats <- info.stats.lsd( mc, median = ( mcStat == "median" ), ci = mcStat,
                           ci.conf = CI, ci.boot = bootCI, boot.R = bootR )

  t <- as.integer( rownames( stats$avg ) )      # t column to insert in tables

  if( mcStat == "median" ) {                    # pick desired statistic set
    P <- as.data.frame( cbind( t, stats$med ) )
    S <- as.data.frame( cbind( t, stats$mad ) )
  } else {
    P <- as.data.frame( cbind( t, stats$avg ) )
    S <- as.data.frame( cbind( t, stats$sd ) )
  }

  M <- as.data.frame( cbind( t, stats$max ) )
  m <- as.data.frame( cbind( t, stats$min ) )
  C <- as.data.frame( cbind( t, stats$ci.hi ) )
  c <- as.data.frame( cbind( t, stats$ci.lo ) )

  if( ! is.null( mcDist ) && mcDist != "" ) {   # use typical runs?
    d <- info.distance.lsd( mc, P, distance = mcDist, rank = TRUE )

    mcP <- d$close[ 1, ]
    P <- matrix( nrow = nTsteps, ncol = 0 )
    for( i in 1 : length( mcP ) )
      P <- cbind( P, mc[ , names( mcP[ i ] ), mcP[ i ] ] )

    dimnames( P ) <- list( dimnames( mc )[[ 1 ]], names( mcP ) )
    P <- as.data.frame( cbind( t, P ) )

    mcX <- names( d$rank )[ 1 ]
    X <- as.data.frame( cbind( t, mc[ , , mcX ] ) )
  } else
    mcP <- mcX <- X <- NULL

  # Save temporary results to disk to save memory
  tmpFile <- paste0( folder, "/", baseName, exper, "_aggr.Rdata" )
  save( mc, mcP, mcX, P, X, S, M, m, C, c, nTsteps, nVar, nSize, file = tmpFile )

  return( tmpFile )
}

# load each experiment serially
tmpFiles <- lapply( 1 : nExp, readExp )

# ---- Organize data read from files ----

# fill the lists to hold data
mcData <- mcPtag <- mcXtag <- Pdata <- Xdata <- Sdata <- Mdata <- mdata <-
  Cdata <- cdata <- list( )
nTsteps.1 <- nSize.1 <- 0

for( k in 1 : nExp ) {                      # relocate data in separate lists

  load( tmpFiles[[ k ]] )                   # pick data from disk
  file.remove( tmpFiles[[ k ]] )            # and delete temporary file

  if( k > 1 && ( nTsteps != nTsteps.1 || nSize != nSize.1 ) )
    stop( "Inconsistent data files.\nSame number of time steps and of MC runs is required." )

  mcData[[ k ]] <- mc
  rm( mc )

  Pdata[[ k ]] <- P
  Sdata[[ k ]] <- S
  Mdata[[ k ]] <- M
  mdata[[ k ]] <- m
  Cdata[[ k ]] <- C
  cdata[[ k ]] <- c
  nTsteps.1 <- nTsteps
  nSize.1 <- nSize

  if( ! is.null( mcDist ) && mcDist != "" ) {   # use typical runs?
    mcPtag[[ k ]] <- mcP
    mcXtag[[ k ]] <- mcX
    Xdata[[ k ]] <- X
  } else
    Xdata[[ k ]] <- P
}

# free memory
rm( tmpFiles, mcP, mcX, P, X, S, M, m, C, c, nTsteps.1, nSize.1 )
invisible( gc( verbose = FALSE ) )


#******************************************************************
#
# --------------------- Plot statistics -------------------------
#
#******************************************************************

# ===================== User parameters =========================

bCase     <- 1      # experiment to be used as base case
nBins     <- 15     # number of bins to use in histograms
warmUpPlot<- 100    # number of "warm-up" runs for plots
nTplot    <- -1     # last period to consider for plots (-1=all)
warmUpStat<- 100    # warm-up runs to evaluate all statistics
nTstat    <- -1     # last period to consider for statistics (-1=all)
lowP      <- 6      # bandpass filter minimum period
highP     <- 32     # bandpass filter maximum period
bpfK      <- 12     # bandpass filter order
lags      <- 4      # lags to analyze
bPlotCoef <- 1.5    # boxplot whiskers extension from the box (0=extremes)
bPlotNotc <- FALSE  # use boxplot notches
smoothing <- 1e5    # HP filter smoothing factor (lambda)
geTrsh    <- 0.8    # threshold for green energy transition at last period

repName   <- ""     # report files base name (if "" same baseName)
sDigits   <- 4      # significant digits in tables
plotRows  <- 1      # number of plots per row in a page
plotCols  <- 1  	  # number of plots per column in a page
plotW     <- 10     # plot window width
plotH     <- 7      # plot window height

# Colors assigned to each experiment's lines in graphics
colors <- c( "black", "blue", "red", "orange", "green", "brown" )

# Line types assigned to each experiment
lTypes <- c( "solid", "solid", "solid", "solid", "solid", "solid" )

# Point types assigned to each experiment
pTypes <- c( 4, 4, 4, 4, 4, 4 )


# ====== External support functions & definitions ======

source( "KS-time-plots.R" )
source( "KS-box-plots.R" )

# remove warnings for support functions and saved data
# !diagnostics suppress = mc, nTsteps, nKeep, nVar, nSize, log0, t.test0
# !diagnostics suppress = bkfilter, hpfilter, adf.test, abind, textplot, colSds
# !diagnostics suppress = plot_recovery, plot_bpf, plot_histo, corr_table
# !diagnostics suppress = growth_stats, corr_struct, time_plots, box_plots


# ==== Support stuff ====

if( repName == "" )
  repName <- baseName

# create tags for MC-specific plots
if( ! is.null( mcDist ) && mcDist != "" ) {   # use typical runs?
  Ptag <- c( )
  for( i in 1 : length( mcPtag[[ 1 ]] ) ) {
    Ptag[ i ] <- mcPtag[[ 1 ]][ i ]
    if( length( mcPtag ) > 1 )
      for( j in 2 : length( mcPtag ) )
        Ptag[ i ] <- paste( Ptag[ i ], mcPtag[[ j ]][ i ], sep = "|" )
  }
  names( Ptag ) <- names( mcPtag[[ 1 ]] )
  Xtag <- unlist( mcXtag )
  XtagAll <- paste( Xtag, collapse = "|" )
  fileTag <- paste0( "_", ifelse( length( mcXtag ) > 1, "multi-mc", mcXtag[[ 1 ]] ) )
} else {
  Ptag <- rep( mcStat, nVar )
  names( Ptag ) <- dimnames( mcData[[ 1 ]] )[[ 2 ]]
  Xtag <- rep( mcStat, nExp )
  XtagAll <- mcStat
  fileTag <- ""
}

# Generate fancy labels & build labels list legend
legends <- vector( )
legendList <- "Experiments: "
for( k in 1 : nExp ) {
  if( is.na( expVal[ k ] ) || expVal[ k ] == "" )
    legends[ k ] <- paste( "Case", k )
  else
    legends[ k ] <- expVal[ k ]
  if( k != 1 )
    legendList <- paste0( legendList, ",  " )
  legendList <- paste0( legendList, "[", k, "] ", legends[ k ] )
}

# Number of periods to show in graphics and use in statistics
if( nTplot < 1 || nTplot > nTsteps || nTplot <= warmUpPlot )
  nTplot <- nTsteps
if( nTstat < 1 || nTstat > nTsteps || nTstat <= warmUpStat )
  nTstat <- nTsteps
if( nTstat < ( warmUpStat + 2 * bpfK + 4 ) )
  nTstat <- warmUpStat + 2 * bpfK + 4         # minimum number of periods
TmaxStat <- nTstat - warmUpStat
TmaskPlot <- ( warmUpPlot + 1 ) : nTplot
TmaskStat <- ( warmUpStat + 1 ) : nTstat
TmaskBpf <- ( bpfK + 1 ) : ( TmaxStat - bpfK )

# Calculates the critical correlation limit for significance (under heroic assumptions!)
critCorr <- qnorm( 1 - ( 1 - CI ) / 2 ) / sqrt( nTstat )


# ==== Create PDF ====

pdf( paste0( folder, "/", repName, "_aggr_plots_", mcStat, fileTag, ".pdf" ),
     width = plotW, height = plotH )
par( mfrow = c ( plotRows, plotCols ) )             # define plots per page


#
# ====== Experiment comparison plots & statistics ======
#

time_plots( mcData, Pdata, Xdata, mdata, Mdata, Sdata, cdata, Cdata, mcStat,
            nExp, nSize, nTsteps, TmaskPlot, CI, Ptag, Xtag, legends, colors,
            lTypes, smoothing )

box_plots( mcData, mcStat, nExp, nSize, TmaxStat, TmaskStat, warmUpStat, nTstat,
           legends, legendList, sDigits, bPlotCoef, bPlotNotc, folder, repName )

#
# ------ Energy transition comparison ------
#

stats <- c( " Avg. GDP growth", " Avg. unemployment", " Avg. emmission growth",
            " Avg. clim. shock size", " Emissions 2100", " CO2 in atmos. 2100",
            " Temp. change 2100"
            )
table <- matrix( data = 0, nrow = 3 * ( length( stats ) + 1 ), ncol = nExp,
                 dimnames = list( c( "ALL RUNS", stats, "GREEN TRANSITION",
                                     stats, "DIRTY LOCK-IN", stats ),
                                  expVal[ 1 : nExp ] ) )
for( k in 1 : nExp ) {
  table[ 1, k ] <- nSize
  table[ 2, k ] <- mean( Xdata[[ k ]]$dGDP[ TmaskStat ], na.rm = TRUE )
  table[ 3, k ] <- mean( Xdata[[ k ]]$U[ TmaskStat ], na.rm = TRUE )
  table[ 4, k ] <- mean( Xdata[[ k ]]$dEm[ TmaskStat ], na.rm = TRUE )
  table[ 5, k ] <- mean( Xdata[[ k ]]$shockAavg[ TmaskStat ], na.rm = TRUE )
  table[ 6, k ] <- log( Xdata[[ k ]]$Em[ nTstat ] )
  table[ 7, k ] <- Xdata[[ k ]]$CO2a[ nTstat ]
  table[ 8, k ] <- Xdata[[ k ]]$Tm[ nTstat ]

  mcData.ge <- mcData[[ k ]][ , , which( mcData[[ k ]][ nTstat, "fGE", ] > geTrsh ),
                              drop = FALSE ]
  table[ 9, k ] <- dim( mcData.ge )[ 3 ]
  table[ 10, k ] <- mean( mcData.ge[ TmaskStat, "dGDP", ], na.rm = TRUE )
  table[ 11, k ] <- mean( mcData.ge[ TmaskStat, "U", ], na.rm = TRUE )
  table[ 12, k ] <- mean( mcData.ge[ TmaskStat, "dEm", ], na.rm = TRUE )
  table[ 13, k ] <- mean( mcData.ge[ TmaskStat, "shockAavg", ], na.rm = TRUE )
  table[ 14, k ] <- mean( log( mcData.ge[ nTstat, "Em", ] ), na.rm = TRUE )
  table[ 15, k ] <- mean( mcData.ge[ nTstat, "CO2a", ], na.rm = TRUE )
  table[ 16, k ] <- mean( mcData.ge[ nTstat, "Tm", ], na.rm = TRUE )

  mcData.de <- mcData[[ k ]][ , , which( mcData[[ k ]][ nTstat, "fGE", ] <= geTrsh ),
                              drop = FALSE ]
  table[ 17, k ] <- dim( mcData.de )[ 3 ]
  table[ 18, k ] <- mean( mcData.de[ TmaskStat, "dGDP", ], na.rm = TRUE )
  table[ 19, k ] <- mean( mcData.de[ TmaskStat, "U", ], na.rm = TRUE )
  table[ 20, k ] <- mean( mcData.de[ TmaskStat, "dEm", ], na.rm = TRUE )
  table[ 21, k ] <- mean( mcData.de[ TmaskStat, "shockAavg", ], na.rm = TRUE )
  table[ 22, k ] <- mean( log( mcData.de[ nTstat, "Em", ] ), na.rm = TRUE )
  table[ 23, k ] <- mean( mcData.de[ nTstat, "CO2a", ], na.rm = TRUE )
  table[ 24, k ] <- mean( mcData.de[ nTstat, "Tm", ], na.rm = TRUE )
}

textplot( formatC( table, format ="fg", digits = 3, zero.print = "" ),
          cmar = 2, cex = 1 )
title <- "Energy transition scenarios ( all experiments )"
subTitle <- paste( "( MC runs =", nSize, "/ MC", XtagAll, "/ period =",
				   warmUpStat + 1, "-", nTstat, ")" )
title( main = title, sub = subTitle )


#
# ====== Experiment-specific plots & statistics ======
#

for( k in 1 : nExp ) { # Experiment k

  #
  # ---- MC experiment distribution plots ----
  #

  # cross-section times selection
  csT <- c( round( ( warmUpPlot + nTplot + 1 ) / 2 ), nTplot )

  plot_histo( csT, mcData[[ k ]][ , "GDPreal", ], log = 3, bins = nBins,
              tit = paste( "GDP distribution (",
                           legends[ k ], ")" ),
              subtit = paste( "( mean at dotted line / cross sections at (",
                              paste( csT, collapse = ", " ), ") / MC runs =",
                              nSize, ")" ),
              labVar = "Log real gross domestic product",
              leg = c( "\"2050\"", "\"2100\"" ) )

  plot_histo( csT, mcData[[ k ]][ , "A", ], log = 1, bins = nBins,
              tit = paste( "Productivity distribution (",
                           legends[ k ], ")" ),
              subtit = paste( "( mean at dotted line / cross sections at (",
                              paste( csT, collapse = ", " ), ") / MC runs =",
                              nSize, ")" ),
              labVar = "Relative log labor productivity",
              leg = c( "\"2050\"", "\"2100\"" ) )

  plot_histo( csT, mcData[[ k ]][ , "wReal", ], log = 1, bins = nBins,
              tit = paste( "Real wage distribution (",
                           legends[ k ], ")" ),
              subtit = paste( "( mean at dotted line / cross sections at (",
                              paste( csT, collapse = ", " ), ") / MC runs =",
                              nSize, ")" ),
              labVar = "Log real wage",
              leg = c( "\"2050\"", "\"2100\"" ) )

  plot_histo( csT, mcData[[ k ]][ , "DebGDP", ], bins = nBins,
              tit = paste( "Government debt distribution (",
                           legends[ k ], ")" ),
              subtit = paste( "( mean at dotted line / cross sections at (",
                              paste( csT, collapse = ", " ), ") / MC runs =",
                              nSize, ")" ),
              labVar = "Government debt over GDP",
              leg = c( "\"2050\"", "\"2100\"" ) )

  plot_histo( csT, mcData[[ k ]][ , "CO2a", ], bins = nBins,
              tit = paste( "CO2 in atmosphere distribution (",
                           legends[ k ], ")" ),
              subtit = paste( "( mean at dotted line / cross sections at (",
                              paste( csT, collapse = ", " ), ") / MC runs =",
                              nSize, ")" ),
              labVar = "CO2 atmospheric concentration in PPM",
              leg = c( "\"2050\"", "\"2100\"" ) )

  plot_histo( csT, mcData[[ k ]][ , "Tm", ], bins = nBins,
              tit = paste( "Temperature anomaly distribution (",
                           legends[ k ], ")" ),
              subtit = paste( "( mean at dotted line / cross sections at (",
                              paste( csT, collapse = ", " ), ") / MC runs =",
                              nSize, ")" ),
              labVar = "Temperature change in C",
              leg = c( "\"2050\"", "\"2100\"" ) )


  #
  # ---- Bandpass filtered series plots ----
  #

  bpfMsg <- paste0( "Baxter-King bandpass-filtered series, low =", lowP,
                    "Q / high = ", highP, "Q / order = ", bpfK )

  plot_bpf( list( log0( Xdata[[ k ]]$GDPreal ), log0( Xdata[[ k ]]$Creal ),
                  log0( Xdata[[ k ]]$Ireal ), log0( Xdata[[ k ]]$A ) ),
            pl = lowP, pu = highP, nfix = bpfK, mask = TmaskPlot,
            col = colors, lty = lTypes,
            leg = c("GDP", "Consumption", "Investment", "Productivity" ),
            xlab = "Time", ylab = "Filtered series",
            tit = paste( "GDP cycles (", legends[ k ], ")" ),
            subtit = paste( "(", bpfMsg, "/ MC runs =", nSize,
                            "/ MC ", Xtag[ k ], ")" ) )

  plot_bpf( list( Xdata[[ k ]]$U, Xdata[[ k ]]$V ),
            pl = lowP, pu = highP, nfix = bpfK, mask = TmaskPlot,
            col = colors, lty = lTypes,
            leg = c( "Productivity", "Unemployment", "Vacancy" ),
            xlab = "Time", ylab = "Filtered series",
            tit = paste( "Shimer puzzle (", legends[ k ], ")" ),
            subtit = paste( "(", bpfMsg, "/ MC runs =", nSize,
                            "/ MC ", Xtag[ k ], ")" ) )

  plot_bpf( list( log0( Xdata[[ k ]]$GDPreal ), Xdata[[ k ]]$entryEexit,
                  Xdata[[ k ]]$entry1exit, Xdata[[ k ]]$entry2exit ),
            pl = lowP, pu = highP, nfix = bpfK, mask = TmaskPlot,
            resc = c( 0.5, NA ), col = colors, lty = lTypes,
            leg = c( "GDP", "Net entry (energy)", "Net entry (capital)",
            "Net entry (consumption)" ),
            xlab = "Time", ylab = "Filtered series (rescaled)",
            tit = paste( "Net entry and business cycle (", legends[ k ], ")" ),
            subtit = paste( "(", bpfMsg, "/ MC runs =", nSize,
                            "/ MC ", Xtag[ k ], ")" ) )

  #
  # ---- Correlation table ----
  #

  corr_table( c( "GDPreal", "Creal", "Ireal", "CPI", "A", "U", "wReal",
                 "mu2avg", "r", "DebGDP", "TC", "Loans", "BadDeb", "entryEexit",
                 "entry1exit", "entry2exit", "En", "Em", "Tm" ),
              mcData[[ k ]], plot = TRUE,
              logVars = c( 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 2, 2, 2, 0, 0, 0, 1, 0, 0 ),
              mask = TmaskStat, pl = lowP, pu = highP, nfix = bpfK,
              tit = paste( "Pearson correlation coefficients (", legends[ k ], ")" ),
              subtit = paste0( "( insignificant values at ", ( 1 - CI ) * 100,
                               "% in white / MC runs = ", nSize, " / period = ",
                               warmUpStat + 1, " - ", nTstat, " )" ),
              labVars = c( "GDP", "Consumption", "Investment", "Cons. price",
                           "L. productivity", "Unemployment", "Wage", "Mark-up",
                           "Interest", "Gov. debt", "Credit supply", "Loans",
                           "Bad debt", "Net entry E", "Net entry K", "Net entry C",
                           "Energy dem.", "Emissions", "Temperature" ) )

  #
  # ---- Correlation structure tables ----
  #

  # add additional composed variables to dataset
  newVar <- dim( mcData[[ k ]] )[[ 2 ]] + 1
  mcData[[ k ]] <- abind( mcData[[ k ]],
                          mcData[[ k ]][ , "DebE", ] +
                            mcData[[ k ]][ , "Deb1", ] +
                            mcData[[ k ]][ , "Deb2", ],
                          ( mcData[[ k ]][ , "NWe", ] +
                              mcData[[ k ]][ , "NW1", ] +
                              mcData[[ k ]][ , "NW2", ] ) /
                            ( mcData[[ k ]][ , "Se", ] +
                                mcData[[ k ]][ , "S1", ] +
                                mcData[[ k ]][ , "S2", ] ),
                          mcData[[ k ]][ , "exitEfail", ] * mcData[[ k ]][ , "Fe", ] +
                            mcData[[ k ]][ , "exit1fail", ] * mcData[[ k ]][ , "F1", ] +
                            mcData[[ k ]][ , "exit2fail", ] * mcData[[ k ]][ , "F2", ],
                          mcData[[ k ]][ , "entryE", ] * mcData[[ k ]][ , "Fe", ] +
                            mcData[[ k ]][ , "entry1", ] * mcData[[ k ]][ , "F1", ] +
                            mcData[[ k ]][ , "entry2", ] * mcData[[ k ]][ , "F2", ],
                          mcData[[ k ]][ , "entryEexit", ] +
                            mcData[[ k ]][ , "entry1exit", ] +
                            mcData[[ k ]][ , "entry2exit", ],
                          along = 2 )
  dimnames( mcData[[ k ]] )[[ 2 ]][ seq( newVar, newVar - 1 + 5 ) ] <-
    c( "DebE12", "NWe12", "exitE12fail", "entryE12", "netEntrE12" )

  corr.struct.1 <- corr_struct( "GDPreal", c( "Creal", "Ireal", "EI", "dN", "U",
                                              "A", "muEavg", "mu2avg", "DebE12",
                                              "NWe12", "exitE12fail" ),
                                mcData[[ k ]], labRef = "GDP (output)",
                                labVars = c( "Consumption", "Investment",
                                             "Net investment", "Change in inventories",
                                             "Unemployment rate", "Productivity",
                                             "Mark-up (energy)",
                                             "Mark-up (consumption)",
                                             "Total firm debt",
                                             "Liquidity-to-sales ratio",
                                             "Bankruptcy rate" ),
                                logVars = c( 1, 1, 1, 2, 0, 1, 0, 0, 2, 2, 0 ),
                                logRef = 2, mask = TmaskStat, lags = lags,
                                pl = lowP, pu = highP, nfix = bpfK, CI = CI )

  textplot( formatC( corr.struct.1, digits = sDigits, format = "g" ), cmar = 1 )

  title <- paste( "Correlation structure for GDP (1) (", legends[ k ], ")" )
  testMsg <- paste0( "( test H0: lag coefficient is not significant at ",
                     ( 1 - CI ) * 100, "% level", " )" )
  subTitle <- paste( paste0( "( ", bpfMsg, " / MC runs = ", nSize, " / period = ",
                             warmUpStat + 1, " - ", nTstat, " )" ),
                     testMsg, sep = "\n" )
  title( main = title, sub = subTitle )

  corr.struct.2 <- corr_struct( "GDPreal", c( "Creal", "Ireal", "A", "entryE12",
                                              "netEntrE12", "wReal", "U", "V",
                                              "En", "Em" ),
                                mcData[[ k ]], labRef = "GDP (output)",
                                labVars = c( "Consumption", "Investment",
                                             "Productivity", "Entry", "Net entry",
                                             "Wage", "Unemployment rate",
                                             "Vacancy rate", "Energy demand",
                                             "Emissions" ),
                                logVars = c( 1, 1, 1, 0, 0, 1, 0, 0, 1, 0 ),
                                logRef = 2, mask = TmaskStat, lags = lags,
                                pl = lowP, pu = highP, nfix = bpfK, CI = CI )

  textplot( formatC( corr.struct.2, digits = sDigits, format = "g" ), cmar = 1 )

  title <- paste( "Correlation structure for GDP (2) (", legends[ k ], ")" )
  title( main = title, sub = subTitle )

  #
  # ---- MC growth statistics and unit root tests ----
  #

  key.stats <- growth_stats( c( "GDPreal", "Creal", "Ireal", "A", "wReal", "En", "Em" ),
                             mcData[[ k ]], mask = TmaskStat,
                             labVars = c( "GDP (output)", "Consumption",
                                          "Investment", "Product.", "Real wage",
                                          "Energy dem.", "Emissions" ),
                             pl = lowP, pu = highP, nfix = bpfK, CI = CI )

  textplot( formatC( key.stats, digits = sDigits, format = "g" ), cmar = 2 )

  title <- paste( "Key statistics and unit roots tests for cycles (",
                  legends[ k ], ")" )
  testMsg <- paste0( "( test H0: there are unit roots / non-stationary at ",
                     ( 1 - CI ) * 100, "% level", " )" )
  subTitle <- paste( paste0( "( ", bpfMsg," / MC runs = ", nSize, " / period = ",
                             warmUpStat + 1, " - ", nTstat, " )" ), testMsg, sep = "\n" )
  title( main = title, sub = subTitle )

  #
  # ------ Stationarity & ergodicity tests ------
  #

  statErgo <- ergod.test.lsd( mcData[[ k ]][ TmaskStat, , ], signif = 1 - CI,
                              vars = c( "dGDP", "dA", "dw", "V", "U", "muEavg",
                                        "mu2avg", "HHe", "HH1", "HH2", "entryE",
                                        "entry1", "entry2", "Tm", "dEm", "dEn",
                                        "fGE" ) )

  textplot( statErgo, cmar = 1 )

  title <- paste( "Stationarity, i.i.d. and ergodicity tests (", legends[ k ], ")" )
  testMsg <- paste(
    "( ADF/PP H0: non-stationary, KPSS H0: stationary, BDS H0: i.i.d., KS/AD/WW H0: ergodic )" ,
    paste0( "( significance = ", ( 1 - CI ) * 100, "% )" ), sep = "\n" )
  subTitle <- paste( paste(
    "( average p-values for testing H0 and rate of rejection of H0 / MC runs =",
    nSize, "/ period =", warmUpStat + 1, "-", nTstat, ")" ), testMsg, sep = "\n" )
  title( main = title, sub = subTitle )

}


# Close plot file
dev.off( )
