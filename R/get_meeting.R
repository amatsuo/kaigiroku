#' Get speeches by meeting
#'
#' @description This function returns all speeches based on the specified conditions.
#' Three parameters have to be specified. The first is the name of house
#' (\code{house}).
#' The second is the name of meeting in Japanese
#' (\code{meetingName}) (e.g. "Yosan Inkai", "Honkaigi").
#' And the third is the time period. There are three ways to specifiy the time period
#' (1. starting and ending date, 2. National Diet session number, and 3.
#' year). If the specified conditions exceed the limit of the number of records
#' for one API call (3 records per call), this function will repeatedly call the
#' API until all records are obtained.
#' @param house Name of the house, value is "Upper" (Sangiin), "Lower" (Shugin), or "Both" (Ryouin).
#' @param sessionNumber integer, session number.
#' @param startDate starting date to obtain the record in the format of "%Y-%m-%d"
#'  (e.g. "1999-01-01"), if you specified session number, you cannot assign this
#'  option.
#' @param endDate ending date to obtain the record in the format of "%Y-%m-%d"
#'  (e.g. "1999-01-01"), if you specified session number, you cannot assign this
#'  option.
#' @param year integer, year of the record.
#' @param meetingName name of the meeting in Japanese. example "Yosan iinkai", "Honkaigi".
#' @param searchTerms search terms. either vector of search terms or a string of
#' search terms separated by a space.
#' @param verbose display detailed message about the download progress.
#' @param sleep the length of break between each time to fetch the record (in seconds).
#' @param downloadMessage show \code{download.file()} progress, default \code{FALSE}.
#' @param meeting_list get the list of meeting, instead of actual speeches. Default \code{FALSE}.
#'
#' @return the function returns a data.frame of speeches.
#' @export
#'
#' @examples
#' \dontrun{
#' hm_122 <- get_meeting(meetingName = "\u904B\u8F38\u59D4\u54E1\u4F1A", sessionNumber = 126)
#' head(hm_122)
#' }
#' 
#' @importFrom utils data
get_meeting <- function(house = "Lower", sessionNumber = NA,
                        startDate = NA, endDate = NA, year = NA,
                        meetingName = NA,
                        searchTerms = NA,
                        verbose = TRUE,
                        downloadMessage = FALSE,
                        sleep = 3, 
                        meeting_list = FALSE) {
  # require("jsonlite")
  # require("tidyr")
  # require("XML")
  # require("dplyr")
  # require("R.utils")
  if(! (house %in% c("Upper", "Lower", "Both"))) {
    stop("house parameter has to be one of c(\"Upper\", \"Lower\", \"Both\")")
  }
  houseName <- ifelse(house == "Lower", "\u8846\u8B70\u9662",
                      ifelse( house == "Upper", "\u53C2\u8B70\u9662",
                              "\u4E21\u9662"))

  if(is.na(meetingName) & meeting_list == FALSE) {
    stop("you need to specify meetingName (e.g. \u4E88\u7B97\u59D4\u54E1\u4F1A)")
  }

  if(sum(!is.na(c(sessionNumber, startDate, endDate, year))) == 0 ){
    stop("You need to specify one of followings:
         startDate and endDate,
         sessionNumber, or
         year")
  }
  if(sum(!is.na(c(sessionNumber, startDate, endDate, year))) > 2 |
     (sum(!is.na(c(sessionNumber, startDate, endDate, year))) == 2 &
      sum(is.na(c(startDate, endDate)) != 0))){
    stop("Too many parameters are specifid, you need to specy either
         startDate and endDate,
         sessionNumber, or
         year")
  }

  if(!is.na(startDate)) {
    startDate <- as.Date(startDate)
    endDate <- as.Date(endDate)
  } else if(!is.na(year)) {
    startDate <- as.Date(paste0(year, "-01-01"))
    endDate <- as.Date(paste0(year, "-12-31"))
  } else {
    data("session_info", envir = environment())
    startDate <- session_info[session_info$sessionNumber == sessionNumber, "startDate"]
    endDate <- session_info[session_info$sessionNumber == sessionNumber, "endDate"]
  }
  if(!is.na(meetingName)){
    searchCondition <- sprintf("nameOfHouse=%s&nameOfMeeting=%s&from=%s&until=%s",
                               houseName, meetingName, startDate, endDate)
  } else {
    searchCondition <- sprintf("nameOfHouse=%s&from=%s&until=%s",
                               houseName, startDate, endDate)
  }
  if(meeting_list == T){
    api_func <- "meeting_list"
  } else {
    api_func <- "meeting"
  }
  speechdf <- api_access_function(api_function = api_func,
                                  searchCondition = searchCondition,
                                  searchTerms = searchTerms,
                                  verbose = verbose,
                                  downloadMessage = downloadMessage,
                                  sleep = sleep)
  return(speechdf)
}


#' @importFrom utils URLencode
#' @import dplyr
api_access_function <- function(api_function,  searchCondition,
                                searchTerms = NA, verbose, sleep,
                                downloadMessage){
  if(!is.na(searchTerms)){
    searchTerms <- unlist(strsplit(searchTerms, "\\s+"))
    searchCondition <- paste(searchCondition, sprintf("any=%s", searchTerms),
                             sep = "&")
  }
  searchCondition <- paste(searchCondition, "recordPacking=json", sep = "&")
  searchConditionEnc <- URLencode(searchCondition, reserved = TRUE)
  if(api_function == "meeting"){
    baseUrl <- "http://kokkai.ndl.go.jp/api/meeting"
  } else {
    baseUrl <- "http://kokkai.ndl.go.jp/api/meeting_list"
  }
  url <- paste(baseUrl, searchConditionEnc, sep = "?")
  #xml_out <- xmlParse(url, isURL = TRUE)
  quiet <- !downloadMessage
  tmp_file <- file_download(url, quiet = quiet)
  json_out <- jsonlite::fromJSON(tmp_file)
  file.remove(tmp_file)
  
  # xml_out <- xmlParse(tmp_file, encoding = "UTF-8")
  # file.remove(tmp_file)

  # stop if no record found
  # saveXML(xmlRoot(xml_out), file = 'R/test_scripts/xml_dump.txt')
  #browser()
  numberOfRecords <- json_out$numberOfRecords %>%  as.numeric()
    
  # numberOfRecords <- getNodeSet(xml_out, "//numberOfRecords")[[1]] %>%
  #   xmlValue() %>% as.numeric(.)
  if( numberOfRecords == 0)
  {
    warning(paste0("No record to match the search criteria\n\t", searchCondition))
    return(NULL)
  } else {
    cat(sprintf("%s records found\n", numberOfRecords))
    if(verbose) cat(paste0("Fetching (current_record_position: ", 1, ")\n"))
  }
  # speechdf <- xml_to_speechdf(xml_out)
  if(api_function == "meeting") {
    speechdf <- tidyr::unnest(json_out$meetingRecord, cols = c("speechRecord"))
  } else {
    speechdf <- json_out$meetingRecord %>% as_tibble %>% select(-"speechRecord")
  }

  # Loop when more than 2 records
  # if(length(getNodeSet(xml_out, "//nextRecordPosition")) > 0) {
  if(!is.null(json_out$nextRecordPosition)) {
    nextRecordPosition_prev <- 0
    while(1) {
      Sys.sleep(sleep)
      nextRecordPosition <- json_out$nextRecordPosition %>% as.numeric
      if(nextRecordPosition == nextRecordPosition_prev) {
        nextRecordPosition <- nextRecordPosition_prev + position_increment
        message("error recovery: set current_record_position at ", nextRecordPosition)
      } else {
        position_increment <- nextRecordPosition - nextRecordPosition_prev
      }
      if(verbose) cat(paste0("Fetching (current_record_position: ", nextRecordPosition, ")\n"))
      searchConditionCont <- sprintf("%s&startRecord=%s&recordPacking=json", searchCondition,
                                     nextRecordPosition)
      searchConditionEnc <- URLencode(searchConditionCont, reserved = TRUE)
      url <- paste(baseUrl, searchConditionEnc, sep = "?")


      tmp_file <- file_download(url, quiet)
      if(is.null(tmp_file)) {
        next
      }
      json_out <- jsonlite::fromJSON(tmp_file)
      file.remove(tmp_file)
      if(api_function == "meeting") {
        speechdf <- bind_rows(speechdf, tidyr::unnest(json_out$meetingRecord, cols = c("speechRecord")))
      } else {
        speechdf <- bind_rows(speechdf, json_out$meetingRecord %>% as_tibble %>% select(-"speechRecord"))
      }
      
      nextRecordPosition_prev <- nextRecordPosition
      if(is.null(json_out$nextRecordPosition)) {
        break
      }

    }
  }
  #speechdf$speech <- as.character(speechdf$speech)
  class(speechdf) <- c(class(speechdf), "kaigroku_data")
  return(speechdf)
}




#' @importFrom utils download.file
file_download <- function(url, quiet = FALSE){
  tmp_file <- tempfile()
  counter <- 0
  while(!file.exists(tmp_file)) {
    if(counter <= 8) to <- 45
    else to <- 300
    tryCatch(R.utils::withTimeout(download.file(url, tmp_file, quiet = quiet), timeout = to),
             TimeoutException = function(ex) {
               counter <<- counter + 1
               if(file.exists(tmp_file)) file.remove(tmp_file)
               if(counter >= 10){
                 message("Download failed too many times. Go to next record")
                 return(NULL)
               } else if(counter >= 8){
                 message("\nDownload timeout, will retry after 60 seconds (trycount #", counter,')')
                 Sys.sleep(60)
               } else {
                 message("\nDownload timeout, will retry after 10 seconds (trycount #", counter,')')
                 Sys.sleep(10)
               }
             },
             error = function(e) {
               print(e)
               counter <<- counter + 1
               if(file.exists(tmp_file)) file.remove(tmp_file)
               if(counter >= 10){
                 message("Download failed too many times. Go to next record")
                 return(NULL)
               } else if(counter >= 8){
                 message("\nDownload error, will retry after 60 seconds (trycount #", counter,')')
                 Sys.sleep(60)
               } else {
                 message("\nDownload error, will retry after 10 seconds (trycount #", counter,')')
                 Sys.sleep(10)
               }
             }
    )
  }
  Sys.sleep(1)
  return(tmp_file)
}
