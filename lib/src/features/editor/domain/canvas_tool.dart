/// Active tool for the designer canvas surface.
enum CanvasTool {
  select,
  frame,
  rect,
  circle,
  line,
  text,

  /// Same placement as [line] (vector stroke); separate id for toolbar grouping.
  pen,
  arrow,
  polygon,
  star,
  image,
}
