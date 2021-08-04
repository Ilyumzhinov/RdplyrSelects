# Main package extended.
library(dplyr)
# Helps with formula processing.
library(rlang)

#' SELECT, MUTATE columns using this function.
#' @param .data A data frame.
#' @param ... args. Columns to select or mutate.
#' @param except Selects all columns except those specified. No need for "-" prescription. E.g. selects(..., except = c(GDP, GDP.deflator))
#' @return Same as DPLYR's SELECT or MUTATE.
#' @note Version 4.0.2
#' @examples
#' # SELECT by column name or slice or exclusion
#' usEconomy %>% selects(Year, GDP) # c=2. Column names old
#' usEconomy %>% selects(1:5) # c=5. Column names old
#' usEconomy %>% selects(except = 1) # c=n_c-1. Column names old
#'
#' # MUTATE by expression or label with expression
#' usEconomy %>% selects(Year - 1960, Federal.Funds * 100, GDP / (GDP.deflator / 100)) # c=3. Column names generated
#' usEconomy %>% selects(i_Year = Year - 1960, Federal.Funds.perc = Federal.Funds * 100, GDP_real = GDP / (GDP.deflator / 100)) # c=3. Column names new
#'
#' # Use everything at once
#' usEconomy %>% selects(Year, 2:5, Year - 1960, GDP_nominal = GDP, GDP_real = GDP_nominal / (GDP.deflator / 100)) # c=8. Column names old and generated and new
selects <- function(.data, ..., except = NULL) {
    # Modify quoted arguments reference: https://tidyeval.tidyverse.org/dplyr.html
    # SELECT formula's rhs only (i.e. unevaluated expressions)
    args <- enquos(...) %>% Map(f_rhs, .)

    # UTILITY FUNCTIONS
    # Maps list and returns a vector.
    map <- function(.list, f) Map(f, .list) %>% unlist()
    # Keeps everything from MINOR table but replaces colliding cols with MAJOR's cols.
    replace_left_join <- function(data_minor, data_major) {
        c_sameMinor <- names(data_minor) %in% names(data_major)
        c_sameMajor <- names(data_major) %in% names(data_minor)
        data_merge <- data_minor
        data_merge[c_sameMinor] <- data_major[c_sameMajor][, names(data_merge[c_sameMinor])]
        data_merge
    }
    # Keeps everything from both tables but replaces colliding cols with MAJOR's cols.
    replace_full_join <- function(data_minor, data_major) {
        c_sameMinor <- names(data_minor) %in% names(data_major)
        c_sameMajor <- names(data_major) %in% names(data_minor)
        data_merge <- data_minor
        data_merge[c_sameMinor] <- data_major[c_sameMajor][, names(data_merge[c_sameMinor])]
        bind_cols(data_merge, data_major[!c_sameMajor])
    }
    # Guaranteed to return a selectable col name for data_mutate.
    get_argName <- function(args, i_arg) if (names(args[i_arg]) != "") names(args[i_arg]) else expr_text(args[[i_arg]])

    # EVALUATION FUNCTIONS
    is_evalOK <- function(arg) {
        is_argSpecFunc <- function(arg) {
            tidyselect_specFunc <- c("all_of", "any_of", "contains", "ends_with", "everything", "last_col", "matches", "num_range", "one_of", "starts_with")

            TRUE %in% (tidyselect_specFunc %>% Map(function(f_name) grepl(paste(f_name, "[(](.*?)[)]", sep = ""), arg), .))
        }

        ((tryCatch(eval(arg), error = function(e) NULL) %>% is.null()) == FALSE) ||
            typeof(arg) == "symbol" ||
            (expr_text(arg) %>% is_argSpecFunc())
    }
    is_lblYES <- function(lbl) lbl != ""

    # FILTER select args:
    # IF((eval OK || eval OK' || eval OK_SF) && lbl NO)
    i_select <- map(args, is_evalOK) &
        map(names(args), function(x) !is_lblYES(x))
    # FILTER mutate args:
    # IF(eval FAIL || ((eval OK || eval OK') && lbl YES))
    i_mutate <- map(args, function(x) !is_evalOK(x)) | (
        map(args, is_evalOK) & map(names(args), is_lblYES))

    # IF(except specified):
    #       IF(except is FALSE) => SELECT args_select, *
    #       ELSE(except is any) => SELECT args_select, -except
    # ELSE(except not specified) => skip
    select_except <- function(except_temp) {
        # Quote multiple args into function using !!! operator
        # Multiple args quotation reference:
        # https://adv-r.hadley.nz/quasiquotation.html#exec,
        # https://tidyeval.tidyverse.org/multiple.html
        if (!is.null(except_temp)) {
            if (except_temp == FALSE) {
                .data %>% select(!!!args[i_select], everything())
            }
            else {
                arg_exc <- expr(-!!(enquo(except_temp) %>% f_rhs()))
                .data %>% select(!!!c(args[i_select], list(arg_exc)))
            }
        }
    }
    
    # Construct mutate table
    data_mutate <- .data %>% mutate(!!!args[i_mutate], .keep = "none")
    # Construct select except table
    data_except <- select_except(substitute(except))

    join_ordered <- function(args, .data, d_m, i_s, i_m) {
        if (length(args) == 0) {
            return(select(.data))
        }

        seq(1,length(args)) %>% Reduce(function(data_merge, i) {
            if (i_s[i]) {
                # JOIN complete data select and complete data select i => JOIN complete data select and colliding data mutate
                data_merge <- replace_left_join(
                    replace_full_join(
                        data_merge,
                        select(.data, !!!args[i])
                    ),
                    d_m
                )
            }
            if (i_m[i]) {
                # SELECT data_mutate i => JOIN complete data select and colliding data mutate
                data_merge <- replace_full_join(
                    data_merge,
                    select(d_m, get_argName(args, i))
                )
            }
            data_merge
        }, ., init = select(.data))
    }

    # IF(except not specified) => JOIN INDEXED select, mutate
    # ELSE(except specified) => JOIN except, mutate
    if (is.null(data_except)) {
        join_ordered(args, .data, data_mutate, i_select, i_mutate)
    }
    else {
        replace_full_join(data_except, data_mutate)
    }
}