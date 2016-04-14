#===================================================================================================
#' Extract taxonomy information from sequence headers
#' 
#' Extracts the taxonomy from metadata (e.g. sequence headers) or parsed sequence data. 
#' The location and identity of important information in the input is specified using a regular expression
#' with capture groups and an corresponding key.
#' An object of type \code{\link{classified}} is returned containing the specifed information.
#' Taxa are translated into unique codes if they are not already encoded this way.
#' 
#' @param input A vector from which to extract taxonomy information or an object of class
#' \code{\link{ape}{DNAbin}}. 
#' @param regex (\code{character; length == 1}) A regular expression with capturing groups
#'  indicating the locations of relevant information. The identity of the information must
#'  be specified using the \code{key} argument.
#' @param key (\code{character}) The identity of the capturing groups defined using \code{regex}.
#'  The length of \code{key} must be equal to the number of capturing groups specified in \code{regex}.
#'  Any names added to the terms will be used as column names in the output.
#'  Each term must be one of those decribed below:
#'  \describe{
#'    \item{\code{taxon_id}}{A unique numeric id for a taxon for a particular \code{database}}
#'    \item{\code{taxon_name}}{The name of a taxon. Not necessarily unique, but are specific (i.e. interpretable)
#'    to a particular \code{database}.}
#'    \item{\code{taxon_info}}{Arbitrary taxon info you want included in the output. Can be used more than once.}
#'    \item{\code{class_id}}{A list of taxa unique IDs that consitute the full taxonomic classification
#'  from broad to specific (see \code{class_tax_rev}) for a particular \code{database}. Individual taxa
#'  are separated by the \code{class_tax_sep} argument and the taxon-rank group is separated by the
#'  \code{class_rank_sep} argument.}
#'    \item{\code{class_name}}{A list of taxa names that consitute the full taxonomic
#'  classification from broad to specific. Same usage as \code{class_id}.
#'  Individual names are not necessarily unique, but are specific (i.e. interperable)
#'  to a particular \code{database}.}
#'    \item{\code{item_id}}{An unique item (e.g. sequence) identifier. The taxonomy information will be
#'  looked up if available. Requires an internet connection.}
#'    \item{\code{item_name}}{An item (e.g. sequence) name. Not necessarily unique.}
#'    \item{\code{item_info}}{Arbitrary item info you want included in the output. Can be used more than once.}
#'  }
#' @param class_tax_sep (\code{character; length == 1}) Used with the \code{class_name} term in the \code{key}
#' argument. The characters used to separate individual taxa within a lineage.
#' @param class_rank_sep (\code{character; length == 1}) Used with the \code{class_name} term in the \code{key}
#' argument when a lineage contiains both taxon and rank information. This is the characters used to separate
#' th rank and the taxon name within an individual taxa in a lineage.
#' @param class_tax_rev Used with the \code{class_name} term in the \code{key} argument.
#' If TRUE, the rank order of taxa read in a lineage is reversed to be specific to broad.
#' @param class_rank_rev Used with the \code{class_name} term in the \code{key} argument  when a lineage
#' contiains both taxon and rank information. If TRUE, the rank information come after the taxon information.
#' @param taxon_in_lineage If \code{TRUE}, the lineage string included the taxon itself as its most specific
#' classification.
#' @param database (\code{character; length == 1}): The name of the database that patterns given in 
#'  \code{parser} will apply to. Valid databases include "ncbi", "itis", "eol", "col", "tropicos",
#'  "nbn", and "none". \code{"none"} will cause no database to be quired; use this if you want to not use the
#'  internet.
#' @param arbitrary_ids (\code{character} of length 1) Determines how the generation of arbitrary IDs is
#'  handled. Possible options are:
#'  \describe{
#'    \item{\code{"allow"}}{Arbitrary IDs are automatically generated if needed. These can occur intermixed
#'    with offical database IDs in the case of failed database lookups.}
#'    \item{\code{"warn"}}{Like \code{"allow"} but issue a warning when arbitrary IDs are used.}
#'    \item{\code{"error"}}{Cause an error if arbitrary IDs are needed.}
#'    \item{\code{"na"}}{Put \code{NA}s where arbitrary are needed.}
#'    \item{\code{"none"}}{Do not use a database to look up information.}
#'  } 
#' @param ... Not used.
#'  
#' @return Returns an object of type \code{classified}
#'
#' @examples
#' # Extract embedded classifications from UNITE FASTA file offline
#' file_path <- system.file("extdata", "unite_general_release.fasta", package = "metacoder")
#' sequences <- ape::read.FASTA(file_path)
#' unite_ex_data_3 <- extract_taxonomy(sequences,
#'                                     regex = "^(.*)\\|(.*)\\|(.*)\\|.*\\|(.*)$",
#'                                     key = c(name = "item_info", seq_id = "item_info",
#'                                             other_id = "item_info", "class_name"),
#'                                     database = "none")
#' \dontrun{
#' # Look up taxonomic data online using sequence ID
#' unite_ex_data <- extract_taxonomy(sequences,
#'                                   regex = "^(.*)\\|(.*)\\|(.*)\\|.*\\|(.*)$",
#'                                 key = c(name = "taxon_name", seq_id = "item_id",
#'                                        other_id = "item_info", tax_string = "item_info"))
#' }
#' 
#' @export
#' @rdname extract_taxonomy
extract_taxonomy <- function(input, ...) {
  UseMethod("extract_taxonomy")
}


#' @method extract_taxonomy default
#' @export
#' @rdname extract_taxonomy
extract_taxonomy.default <- function(input, regex, key, class_tax_sep = ";", class_rank_sep = "__", 
                                     class_tax_rev = FALSE, class_rank_rev = FALSE,
                                     taxon_in_lineage = TRUE, database = 'ncbi', arbitrary_ids = "warn", ...) {
  # Constants --------------------------------------------------------------------------------------
  valid_databases <- c("ncbi", "itis", "eol", "col", "tropicos", "nbn", "none")
  valid_keys <- c("taxon_id", "taxon_name", "taxon_info", "class_id", "class_name", 
                  "item_id", "item_name", "item_info")
  valid_arb_id_opts <- c("allow", "warn", "error", "na")
  database_id_classes <- c(ncbi = "uid", itis = "tsn", eol = "eolid", col = "colid",
                           tropicos = "tpsid", nbn = "nbnid")
  id_from_name_funcs <- list(ncbi = taxize::get_uid, itis = taxize::get_tsn, eol = taxize::get_eolid,
                             col = taxize::get_colid, tropicos = taxize::get_tpsid, nbn = taxize::get_nbnid, 
                             none = NA)
  taxid_from_seqid_funcs <- list(ncbi = taxize::genbank2uid, none = NA)
  taxon_in_lineage = TRUE
  # Argument validation ----------------------------------------------------------------------------
  if (!all(key %in% valid_keys)) stop("Invalid key term. Look at documentation for valid terms.")
  database <- match.arg(tolower(database), choices = valid_databases)
  arbitrary_ids <- match.arg(tolower(arbitrary_ids), choices = valid_arb_id_opts)
  # Apply option default ---------------------------------------------------------------------------
  if (is.null(names(key))) names(key) <- key
  # Parse arguments --------------------------------------------------------------------------------
  id_class <- database_id_classes[database]
  id_from_name <- id_from_name_funcs[[database]]
  taxid_from_seqid <- taxid_from_seqid_funcs[[database]]
  # Parse input using regex ------------------------------------------------------------------------
  item_data <- data.frame(stringr::str_match(input, regex), stringsAsFactors = FALSE)
  if (ncol(item_data) != length(key) + 1) stop("The number of capture groups and keys do not match.")
  if (any(is.na(item_data))) stop("Could not parse one or more entries. Check that `regex` matches all of `input`.")
  names(item_data) <- c("input", key)
  # Get taxon id -----------------------------------------------------------------------------------
  report_found <- function(get_id_result) {
    not_found <- sum(attr(get_id_result, "match") ==  "not found")
    if (not_found > 0) warning(paste0("Could not find taxon IDs for ", not_found, " items."))    
  }
  arbitrary_taxon_ids <- FALSE
  if ("taxon_id" %in% names(item_data)) {
    if (database != "none") class(item_data$taxon_id) <- id_class
  } else if ("class_id" %in% names(item_data) && taxon_in_lineage) {
    item_classification <- parse_lineage(item_data$class_id, taxon_sep = class_tax_sep,
                                         rank_sep = class_rank_sep, rev_taxon = class_tax_rev,
                                         rev_rank = class_rank_rev, taxon_col_name = "taxon_id")
    item_data$taxon_id <- extract_last(item_classification, "taxon_id")
    if (database != "none") class(item_data$taxon_id) <- id_class
  } else if ("item_id" %in% names(item_data) && database != "none") {
    if (is.null(taxid_from_seqid)) stop("Cannot look up taxonomy from sequence id using current database.")
    item_data$taxon_id <- taxid_from_seqid(item_data$item_id, batch_size = 1)
  } else if ("taxon_name" %in% names(item_data) && database != "none") {
    item_data$taxon_id <- map_unique(item_data$taxon_name, id_from_name)
    report_found(item_data$taxon_id)
  } else {
    warning("Insufficient information supplied to infer taxon IDs. Assigning arbitrary IDs.")
    arbitrary_taxon_ids <- TRUE
  }
  # Get taxon id lineage ---------------------------------------------------------------------------
  get_id_from_name <- FALSE 
  if ("taxon_id" %in% names(item_data) && database != "none") {
    item_classification <- map_unique(item_data$taxon_id, taxize::classification,
                                      db = database, return_id = TRUE)
    item_classification[!is.na(item_classification)] <- lapply(item_classification[!is.na(item_classification)],
                                                               setNames, nm = c("name", "rank_name", "taxon_id"))
  } else if ("class_id" %in% names(item_data) && taxon_in_lineage) {
    item_classification <- parse_lineage(item_data$class_id, taxon_sep = class_tax_sep,
                                         rank_sep = class_rank_sep, rev_taxon = class_tax_rev,
                                         rev_rank = class_rank_rev, taxon_col_name = "taxon_id")
  } else if ("class_id" %in% names(item_data) && !taxon_in_lineage && "taxon_id" %in% names(item_data) && !arbitrary_taxon_ids) {
    item_classification <- parse_lineage(item_data$class_id, taxon_sep = class_tax_sep,
                                         rank_sep = class_rank_sep, rev_taxon = class_tax_rev,
                                         rev_rank = class_rank_rev, taxon_col_name = "taxon_id")
    item_classification <- append_to_each(item_classification, 
                                          item_data[ , c("taxon_id", "taxon_rank")])
  } else if ("class_name" %in% names(item_data) && taxon_in_lineage) {
    item_classification <- parse_lineage(item_data$class_name, taxon_sep = class_tax_sep,
                                         rank_sep = class_rank_sep, rev_taxon = class_tax_rev,
                                         rev_rank = class_rank_rev, taxon_col_name = "name")
    item_classification <- add_taxon_ids(item_classification)
    get_id_from_name <- TRUE 
  } else if ("class_name" %in% names(item_data) && !taxon_in_lineage && "taxon_name" %in% names(item_data)) {
    item_classification <- parse_lineage(item_data$class_name, taxon_sep = class_tax_sep,
                                         rank_sep = class_rank_sep, rev_taxon = class_tax_rev,
                                         rev_rank = class_rank_rev, taxon_col_name = "name")
    item_classification <- append_to_each(item_classification, 
                                          item_data[ , c("taxon_name", "taxon_rank")])
    item_classification <- add_taxon_ids(item_classification)
    get_id_from_name <- TRUE 
  } else {
    stop("Insufficient information supplied to infer lineage taxon IDs. Taxonomy structure cannot be determined.")
    item_classification <- NULL
  } 
  # Add arbitrary taxon IDs to item data if necessary ----------------------------------------------
  if (arbitrary_taxon_ids) item_data$taxon_id <- extract_last(item_classification, "taxon_id")
  # Get taxon data ---------------------------------------------------------------------------------
  taxon_id_key <- unique_taxa(item_classification, id_column = "taxon_id")
  taxon_data <- do.call(rbind, lapply(taxon_id_key, function(x) x[nrow(x), ]))
  if (database != "none") class(taxon_data$taxon_id) <- id_class
  # Get taxon id of classifications if necessary ---------------------------------------------------
  if (get_id_from_name && database != "none") {
    taxon_ids <- map_unique(taxon_data$name, id_from_name, rows = 1)
    not_unique <- names(which(table(taxon_ids) != 1))
    taxon_ids[taxon_ids %in% not_unique] <- NA
    ids_found <- !is.na(taxon_ids)
    if (arbitrary_ids == "error" && any(is.na(taxon_ids))) stop("Could not look up all taxon names. Use option `arbitrary_ids` to allow arbitrary IDs.")
    if (arbitrary_ids == "warn" && any(is.na(taxon_ids))) warning("Could not look up all taxon names. Arbitrary IDs will be applied.")
    taxon_data$taxon_id[ids_found] <- taxon_ids[ids_found]
    if (arbitrary_ids == "na") {
      taxon_data$taxon_id[!ids_found] <- NA
    } else {
      taxon_data$taxon_id[!ids_found] <- make_new_ids(sum(!ids_found), existing = taxon_data$taxon_id[ids_found]) 
    }
    taxon_data$id_type <- "arbitrary"
    taxon_data$id_type[ids_found] <- database
    names(taxon_id_key) <- taxon_data$taxon_id
    item_classification <- add_taxon_ids(item_classification, id_key = taxon_id_key)
    taxon_id_key <- add_taxon_ids(taxon_id_key, id_key = taxon_id_key)
    names(item_classification) <- extract_last(item_classification, "taxon_id")
    item_data$taxon_id <- names(item_classification)
  }
  # Get taxon name and rank if necessary -----------------------------------------------------------
  if (!arbitrary_taxon_ids && database != "none") {
    if (!("name" %in% names(taxon_data)) || !("rank_name" %in% names(taxon_data))) {
      result <- taxize::classification(taxon_data$taxon_id)
      result <- lapply(result, setNames, nm = c("name", "rank_name", "taxon_id"))
    }
    if (!("name" %in% names(taxon_data))) {
      taxon_data$name <- extract_last(result, column = "name")
      taxon_id_key <- lapply(seq_along(taxon_id_key),
                             function(i) cbind(taxon_id_key[[i]], result[[i]][ , "name", drop = FALSE]))
    }    
    if (!("rank_name" %in% names(taxon_data))) {
      taxon_data$rank_name <- extract_last(result, column = "rank_name")
      taxon_id_key <- lapply(seq_along(taxon_id_key),
                             function(i) cbind(taxon_id_key[[i]], result[[i]][ , "rank_name", drop = FALSE]))
    }
  }
  # Add taxon info ---------------------------------------------------------------------------------
  map_item_to_taxon <- function(col_index) {
    data <- lapply(taxon_data$taxon_id,
                   function(x) unique(item_data[x == item_data$taxon_id & !is.na(item_data$taxon_id), col_index]))
    data[lapply(data, length) == 0] <- NA
    if (max(vapply(data, length, numeric(1))) > 1)
      stop(paste0("taxon_info field ", col_index - 1, " content does not correspond to taxa IDs.", 
                  " Perhaps an item_info field would be more appropriate."))
    return(unlist(data))
  }
  taxon_info_cols <- 1 + which(key == "taxon_info")
  if (length(taxon_info_cols) > 0) {
    taxon_data <- cbind(taxon_data, data.frame(lapply(taxon_info_cols, map_item_to_taxon)))    
  }
  # Add arbitrary item IDs to item data if necessary -----------------------------------------------
  if (!("item_id" %in% names(item_data))) item_data$item_id <- 1:nrow(item_data)
  # Add taxon parent column ------------------------------------------------------------------------
  get_parent <- function(taxa, classifications) {
    taxon_classifications <- lapply(taxon_data$taxon_id, function(x) classifications[[x]])
    parents <- lapply(taxon_classifications, function(x) x$taxon_id[nrow(x) - 1])
    parents[vapply(parents, length, numeric(1)) == 0] <- NA
    unlist(parents)
  }
  taxon_data$parent_id <- get_parent(taxon_data$taxon_id, taxon_id_key)
  # Format and return output -----------------------------------------------------------------------
  names(key)[names(key) == ""] <- names(item_data)[seq_along(key) + 1][names(key) == ""] 
  names(item_data)[seq_along(key) + 1] <- names(key)
  # Make 'classified' output class
  classified(taxon_id = taxon_data$taxon_id,
             parent_id = taxon_data$parent_id,
             item_taxon_id = item_data$taxon_id,
             taxon_data = taxon_data[ , ! colnames(taxon_data) %in% c("taxon_id", "parent_id"), drop = FALSE],
             item_data = item_data[ , ! colnames(item_data) %in% c("taxon_id"), drop = FALSE])
}


#' @method extract_taxonomy DNAbin
#' @export
#' @rdname extract_taxonomy
extract_taxonomy.DNAbin <- function(input, ...) {
  output <- extract_taxonomy(names(input), ...)
  output$item_data$sequence <- unlist(lapply(as.character(input),
                                             function(x) paste0(x, collapse = "")))
  return(output)
}