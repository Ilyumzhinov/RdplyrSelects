# Main package extended.
require(dplyr)
# Helps with formula processing.
require(rlang)

#' SELECT, MUTATE columns using this function.
#' @param .data A data frame.
#' @param ... args. Columns to select or mutate.
#' @param except Selects all columns except those specified. No need for "-" prescription. E.g. selects(..., except = c(GDP, GDP.deflator))
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

    # Maps list and returns a vector.
    map <- function(.list, f) Map(f, .list) %>% unlist()
    is_evalOK <- function(arg) ((tryCatch(eval(arg), error = function(e) NULL) %>% is.null()) == FALSE) || typeof(arg) == "symbol"
    is_lblYES <- function(lbl) lbl != ""

    # FILTER select args:
    # IF((eval OK || eval OK') && lbl NO)
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
    wrap_operation <- function(args, i_operation, f_operation) {
        if (length(args) == 0) {
            return(list())
        }
        1:length(args) %>% Reduce(function(l_mutate, i) {
            l_mutate[[i]] <- if (i_operation[i]) f_operation(i) else NULL
            l_mutate
        }, ., init = list())
    }

    # Wrap select and mutate tables to preserve their index
    l_select <- wrap_operation(args, i_select, function(i) select(.data, !!!args[i]))
    l_mutate <- wrap_operation(args, i_mutate, function(i) mutate(.data, !!!args[i], .keep = "none"))
    # Construct select except table
    data_except <- select_except(substitute(except))

    # Replaces select column with a mutated col with same label; reserve index
    replace_same_cols <- function(df_s, df_m) {
        i_sameT1 <- names(df_s) %in% names(df_m)
        i_sameT2 <- names(df_m) %in% names(df_s)
        data_merge <- df_s
        data_merge[i_sameT1] <- df_m[i_sameT2]
        data_merge
    }

    # Combines wrapped select and mutate tables using indexes
    combine_wrap <- function(l_s, l_m, i_s, i_m) {
        if (length(i_s) == 0) {
            return(data.frame(row.names = 1:dim(.data)[1]))
        }
        # Flatten mutate wrap into mutate data
        data_mutate <- l_m %>%
            Filter(function(arg) !is.null(arg), .) %>%
            data.frame()
        names_mutate <- Map(names, l_m)
        names_replace <- l_s %>% Map(function(arg) names(arg) %in% names_mutate, .)
        i_collision <- l_s %>% Reduce(function(accum, arg) accum | (names_mutate %in% names(arg)), ., init = rep(FALSE, length(names_mutate)))

        1:length(i_s) %>% Reduce(function(data_out, i) {
            if (i_s[i]) {
                if (TRUE %in% names_replace[[i]]) {
                    data_collision <- replace_same_cols(l_s[[i]], data_mutate)
                    data_out <- cbind(data_out, data_collision)
                }
                else {
                    data_out <- cbind(data_out, l_s[[i]])
                }
            }
            if (i_m[i] && !i_collision[i]) {
                data_out <- cbind(data_out, l_m[[i]])
            }
            data_out
        }, ., init = data.frame(row.names = 1:dim(.data)[1]))
    }

    # IF(except not specified) => COMBINE select, mutate
    # ELSE(except specified) => COMBINE except, mutate
    if (is.null(data_except)) {
        combine_wrap(l_select, l_mutate, i_select, i_mutate)
    }
    else {
        combine_wrap(
            list(data_except),
            c(list(NULL), l_mutate),
            c(TRUE, rep(FALSE, length(i_mutate))),
            c(FALSE, i_mutate)
        )
    }
}