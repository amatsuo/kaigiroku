#' Convert Kaigiroku XML to well-forated data frame
#'
#' @param xml_out an xml object returned from kokkai kaigiroku API
#'
#' @return data.frame
#' @export
#'
#' @examples
#'
xml_to_speechdf <- function(xml_out){
  out_data <- NULL
  meetings_node <- getNodeSet(xml_out, "//meetingRecord")
  for(i in 1:length(meetings_node)){
    meeting_node <- meetings_node[[i]]
    meeting_list <- xmlToList(meeting_node, simplify = TRUE)
    meeting_list <- meeting_list[which(names(meeting_list) != "speechRecord")]
    meeting_info <- as.data.frame.list(unlist(meeting_list))
    speech_df <- xmlToDataFrame(node = getNodeSet(meeting_node, "speechRecord"),
                                stringsAsFactors = FALSE)
    meeting_df <- cbind(meeting_info, speech_df)
    
    out_data <- bind_rows(out_data, meeting_df)
  }
  return(out_data)
}
