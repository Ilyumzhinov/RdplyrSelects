# Main package extended.
require(dplyr)
# Helps with formula processing.
require(rlang)
# map() for lists.
require(purrr)

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
    args <- enquos(...)

    # SELECT formula's rhs only (i.e. unevaluated expressions)
    args_formula <- args %>%
        map(f_rhs)

    is_evalOK <- function(arg) ((tryCatch(eval(arg), error = function(e) NULL) %>% is.null()) == FALSE) || typeof(arg) == "symbol"
    is_lblYES <- function(lbl) lbl != ""

    # FILTER select args:
    # IF((eval OK || eval OK') && lbl NO)
    i_select <- unlist(args_formula %>% map(is_evalOK)) &
        unlist((names(args_formula) %||% rep("", length(args_formula))) %>% map(~ !is_lblYES(.)))
    args_select <- args_formula[i_select]
    # FILTER mutate args:
    # IF(eval FAIL || ((eval OK || eval OK') && lbl YES))
    i_mutate <- unlist(args_formula %>% map(~ !is_evalOK(.))) |
        (unlist(args_formula %>% map(is_evalOK)) &
            unlist((names(args_formula) %||% rep("", length(args_formula))) %>% map(is_lblYES)))
    args_mutate <- args_formula[i_mutate]

    # Construct temporary tables using dplyr operations
    # Construct temporary SELECT table:
    # IF(except specified):
    #       IF(except is FALSE) => SELECT args_select, *
    #       ELSE(except is any) => SELECT args_select, -except
    # ELSE(except not specified) => SELECT args_select
    if (!is.null(substitute(except))) {
        if (substitute(except) == FALSE) {
            data_select <- .data %>% select(!!!args_select, everything())
        }
        else {
            arg_exc <- expr(-!!(enquo(except) %>% f_rhs()))
            data_select <- .data %>% select(!!!c(args_select, list(arg_exc)))
        }
    }
    else {
        data_select <- .data %>% select(!!!args_select)
    }
    # Construct temporary MUTATE table
    # Quote multiple args into function using !!! operator
    # Multiple args quotation reference:
    # https://adv-r.hadley.nz/quasiquotation.html#exec,
    # https://tidyeval.tidyverse.org/multiple.html
    data_mutate <- .data %>% mutate(!!!args_mutate, .keep = "none")

    check_notEmpty <- function(.table) (0 %in% dim(.table)) == FALSE

    # Check if tables aren't empty then merge
    if (check_notEmpty(c(data_select, data_mutate))) {
        # Replaces select column with a mutated col with same label; reserve index
        replace_same_cols <- function(df1, df2) {
            i_sameT1 <- names(df1) %in% names(df2)
            i_sameT2 <- names(df2) %in% names(df1)
            data_merge <- df1
            data_merge[i_sameT1] <- df2[i_sameT2]
            cbind(data_merge, df2[!i_sameT2])
        }

        replace_same_cols(data_select, data_mutate)
    }
    else {
        if (check_notEmpty(data_select)) {
            data_select
        }
        else {
            if (check_notEmpty(data_mutate)) {
                data_mutate
            }
        }
    }
}