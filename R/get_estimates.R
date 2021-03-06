#' @importFrom utils tail
rename_function <- function(text){
  fulltext <- paste(text, collapse = "")
  new_names <- names_est <- text
  #if(grepl("[\\(\\)]", fulltext)){
  #  text <- gsub("\\(", "___O___", text)
  #  text <- gsub("\\)", "___C___", text)
  #}
  text[text == "(Intercept)"] <- "Intercept"
  if(grepl(":", fulltext)){
    text <- gsub(":", "___X___", text)
  }

  if(grepl("mean of ", fulltext)){
    text <- gsub("mean of the differences", "difference", text)
    text <- gsub("mean of ", "", text)
  }

  # If any variables are subsetted from data.frames: remode the df part of the name
  remove_df <- sapply(text, grepl, pattern = "[\\]\\$]+", perl = TRUE)
  if(any(remove_df)){
    text[remove_df] <- sapply(text[remove_df], function(x){
      tmp_split <- strsplit(x, "[\\]\\$]+", perl = TRUE)[[1]]
      if(length(tmp_split)==1){
        x
      } else {
        tail(tmp_split, 1)
      }
    })
  }

  text
}



#' @importFrom utils tail
rename_estimate <- function(estimate){

  new_names <- names_est <- names(estimate)
  if(any(new_names == "(Intercept)")) new_names[match(new_names, "(Intercept)")] <- "Intercept"
  if(is.null(names_est)){
    stop("The 'estimates' supplied to bain() were unnamed. This is not allowed, because estimates are referred to by name in the 'hypothesis' argument. Please name your estimates.")
  }

  if(length(new_names) < 3){
    new_names <- gsub("mean of the differences", "difference", new_names)
    new_names <- gsub("mean of ", "", new_names)
  }

  # If any variables are subsetted from data.frames: remode the df part of the name
  remove_df <- sapply(new_names, grepl, pattern = "[\\]\\$]+", perl = TRUE)
  if(any(remove_df)){
    new_names[remove_df] <- sapply(new_names[remove_df], function(x){
      tmp_split <- strsplit(x, "[\\]\\$]+", perl = TRUE)[[1]]
      if(length(tmp_split)==1){
        x
      } else {
        tail(tmp_split, 1)
        }
    })
  }

  # Any interaction terms: replace : with _X_
  new_names <- gsub(":", "___X___", new_names)

  legal_varnames <- sapply(new_names, grepl, pattern = "^[a-zA-Z\\.][a-zA-Z0-9\\._]{0,}$")
  if(!all(legal_varnames)){
    stop("Could not parse the names of the 'estimates' supplied to bain(). Estimate names must start with a letter or period (.), and can be a combination of letters, digits, period and underscore (_).\nThe estimates violating these rules were originally named: ", paste("'", names_est[!legal_varnames], "'", sep = "", collapse = ", "), ".\nAfter parsing by bain, these parameters are named: ", paste("'", new_names[!legal_varnames], "'", sep = "", collapse = ", "), call. = FALSE)
  }
  names(estimate) <- new_names
  estimate
}

#' @title Get estimates from a model object
#' @description Get estimates from a model object, the way the
#' \code{\link{bain}} function will. This convenience function allows you to see
#' that coefficients are properly extracted, note how their names will be parsed
#' by bain, and inspect their values.
#' @param x A model object for which a \code{\link{bain}} method exists.
#' @param ... Parameters passed to and from other functions.
#' @return A named numeric vector.
#' @rdname get_estimates
#' @keywords internal
get_estimates <- function(x, ...){
  UseMethod("get_estimates", x)
}

#' @method get_estimates lm
get_estimates.lm <- function(x, ...){
  estimates <- x$coefficients
  variable_types <- sapply(x$model, class)

  # if(any(variable_types[-1] == "factor")){
  #   names(estimates) <- gsub(paste0("(^|:)(",
  #                                  paste(names(x$model)[-1][variable_types[-1] == "factor"], sep = "|"),
  #                                  ")"), "\\1", names(estimates))
  # }
  # Restore standard interaction term notation
  rename_estimate(estimates)
}

#' @method get_estimates bain_htest
get_estimates.bain_htest <- function(x, ...){
  rename_estimate(x$estimate)
}


#' @method get_estimates htest
get_estimates.htest <- function(x, ...) {
  stop("To be able to run bain on the results of an object returned by t_test(), you must first load the 'bain' package, and then conduct your t_test. The standard t_test does not return group-specific variances and sample sizes, which are required by bain. When you load the bain package, the standard t_test is replaced by a version that does return this necessary information.")
}


#' @title Label estimates from a model object
#' @description Label estimates from a model object, before passing it on to the
#' \code{\link{bain}} function.
#' @param x A model object for which a \code{\link{bain}} method exists.
#' @param labels Character vector. New labels (in order of appearance) for the
#' model object in \code{x}. If you are unsure what the estimates in \code{x}
#' are, first run \code{\link{get_estimates}}.
#' @param ... Parameters passed to and from other functions.
#' @return A model object of the same class as x.
#' @seealso get_estimates bain
#' @rdname label_estimates
#' @keywords internal
label_estimates <- function(x, labels, ...){
  x
  #UseMethod("label_estimates", x)
}

#' @method label_estimates lm
label_estimates.lm <- function(x, labels, ...){
  if(length(x$coefficients) != length(labels)) stop("The length of the vector of 'labels' must be equal to the length of the vector of coefficients in the model. To view the vector of coefficients, use 'get_estimates()'.")
  if(grepl("^\\(?Intercept\\)?$", names(x$coefficients)[1])){
    current_label <- 2
  } else {
    current_label <- 1
  }

  names(x$coefficients) <- labels
  # Now, process the data

  variable_types <- sapply(x$model, class)

  for(thisvar in 2:length(variable_types)){
    if(variable_types[thisvar] == "factor"){
      x$model[[thisvar]] <- ordered(x$model[[thisvar]], labels = labels[current_label:(current_label+length(levels(x$model[[thisvar]]))-1)])
      current_label <- current_label + length(levels(x$model[[thisvar]]))
      #fac_name <- names(x$model)[thisvar]
      #fac_levels <- levels(x$model[[thisvar]])
      #which_coef <- match(paste0(fac_name, fac_levels), names(x$coefficients))
      #fac_levels[which(!is.na(which_coef))] <- labels[which_coef[!is.na(which_coef)]]
      #x$model[[fac_name]] <- ordered(x$model[[fac_name]], labels = fac_levels)

    } else {
      #x$call$formula[3] <- gsub(paste0("\\b", names(x$model)[thisvar], "\\b"), labels[current_label], x$call$formula[3])

      #substitute(x$call$formula, list(names(x$model)[thisvar] = labels[current_label]))

      x$call$formula <- do.call("substitute", list(x$call$formula,
                                                   setNames(list(as.name(labels[current_label])), names(x$model)[thisvar])
                                                        )
                                                   )

      names(x$model)[thisvar] <- labels[current_label]
      current_label <- current_label+1
    }
  }

  invisible(get_estimates(x))
  x
}

#' @method label_estimates bain_htest
label_estimates.bain_htest <- function(x, labels, ...){
  names(x$estimate) <- labels
  invisible(get_estimates(x))
  x
}


#' @method label_estimates htest
label_estimates.htest <- function(x, labels, ...) {
  stop("To be able to run bain on the results of an object returned by t_test(), you must first load the 'bain' package, and then conduct your t_test. The standard t_test does not return group-specific variances and sample sizes, which are required by bain. When you load the bain package, the standard t_test is replaced by a version that does return this necessary information.")
}
