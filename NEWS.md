# v0.5 (2022/05/27)

* Switch from XML to json 
  * Now get the data in JSON format
  * Does not require XML package anymore. Instead, use jsonline and tidyr (for unnesting).
* Add the functionality of `meeting_list` download. This will help to identify names of meeting in the specific period.

# v0.2.2 (2022/01/03)

* Specify the encoding in XML parsing
* Bug fix for missing fields

# v0.2.1 (2020/01/22)

* Dealing with API change
  - the returning data.frame include new fields (e.g.  "speakerYomi", "speakerGroup", "speakerPosition")

# v0.2 (2018/12/19)

* Fully implement the download failure recovery

# v0.1.3 (2018/11/28)

* Dealing with the slow response of the server

# v0.1.2

* Update `session_info.rda` up to the end of Session 194

# v0.1.1

* The first workable version
