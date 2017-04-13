#' Get speeches by meeting
#'
#' @description This function returns all speeches based on the specified conditions.
#' Three parameters have to be specified. The first is the name of house
#' (\code{house}).
#' The second is the name of meeting
#' (\code{meetingName}) (e.g. "文教委員会", "本会議").
#' And the third is the time period. There are three ways to specifiy the time period
#' (1. starting and ending date, 2. National Diet session number, and 3.
#' year). If the specified conditions exceed the limit of the number of records
#' for one API call (2 records per call), this function will repeatedly call the
#' API until all records are obtained.
#' @param house Name of the house, value is "Upper", "Lower", or "Both"
#' @param sessionNumber integer, session number
#' @param startDate starting date to obtain the record in the format of "%Y-%m-%d"
#'  (e.g. "1999-01-01"), if you specified session number, you cannot assign this
#'  option.
#' @param endDate ending date to obtain the record in the format of "%Y-%m-%d"
#'  (e.g. "1999-01-01"), if you specified session number, you cannot assign this
#'  option.
#' @param year integer, year
#' @param meetingName name of the meeting in Japanese. example "予算委員会", "本会議"
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
                        ... ) {
  if(! (house %in% c("Upper", "Lower", "Both"))) {
    stop("house parameter has to be one of c(\"Upper\", \"Lower\", \"Both\")")
  }
  houseName <- ifelse(house == "Lower", "衆議院",
                      ifelse( house == "Upper", "参議院", "両院"))

  if(is.na(meetingName)) {
    stop("you need to specify meetingName (e.g. 予算委員会)")
  }

  if(sum(!is.na(c(sessionNumber, startDate, endDate, year))) == 0 ){
    stop("You need to specify one of followings:
         startDate and endDate,
         sessionNumber, or
         year")
  }
  if(sum(!is.na(c(sessionNumber, startDate, endDate, year))) > 2 |
     (sum(!is.na(c(sessionNumber, startDate, endDate, year))) == 2 &
      sum(is.na(c(startDate, endDate)) == 0))){
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
  searchConditionEnc <- URLencode(searchCondition, reserved = TRUE)
  baseUrlMeeting <- "http://kokkai.ndl.go.jp/api/1.0/meeting"
  # return(searchCondition)
  url <- paste(baseUrlMeeting, searchConditionEnc, sep = "?")
  xml_out <- xmlParse(url, isURL = TRUE)

  # stop if no record found
  saveXML(xmlRoot(xml_out), file = 'R/test_scripts/xml_dump.txt')
  #browser()
  numberOfRecords <- getNodeSet(xml_out, "//numberOfRecords")[[1]] %>%
    xmlValue() %>% as.numeric(.)
  if( numberOfRecords == 0)
  {
    stop(paste0("No record to match the search criteria\n\t", searchCondition))
  } else {
    cat(sprintf("%s records found\n", numberOfRecords))
    cat("Fetching, startingRecord = 1\n")
  }
  speechdf <- xml_to_speechdf(xml_out)

  # Loop when more than 2 records
  if(length(getNodeSet(xml_out, "//nextRecordPosition")) > 0) {
    while(1) {
      nextRecordPosition <- getNodeSet(xml_out, "//nextRecordPosition")[[1]] %>%
        xmlValue() %>% as.numeric
      cat("Fetching, startingRecord =", nextRecordPosition, "\n")
      searchConditionCont <- sprintf("%s&startRecord=%s", searchCondition,
                                     nextRecordPosition)
      searchConditionEnc <- URLencode(searchConditionCont, reserved = TRUE)
      url <- paste(baseUrlMeeting, searchConditionEnc, sep = "?")
      xml_out <- xmlParse(url, isURL = TRUE)
      speechdf <- rbind(speechdf, xml_to_speechdf(xml_out))
      if(length(getNodeSet(xml_out, "//nextRecordPosition")) == 0) {
        break
      }

    }
  }
  return(speechdf)
}

