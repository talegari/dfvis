#' @name add_sort_agg_column
#' @title Add sort aggregator to the dataframe
#' @description The added column is always named '.quantile'. This acts as an
#'   aggregator for downstream functions
#' @param df data.frame
#' @param sort_column_name (string) Name of the column to be used for sorting
#' @param respect_grouping (flag, default: TRUE) Whether the sorting should
#'   honour group structure in the input dataframe (if any)
#' @return Dataframe with new column added: '.quantile'
add_sort_agg_column = function(df,
                               sort_column_name,
                               respect_grouping = TRUE
                               ){

  # TODO
  # 1. Add options other than chopping by quantiles
  # 2. Provide chopping specific args like 'number_parts', ...

  stopifnot(inherits(df, "data.frame"))
  stopifnot(!(".quantile" %in% colnames(df)))
  stopifnot(sort_column_name %in% colnames(df))
  stopifnot(is.numeric(df[[sort_column_name]]))

  sort_col   = rlang::sym(sort_column_name)
  group_cols = dplyr::group_vars(df)

  if(respect_grouping){

    qdf = dplyr::mutate(
      df,
      .quantile = santoku::chop_quantiles(!!sort_col,
                                          probs = seq(0, 1, 0.01)
                                          )
      )
  } else {

    qdf = df %>%
      dplyr::ungroup() %>%
      dplyr::mutate(
        .quantile = santoku::chop_quantiles(!!sort_col,
                                            probs = seq(0, 1, 0.1)
                                            )
        ) %>%
      dplyr::grouped_df(group_cols)
  }

  return(qdf)
}

#' @name plot_column
#' @title Create plot object corresponding to a single column
#' @description Plot object depends of the type of variable
#' @param column_name (string) Name of the column
#' @param qdf dataframe with '.quantile' column
#' @return ggplot object
plot_column = function(column_name, qdf){

  # TODO
  # 1. Implement plot methods for other column types
  # 2. currently supported: numeric, factor
  # 3. Provide arguments specific to column type handling

  stopifnot(".quantile" %in% colnames(qdf))

  column     = rlang::sym(column_name)
  group_cols = dplyr::group_vars(qdf)

  if(is.factor(qdf %>% dplyr::pull(!!column))){

    df = qdf %>%
      dplyr::select(!!column, .quantile) %>%
      dplyr::group_by(.quantile, !!column, add = TRUE) %>%
      dplyr::summarise(n = n())

    po = df %>%
      ggplot(aes(.quantile, n, fill = !!column)) +
      geom_bar(position = position_fill(), stat = "identity") +
      ylab(column_name) +
      theme(legend.position="bottom",
            axis.text.y = element_blank(),
            axis.ticks = element_blank(),
            axis.title.y = element_blank()
            ) +
      guides(fill = guide_legend(title = NULL, ncol = 1)) +
      scale_fill_viridis_d() +
      coord_flip()

  } else {

    df = qdf %>%
      dplyr::group_by(.quantile, add = TRUE) %>%
      dplyr::summarise(mean_value = median(!!column),
                      lower = quantile(!!column, 0.25),
                      upper = quantile(!!column, 0.75)
                      )

    po = df %>%
      ggplot(aes(.quantile, mean_value)) +
      geom_point() +
      ylab(column_name) +
      geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.2) +
      theme(axis.text.y = element_blank(),
            axis.ticks = element_blank(),
            axis.title.y = element_blank()
            ) +
      coord_flip()

  }

  has_other_groups = function(df){

    others = setdiff(dplyr::group_vars(df), ".quantile")
    res    = (length(others) > 0)

    return(res)
  }


  if(has_other_groups(df)){
    po = po + facet_wrap(group_cols, ncol = 1)
  }

  return(po)
}

#' @name autoplot.data.frame
#' @title autplot method for dataframe
#' @description
#' @param object data.frame
#' @param sort_column_name (string) Name of the column to be used for sorting
#' @param respect_grouping (flag, default: TRUE) Whether the sorting should
#'   honour group structure in the input dataframe (if any)
#' @return patchwork object
#' @importFrom ggplot2 autoplot
#' @export
autoplot.data.frame = function(object,
                               sort_column_name,
                               respect_grouping = TRUE){

  # TODO
  # 1. Figure out maximum number of columns should be printed depending on
  #   - readability
  #   - cognitive comprehension
  # 2. Setting these kind of options at global level for a R session
  #    might be a good idea
  # 3. Add metadata annotations (tabplot does some)

  qdf   = add_sort_agg_column(object, sort_column_name, respect_grouping)
  plots = lapply(colnames(object), plot_column, qdf)
  res   = patchwork::wrap_plots(plots, nrow = 1, guides = "keep")

  return(res)
}
