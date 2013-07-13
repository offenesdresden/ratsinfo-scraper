ratsinfo-scraper
================

Scrape documents with associated metadata from http://ratsinfo.dresden.de

INSTALLATION
------------

0. Get the code

   $ git clone https://github.com/Mic92/ratsinfo-scraper.git

1. Get ruby

   $ \curl -L https://get.rvm.io | bash -s stable

2. Install bundler

   $ gem install bundler

3. Install Dependencies

   $ cd ratsinfo
   
   $ bundle install


USAGE
-----

To start scraping use:

   $ rake scrape

This will extract all documents to the path of the environment variable DOWNLOAD_PATH (defaults
to "data").

The download directory will have the following scheme:

- each session have a directory, where the id is the directory name
- every document belonging to this session will be extracted to this directory
- additionally a file called metadata.json is created, which contains a
  machine-readable version of the index.htm file, which is contained in the
  document archives

The metadata.json file follow this structure. (optional means null-values
for strings or empty array, required values should be always available)

- id: (required) a human-readable identifier of the session, ex: "SR/003/2009"
- description: (required) the long name of the session, ex "3. Sitzung des Stadtrates"
- committee: (required) the board, holding the session, ex "Stadtrat"
- started_at: (required) the time when the session started (converted from CEST time), ex "2009-10-01T14:00:00Z"
- ended_at: (required) the time when the session ended (converted from CEST time), ex "2009-10-01T18:30:00Z"
- location: (optional) the location where the session took place, ex "Landeshauptstadt Dresden,  im Neuen Rathaus, Plenarsaal,Rathausplatz 1, 01067 Dresden"
- download_at: (required) the time when the archive was downloaded
- documents: documents associated with the session (excluding those associated
  with parts)
- parts: (optional) each session can be contains an array of parts.
  a part is an object containing the following keys:
  - description: (required) name of the part, ex "Beschlussvorlagen zu VOB-Vergaben"
  - template_id: (optional) some parts uses templates, further information here http://ratsinfo.dresden.de/vo0042.php
  - documents: (optional) array of documents associated with this part
     - file_name: the file name as it is in the session directory, ex: "00003144.pdf"
     - description: name of the document, ex: "Vorlage Gremien"
  - decision: (optional) some sessions ended with a decision made by the comittee, ex: "Zustimmung"
  - vote_result: (optional) object
     - pro: (required) votes for the subject, ex: 1
     - contra: (required) votes against the subject, ex: 2
     - abstention: (required) neither/nor contra or pro, ex: 0

TODO
----

- [] continue, where the last scan stopped
- [] templates for custom tasks
- [] clean up task
- [] some kind of tests
