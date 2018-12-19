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
#' for one API call (2 records per call), this function will repeatedly call the
#' API until all records are obtained.
#' @param house Name of the house, value is "Upper" (Sangiin), "Lower" (Shugin), or "Both" (Ryouin)
#' @param sessionNumber integer, session number
#' @param startDate starting date to obtain the record in the format of "%Y-%m-%d"
#'  (e.g. "1999-01-01"), if you specified session number, you cannot assign this
#'  option.
#' @param endDate ending date to obtain the record in the format of "%Y-%m-%d"
#'  (e.g. "1999-01-01"), if you specified session number, you cannot assign this
#'  option.
#' @param year integer, year
#' @param meetingName name of the meeting in Japanese. example "Yosan iinkai", "Honkaigi"
#' @param searchTerms search terms. either vector of search terms or a string of
#' search terms separated by a space
#' @param verbose display detailed message about the download progress
#' @param sleep the length of break between each time to fetch the record (in seconds)
#' @param downloadMessage show \code{download.file()} progress, default \code{FALSE}
#' @param ...
#'
#' @return the function returns a data.frame of speeches.
#' @export
#'
#' @examples
#' budget_122 <- get_meeting(meetingName = "予算委員会", sessionNumber = 122)
#' head(budget_122)
get_meeting <- function(house = "Lower", sessionNumber = NA,
                        startDate = NA, endDate = NA, year = NA,
                        meetingName = NA,
                        searchTerms = NA,
                        verbose = TRUE,
                        downloadMessage = FALSE,
                        sleep = 3,
                        ... ) {
  require("XML")
  require("dplyr")
  require("R.utils")
  if(! (house %in% c("Upper", "Lower", "Both"))) {
    stop("house parameter has to be one of c(\"Upper\", \"Lower\", \"Both\")")
  }
  houseName <- ifelse(house == "Lower", "\u8846\u8B70\u9662",
                      ifelse( house == "Upper", "\u53C2\u8B70\u9662",
                              "\u4E21\u9662"))

  if(is.na(meetingName)) {
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
    data("session_info")
    startDate <- session_info[session_info$sessionNumber == sessionNumber, "startDate"]
    endDate <- session_info[session_info$sessionNumber == sessionNumber, "endDate"]
  }
  searchCondition <- sprintf("nameOfHouse=%s&nameOfMeeting=%s&from=%s&until=%s",
                             houseName, meetingName, startDate, endDate)
  speechdf <- api_access_function(api_function = "meeting",
                                  searchCondition = searchCondition,
                                  searchTerms = searchTerms,
                                  verbose = verbose,
                                  downloadMessage = downloadMessage,
                                  sleep = sleep)
  return(speechdf)
}

api_access_function <- function(api_function,  searchCondition,
                                searchTerms = NA, verbose, sleep,
                                downloadMessage){
  if(!is.na(searchTerms)){
    searchTerms <- unlist(strsplit(searchTerms, "\\s+"))
    searchCondition <- paste(searchCondition, sprintf("any=%s", searchTerms),
                             sep = "&")
  }
  searchConditionEnc <- URLencode(searchCondition, reserved = TRUE)
  if(api_function == "meeting"){
    baseUrl <- "http://kokkai.ndl.go.jp/api/1.0/meeting"
  } else {
    baseUrl <- "http://kokkai.ndl.go.jp/api/1.0/speech"
  }
  url <- paste(baseUrl, searchConditionEnc, sep = "?")
  #xml_out <- xmlParse(url, isURL = TRUE)
  quiet <- !downloadMessage
  tmp_file <- file_download(url, quiet = quiet)
  xml_out <- xmlParse(tmp_file)
  file.remove(tmp_file)

  # stop if no record found
  # saveXML(xmlRoot(xml_out), file = 'R/test_scripts/xml_dump.txt')
  #browser()
  numberOfRecords <- getNodeSet(xml_out, "//numberOfRecords")[[1]] %>%
    xmlValue() %>% as.numeric(.)
  if( numberOfRecords == 0)
  {
    warning(paste0("No record to match the search criteria\n\t", searchCondition))
    return(NULL)
  } else {
    cat(sprintf("%s records found\n", numberOfRecords))
    if(verbose) cat(paste0("Fetching (current_record_position: ", 1, ")\n"))
  }
  speechdf <- xml_to_speechdf(xml_out)

  # Loop when more than 2 records
  if(length(getNodeSet(xml_out, "//nextRecordPosition")) > 0) {
    nextRecordPosition_prev <- 0
    while(1) {
      Sys.sleep(sleep)
      nextRecordPosition <- getNodeSet(xml_out, "//nextRecordPosition")[[1]] %>%
        xmlValue() %>% as.numeric
      if(nextRecordPosition == nextRecordPosition_prev) {
        nextRecordPosition <- nextRecordPosition_prev + position_increment
        message("error recovery: set current_record_position at ", nextRecordPosition)
      } else {
        position_increment <- nextRecordPosition - nextRecordPosition_prev
      }
      if(verbose) cat(paste0("Fetching (current_record_position: ", nextRecordPosition, ")\n"))
      searchConditionCont <- sprintf("%s&startRecord=%s", searchCondition,
                                     nextRecordPosition)
      searchConditionEnc <- URLencode(searchConditionCont, reserved = TRUE)
      url <- paste(baseUrl, searchConditionEnc, sep = "?")


      tmp_file <- file_download(url, quiet)
      xml_out <- xmlParse(tmp_file)
      file.remove(tmp_file)


      speechdf <- rbind(speechdf, xml_to_speechdf(xml_out))
      nextRecordPosition_prev <- nextRecordPosition

      if(length(getNodeSet(xml_out, "//nextRecordPosition")) == 0) {
        break
      }

    }
  }
  speechdf$speech <- as.character(speechdf$speech)
  class(speechdf) <- c(class(speechdf), "kaigroku_data")
  return(speechdf)
}

file_download <- function(url, quiet = FALSE){
  tmp_file <- tempfile()
  counter <- 0
  browser()
  while(!file.exists(tmp_file)) {
    tryCatch(withTimeout(download.file(url, tmp_file, quiet = quiet), timeout = 45),
             TimeoutException = function(ex) {
               counter <<- counter + 1
               if(counter >= 10) {
                 break
               }
               if(file.exists(tmp_file)) file.remove(tmp_file)
               message("\nDownload timeout, will retry (trycount #", counter,')')
             },
             error = function(e) {
               print(e)
               counter <<- counter + 1
               if(counter >= 10) {
                 break
               }
               if(file.exists(tmp_file)) file.remove(tmp_file)
               message("\nDownload error, will retry (trycount #", counter,')')
             }
    )
  }
  Sys.sleep(1)
  return(tmp_file)
}
