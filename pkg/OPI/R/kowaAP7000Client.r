#
# OPI for Kowa AP 7000
# 
# Based on octopus900Client.r.
# 
# Author: Andrew Turpin    (aturpin@unimelb.edu.au)
# Date: December 2014
#
# Copyright 2015 Andrew Turpin
#
# This program is part of the OPI (http://perimetry.org/OPI).
# OPI is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

###################################################################
# .KowaAP7000Env$socket is the connection to the AP 7000
# .KowaAP7000Env$...    a variety of constants for colors, etc
###################################################################
if (!exists(".KowaAP7000Env")) {
    .KowaAP7000Env <- new.env()

    .KowaAP7000Env$BACKGROUND_WHITE  <- 0  # white, 10 cd/m^2
    .KowaAP7000Env$BACKGROUND_YELLOW <- 1  # yellow, 100 cd/m^2

    .KowaAP7000Env$FIX_CENTRE   <- 0   # fixation markers
    .KowaAP7000Env$FIX_CENTER   <- 0   # usa spelling
    .KowaAP7000Env$FIX_AUX      <- 1
    .KowaAP7000Env$FIX_MACULA   <- 2
    .KowaAP7000Env$FIX_AUX_LEFT <- 3

    .KowaAP7000Env$SIZES_DEGREES <- c(6.5, 13, 26, 52, 104) / 60 # Goldmann target sizes in degrees

    .KowaAP7000Env$COLOR_WHITE <- 0
    .KowaAP7000Env$COLOR_GREEN <- 1
    .KowaAP7000Env$COLOR_BLUE  <- 2
    .KowaAP7000Env$COLOR_RED   <- 3

    # Utility functions for validating inputs
    .KowaAP7000Env$minCheck <- function(x, limit, txt) {
        if (x < limit)
            stop(paste("opiPresent: ", txt, "is too small (minimum ", limit, ")"))
    }
    .KowaAP7000Env$maxCheck <- function(x, limit, txt) {
        if (x > limit)
        stop(paste("opiPresent: ", txt, "is too big (maximum ", limit, ")"))
    }

}

#######################################################################
# INPUT: 
#   ip                       = ip address on which server is listening
#   port                     = port number on which server is listening
#   mode                     = .KowaAP7000Env$MODE_WoW or .KowaAP7000Env$MODE_BoY
#
# @return NULL if succeed
# @return 1    server not found/ready at the ip+port provided
#######################################################################
kowaAP7000.opiInitialize <- function(ip="127.0.0.1", port=50001) {
    cat("Looking for server... ")
    suppressWarnings(tryCatch(    
        v <- socketConnection(host = ip, port,
                      blocking = TRUE, open = "w+b",
                      timeout = 10)
        , error=function(e) { 
            stop(paste(" cannot find a server at", ip, "on port",port))
        }
    ))
    close(v)
    
    print("found server :)")

    socket <- tryCatch(
        socketConnection(host=ip, port, open = "w+b", blocking = TRUE, timeout = 1000), 
        error=function(e) stop(paste("Cannot connect to AP 7000 at",ip,"on port", port))
    )

    assign("socket", socket, envir = .KowaAP7000Env)
    msg <- paste0("OPI_SET_MODE")
    writeLines(msg, socket)
    
	return(NULL)
}

###########################################################################
# INPUT: 
#   As per OPI spec
#
# Return a list of 
#	err  = string message
#	seen = 1 if seen, 0 otherwise
#	time = reaction time
#   xs = list of x-coordinates of pupil position during presentation
#   ys = list of y-coordinates of pupil position during presentation
###########################################################################
kowaAP7000.opiPresent <- function(stim, nextStim=NULL) { UseMethod("kowaAP7000.opiPresent") }
setGeneric("kowaAP7000.opiPresent")

kowaAP7000.opiPresent.opiStaticStimulus <- function(stim, nextStim) {
    if (is.null(stim)) {
        warning("opiPresent: NULL stimulus")
        return(list(err="NULL stimulus not supported", seen=NA, time=NA, pupilX=NA, pupilY=NA))
    }

    if(min(abs(.KowaAP7000Env$SIZES_DEGREES - stim$size)) != 0)
        warning("opiPresent: Rounding stimulus size to nearest Goldmann size")

    if (!is.element(stim$color, c(.KowaAP7000Env$COLOR_WHITE,
                                  .KowaAP7000Env$COLOR_GREEN,
                                  .KowaAP7000Env$COLOR_BLUE ,
                                  .KowaAP7000Env$COLOR_RED  )))
        stop("opiPresent: stimulus color is not supported.")

    .KowaAP7000Env$minCheck(stim$x, -80, "Stimulus x")
    .KowaAP7000Env$maxCheck(stim$x,  80, "Stimulus x")
    .KowaAP7000Env$minCheck(stim$y, -70, "Stimulus y")
    .KowaAP7000Env$maxCheck(stim$y,  65, "Stimulus y")
    .KowaAP7000Env$minCheck(stim$duration,  100, "Stimulus duration")
    .KowaAP7000Env$maxCheck(stim$duration, 1200, "Stimulus duration")
    .KowaAP7000Env$minCheck(stim$responseWindow,  stim$duration, "Stimulus responseWindow")
    .KowaAP7000Env$maxCheck(stim$responseWindow,           5000, "Stimulus responseWindow")
    .KowaAP7000Env$minCheck(stim$level,  10000/pi/10^5, "Stimulus level")
    .KowaAP7000Env$maxCheck(stim$level,  10000/pi     , "Stimulus level")

    if (!is.null(nextStim)) 
        warning("opiPresent: nextStim ignored")

    msg <- "OPI_PRESENT_STATIC "
    msg <- paste(msg, stim$x, stim$y, cdTodb(stim$level, 10000/pi))
    msg <- paste(msg, (which.min(abs(.KowaAP7000Env$SIZES_DEGREES - stim$size))))
    msg <- paste(msg, stim$color)
    msg <- paste(msg, stim$duration)
	msg <- paste(msg, stim$responseWindow)

    writeLines(msg, .KowaAP7000Env$socket)
    res <- readLines(.KowaAP7000Env$socket, n=1)
    s <- strsplit(res, "|||", fixed=TRUE)[[1]]

    return(list(
      err=NULL,
      seen=ifelse(s[1] == "1", TRUE, FALSE),    # assumes 1 or 0, not "true" or "false"
      time=as.numeric(s[2]), 
      pupilX=as.numeric(s[3]),
      pupilY=as.numeric(s[4])
    ))
}

########################################## 
# Present kinetic stim, return values 
########################################## 
kowaAP7000.opiPresent.opiKineticStimulus <- function(stim, ...) {
    if (is.null(stim)) {
        warning("opiPresent: NULL stimulus")
        return(list(err="NULL stimulus not supported", seen=NA, x=NA, y=NA))
    }

    if (length(xy.coords(stim$path)$x) > 2) 
        warning("opiPresent (kinetic): Kowa AP-7000 only supports paths of length 2 (start and end).  Ignoring all but the first two elements of stim$path etc")

        # convert sizes to .KowaAP7000Env$SIZES_DEGREES
    stim$sizes <- sapply(stim$sizes, function(s) {
         i <- which.min(abs(.KowaAP7000Env$SIZES_DEGREES - s))
         if(abs(.KowaAP7000Env$SIZES_DEGREES[i] - s) > 0.000001) {
             warning(paste("opiPresent: Rounding stimulus size",s,"to nearest Goldmann size"))
         } 
         return(i)
    })

    if (!is.element(stim$colors[1], c(.KowaAP7000Env$COLOR_WHITE,
                                  .KowaAP7000Env$COLOR_GREEN,
                                  .KowaAP7000Env$COLOR_BLUE ,
                                  .KowaAP7000Env$COLOR_RED  )))
        stop("opiPresent: stimulus color is not supported.")

    .KowaAP7000Env$minCheck(xy.coords(stim$path)$x[1], -80, "Start x")
    .KowaAP7000Env$maxCheck(xy.coords(stim$path)[1], 80, "Start x")
    .KowaAP7000Env$minCheck(xy.coords(stim$path)$x[2], -80, "End x")
    .KowaAP7000Env$maxCheck(xy.coords(stim$path)[2], 80, "End x")
    .KowaAP7000Env$minCheck(xy.coords(stim$path)$y[1], -70, "Start y")
    .KowaAP7000Env$maxCheck(xy.coords(stim$path)[1], 65, "Start y")
    .KowaAP7000Env$minCheck(xy.coords(stim$path)$y[2], -70, "End y")
    .KowaAP7000Env$maxCheck(xy.coords(stim$path)[2], 65, "End y")
    .KowaAP7000Env$minCheck(stim$levels[1],  10000/pi/10^5, "Stimulus level")
    .KowaAP7000Env$maxCheck(stim$levels[1],  10000/pi     , "Stimulus level")
    .KowaAP7000Env$minCheck(stim$speeds[1],  3, "Stimulus speed")
    .KowaAP7000Env$maxCheck(stim$speeds[1],  5, "Stimulus speed")

    msg <- "OPI_PRESENT_KINETIC "
    xs <- xy.coords(stim$path)$x[1]
    ys <- xy.coords(stim$path)$y[1]
    msg <- paste(msg, xy.coords(stim$path)$x[1])
    msg <- paste(msg, xy.coords(stim$path)$y[1])
    msg <- paste(msg, xy.coords(stim$path)$x[2])
    msg <- paste(msg, xy.coords(stim$path)$y[2])
    msg <- paste(msg, cdTodb(stim$levels[1], maxStim=10000/pi))
    msg <- paste(msg, stim$sizes[1])
    msg <- paste(msg, stim$colors[1])
    msg <- paste(msg, stim$speeds[1])
    
    writeLines(msg, .KowaAP7000Env$socket)
    res <- readLines(.KowaAP7000Env$socket, n=1)
    s <- strsplit(res, "|||", fixed=TRUE)[[1]]

    return(list(
        err =NULL, 
        seen=ifelse(s[1] == "1", TRUE, FALSE),    # assumes 1 or 0, not "true" or "false"
        time=NA,
        x=strtoi(s[2]),     # in degrees
        y=strtoi(s[3])       # in degrees
    ))
}

###########################################################################
# Not supported on AP 7000
###########################################################################
kowaAP7000.opiPresent.opiTemporalStimulus <- function(stim, nextStim=NULL, ...) {
    stop("opiPresent: Kowa AP 7000 does not support temporal stimuli")
}#opiPresent.opiTemporalStimulus()

###########################################################################
# set background color and/or fixation marker
# color is one of .KowaAP7000Env$BACKGROUND_WHITE or 
#                 .KowaAP7000Env$BACKGROUND_YELLOW
###########################################################################
kowaAP7000.opiSetBackground <- function(lum=NA, color=NA, fixation=NA) {
    if (is.na(fixation)) {
        .KowaAP7000Env$minCheck(fixation, 0, "Fixation")
        .KowaAP7000Env$maxCheck(fixation, 3, "Fixation")

        msg <- paste("OPI_SET_FIXATION", fixation)
        writeLines(msg, .KowaAP7000Env$socket)
    }

    if (!is.na(lum) && !is.na(color)) {
        if (lum == 10 && color != .KowaAP7000Env$BACKGROUND_WHITE)
            warning("Can only have a 10 cd/m^2 background that is white")
        if (lum == 100 && color != .KowaAP7000Env$BACKGROUND_YELLOW)
            warning("Can only have a 100 cd/m^2 background that is yellow")
    }

    if (!is.na(lum) && is.na(color)) {
        if (lum == 10) {
            color <- .KowaAP7000Env$BACKGROUND_WHITE
            warning("Can only have a 10 cd/m^2 background that is white")
        } else if (lum == 100) {
            color <- .KowaAP7000Env$BACKGROUND_YELLOW
            warning("Can only have a 100 cd/m^2 background that is yellow")
        } else {
            stop("opiSetBackground: Can only have 10 cd/m^2 (white) or 100 cd/m^2 (yellow)")
        }
    }
    
    if (!is.na(color)) {
        .KowaAP7000Env$minCheck(color, 0, "Background color")
        .KowaAP7000Env$maxCheck(color, 1, "Background color")
        msg <- paste("OPI_SET_BACKGROUND", color)
        writeLines(msg, .KowaAP7000Env$socket)
    }
        
    return(NULL)
}

###########################################################################
# return NULL on success (in fact, always!)
###########################################################################
kowaAP7000.opiClose <- function() {
    writeLines("OPI_CLOSE", .KowaAP7000Env$socket)
    close(.KowaAP7000Env$socket)
    return(NULL)
}

###########################################################################
# Lists defined constants
###########################################################################
kowaAP7000.opiQueryDevice <- function() {
    cat("Defined constants and functions\n")
    cat("-------------------------------\n")
    ls(envir=.KowaAP7000Env)

    writeLines("OPI-GET-PUPILPOS", .KowaAP7000Env$socket)
    res <- readLines(.KowaAP7000Env$socket, n=1)
    s <- strsplit(res, "|||", fixed=TRUE)[[1]]

    return(list(
        pupilX=strtoi(s[1]), 
        pupilY=strtoi(s[2])       # in pixels
    ))
}
