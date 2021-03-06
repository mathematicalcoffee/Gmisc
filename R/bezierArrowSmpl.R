#' A simple bezier arrow
#'
#' This is an alternative to the grid packages \code{\link[grid]{bezierGrob}}
#' with the advantage that it allows you to draw an arrow with a specific
#' unit width. Note, it has only a end-arrow at this point.
#'
#' @inheritParams grid::bezierGrob
#' @param width The width of the arrow, either a numeric single number or a unit. \strong{Note:}
#'  The arrow does not rely on lwd but on actual width.
#' @param clr The color of the arrow.
#' @param arrow This is a list with all the \strong{base} (width) and the desired 
#' \strong{length} for the arrow. \strong{Note:} This differs from the original 
#' \code{\link{bezierGrob}} function.
#' @param align_2_axis Indicates if the arrow should be vertically/horizontally 
#'  aligned. This is useful for instance if the arrow attaches to a box.
#' @param name A character identifier.
#' @return \code{grid::grob} A grob of the class polygonGrob with attributes that 
#'  correspond to the bezier points.
#'
#' @examples
#' library(grid)
#' grid.newpage()
#' arrowGrob <- bezierArrowSmpl(x = c(.1,.3,.6,.9),
#'                              y = c(0.2, 0.2, 0.9, 0.9))
#' grid.draw(arrowGrob)
#'
#' @import grid
#' @export
bezierArrowSmpl <- function(x = c(0.2, .7, .3, .9),
                            y = c(0.2, .2, .9, .9),
                            width = .05,
                            clr = "#000000",
                            default.units = "npc",
                            arrow = list(base=unit(.1, "npc"),
                                         length = unit(.1, "npc")),
                            align_2_axis = TRUE,
                            name = NULL,
                            gp = gpar(), vp = NULL){
  if (class(x) != "unit")
    x <- unit(x, default.units)
  if (class(y) != "unit")
    y <- unit(y, default.units)
  if (class(arrow$base) != "unit")
    arrow$base <- unit(arrow$base, default.units)
  if (class(arrow$length) != "unit")
    arrow$length <- unit(arrow$length, default.units)
  if (class(width) != "unit")
    width <- unit(width, default.units)

  # Internally we want to avoid using the "npc" and we therefore
  # switch to mm that is consistent among the axes. This compromises
  # the portability of the grob but it is a price worth paying
  internal.units <- "mm"
  x <- convertX(x, unitTo=internal.units, valueOnly=TRUE)
  y <- convertY(y, unitTo=internal.units, valueOnly=TRUE)


  if (length(y) != length(x))
    stop("You have provided unequal lengths to y and x - thus uninterpretable:",
      " y=", length(y), " elements",
      " while x=", length(x), " elements")

  # According to the original description they're all spline
  # control points but as I want the line to start and end
  # at specific points then this makes sense to me
  end_points <- list(start=list(x=x[1],
                                y=y[1]),
                     end=list(x=tail(x, 1),
                              y=tail(y, 1)))

  spline_ctrl <- list(x=x[2:(length(x)-1)],
                      y=y[2:(length(y)-1)])

  # Get the length of the spline control through sqrt(a^2+b^2)
  spline_ctrl$start$length <- sqrt((spline_ctrl$x[1] - end_points$start$x)^2+
      (spline_ctrl$y[1] - end_points$start$y)^2)
  spline_ctrl$end$length <- sqrt((tail(spline_ctrl$x,1) - end_points$end$x)^2+
      (tail(spline_ctrl$y, 1) - end_points$end$y)^2)

  # TODO: extend to multiple ctrl points as regular bezier curves as they do for instance in Inkscape
  bz_grob <- bezierGrob(x=c(end_points$start$x, spline_ctrl$x, end_points$end$x),
                        y=c(end_points$start$y, spline_ctrl$y, end_points$end$y),
                        default.units=internal.units, vp=vp)
  bp <- bezierPoints(bz_grob)
  # Change to values that we can work with arithmetically
  bp$y <- convertY(bp$y, unitTo=internal.units, valueOnly=TRUE)
  bp$x <- convertX(bp$x, unitTo=internal.units, valueOnly=TRUE)
  getBzLength <- function(x, y){
    m <- rbind(y, x)
    # Map the change between coordinates
    m <- m[, 2:ncol(m)] - m[, 1:(ncol(m)-1)]
    # Set first element to 0 length
    m <- cbind(c(0,0), m)
    # The old sqrt(a^2+b^2) formula
    return(sqrt(colSums(m^2)))
  }

  getBestMatchForArrowLengthAlongCurve <- function (bp, arrow_length,
                                                    internal.units) {

    arrow_length <- getGridVal(arrow_length, internal.units)

    dist2end <- sqrt((bp$x-tail(bp$x, 1))^2+
            (bp$y-tail(bp$y, 1))^2)
    best_point <- tail(which(dist2end > arrow_length), 1)

    return(best_point)
  }
  bp$cut_point <- getBestMatchForArrowLengthAlongCurve(bp, arrow$length, internal.units)

  # Set the arrow details according to this new information
  arrow$x <- end_points$end$x - bp$x[bp$cut_point]
  arrow$y <- end_points$end$y - bp$y[bp$cut_point]
  #arrow$length <- sqrt(arrow$x^2+arrow$y^2)

  getBezierAdjustedForArrow <- function(bp, end_points,
                                        spline_ctrl, arrow,
                                        internal.units){
    a_l <- getGridVal(arrow$length, internal.units)

    # Special case where the end spline control isn't used
    if (spline_ctrl$end$length == 0){
      multiplier <- 0
    }else{
      multiplier <- (spline_ctrl$end$length-a_l*1.1)/spline_ctrl$end$length
    }

    # Use the arrow's vector in the opposite direction as the new ctrl point
    adjust_ctr <- function(spl_point, org_endpoint,
                           new_endpoint, arrow,
                           multiplier){

      # Shorten/lengthen depending on the arrow direction
      if (new_endpoint < org_endpoint){
        direction <- 1
      }else{
        direction <- -1
      }

      # The minimum spline control is the arrow length
      min_adjusted <- new_endpoint-(org_endpoint-new_endpoint)

      new_sppoint <- spl_point + direction*arrow*multiplier

      if (direction*(min_adjusted - new_sppoint) < 0)
        new_sppoint <- min_adjusted

      return(new_sppoint)
    }
    spline_ctrl$x[length(spline_ctrl$x)] <-
      adjust_ctr(tail(spline_ctrl$x, 1),
                 tail(bp$x, 1),
                 bp$x[bp$cut_point],
                 arrow$x, multiplier)
    spline_ctrl$y[length(spline_ctrl$y)] <-
      adjust_ctr(tail(spline_ctrl$y, 1),
                 tail(bp$y, 1),
                 bp$y[bp$cut_point],
                 arrow$y, multiplier)

    # Relate to full length
    tot_line_length <- sum(getBzLength(x = bp$x, y= bp$y))
    simple_start_adjustment <- 1-a_l/tot_line_length/3
    # Remove a fraction of the distance for the spline controles
    spline_ctrl$x[1] <- end_points$start$x + (spline_ctrl$x[1]-end_points$start$x)*simple_start_adjustment
    spline_ctrl$y[1] <- end_points$start$y + (spline_ctrl$y[1]-end_points$start$y)*simple_start_adjustment

    return(bezierGrob(x=c(end_points$start$x, spline_ctrl$x,
                          bp$x[bp$cut_point]),
                      y=c(end_points$start$y, spline_ctrl$y, bp$y[bp$cut_point]),
                      default.units=internal.units,
                      vp=vp))
  }

  new_bz_grob <- getBezierAdjustedForArrow(bp, end_points,
                                           spline_ctrl, arrow,
                                           internal.units)


  # Get the bezier points that are adjusted for the arrow
  new_bp <- bezierPoints(new_bz_grob)
  new_bp$y <- convertY(new_bp$y, unitTo=internal.units, valueOnly=TRUE)
  new_bp$x <- convertX(new_bp$x, unitTo=internal.units, valueOnly=TRUE)

  extendBp2MatchArrowLength <- function (bp, end, arrow_length, internal.units){
    arrow_length <- getGridVal(arrow_length, internal.units)
    bp_last_x <- tail(bp$x, 1)
    bp_last_y <- tail(bp$y, 1)
    dist2end <- sqrt((bp_last_x-end$x)^2+
            (bp_last_y-end$y)^2)

    if (dist2end != arrow_length){
      partial_distance <- 1-arrow_length/dist2end
      add_x <- bp_last_x +
          (end$x-bp_last_x)*partial_distance
      add_y <- bp_last_y +
          (end$y-bp_last_y)*partial_distance
      # Insert new point
      bp$x <- c(bp$x, add_x)
      bp$y <- c(bp$y, add_y)
    }

    return (bp)
  }
  new_bp <- extendBp2MatchArrowLength(new_bp,
      end = end_points$end,
      arrow_length = arrow$length,
      internal.units = internal.units)

  # Get lengths
  new_bp$lengths <- getBzLength(new_bp$x, new_bp$y)

  # Add the arrow length to the last element
  new_bp$lengths[length(new_bp$lengths)] <- tail(new_bp$lengths, 1) +
    getGridVal(arrow$length, internal.units)
  lines <- getLinesWithArrow(bp = new_bp,
      arrow = arrow,
      width = width,
      end_points = end_points,
      default.units = internal.units,
      align_2_axis = align_2_axis)

  # Change evrything to default.units from internal
  lines$left$x <- convertX(lines$left$x, unitTo=default.units)
  lines$right$x <- convertX(lines$right$x, unitTo=default.units)

  lines$left$y <- convertY(lines$left$y, unitTo=default.units)
  lines$right$y <- convertY(lines$right$y, unitTo=default.units)

  new_bp$x <- convertX(unit(new_bp$x, internal.units), unitTo=default.units)
  new_bp$y <- convertY(unit(new_bp$y, internal.units), unitTo=default.units)
  # The length cannot be converted into npc
  new_bp$length <- unit(new_bp$length, internal.units)

  end_points$start$x <- convertX(unit(end_points$start$x, internal.units),
                                 unitTo=default.units)
  end_points$start$y <- convertY(unit(end_points$start$y, internal.units),
                                 unitTo=default.units)
  end_points$end$x <- convertX(unit(end_points$end$x, internal.units),
                                 unitTo=default.units)
  end_points$end$y <- convertY(unit(end_points$end$y, internal.units),
                               unitTo=default.units)

  poly_x <- unit.c(lines$left$x,
                   rev(lines$right$x))
  poly_y <- unit.c(lines$left$y,
                   rev(lines$right$y))
  pg <- polygonGrob(x=poly_x,
                    y=poly_y,
                    gp=gpar(fill=clr, col=clr), # col=NA, - messes up the anti-aliasing
                    name = name,
                    vp = vp)

  # Add details that are used by the gradient version
  attr(pg, "center_points") <- new_bp
  attr(pg, "upper_points") <- lines$left
  attr(pg, "lower_points") <- lines$right
  attr(pg, "end_points") <- end_points

  return(pg)
}
