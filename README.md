ratsinfo-scraper
================

Scrape documents with associated metadata from http://ratsinfo.dresden.de

INSTALLATION
------------

Get the code

    git clone https://github.com/Mic92/ratsinfo-scraper.git

Get ruby (>= 2.0.0)

    gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
    \curl -sSL https://get.rvm.io | bash -s stable
    rvm install 2.2.3
    rvm --default use 2.2.3

Install bundler

    gem install bundler

Install Dependencies

    cd ratsinfo
    bundle install

USAGE
-----

To start scraping use:

    rake

This will extract all documents to the path of the environment variable DOWNLOAD_PATH (defaults to "data") and convert it to plain text

To scrape an individual session for example: [http://ratsinfo.dresden.de/to0040.php?\_\_ksinr=100](http://ratsinfo.dresden.de/to0040.php?\_\_ksinr=100)

    rake scrape_session[100]

To display all tasks use:

    rake -T

The download directory will have the following scheme:

- each session have a directory, where the id is the directory name
- every document belonging to this session will be extracted to this directory
- if the document is an pdf, it try to extract each page into a plain text file using the
  [pdf-reader](https://github.com/yob/pdf-reader) gem (00143511.pdf -> 00143511_0.txt, 00143511_1.txt, 00143511_2.txt)
- additionally a JSON file is created, with the session id in its name. This is a machine-readable
  version of the index.htm file, which is contained in the document archives

This JSON file follow this structure. (optional means null-values
for strings or empty array, required values should be always available)

<table>
<tr>
  <th>Key</th> <th>Value</th>
</tr>
<tr>
  <th>id</th>
  <td>(required) a human-readable identifier of the session, ex: "SR/003/2009"</td>
</tr>
<tr>
  <th>description</th>
  <td>(required) the long name of the session, ex "3. Sitzung des Stadtrates"</td>
</tr>
<tr>
  <th>committee</th>
  <td>(required) the board, holding the session, ex "Stadtrat"</td>
</tr>
<tr>
  <th>started_at</th>
  <td>(required) the time when the session started (converted from CEST time), ex "2009-10-01T14:00:00Z"</td>
</tr>
<tr>
  <th>ended_at</th>
  <td>(optional) the time when the session ended (converted from CEST time), ex "2009-10-01T18:30:00Z"</td>
</tr>
<tr>
  <th>location</th>
  <td>(optional) the location where the session took place,
      ex "Landeshauptstadt Dresden,  im Neuen Rathaus, Plenarsaal,Rathausplatz 1, 01067 Dresden"</td>
</tr>
<tr>
  <th>download_at</th>
  <td>(required) the time when the archive was downloaded</td>
</tr>
<tr>
  <th>documents</th>
  <td>documents associated with the session (excluding those associated
    with parts)
    <table>
       <tr>
         <th>file_name</th>
         <td>the file name as it is in the session directory, ex: 00003144.pdf"</td>
       </tr>
       <tr>
         <th>description:</th>
         <td>name of the document, ex: "Vorlage Gremien"</td>
       </tr>
    </table>
  </td>
</tr>
<tr>
  <th>parts</th>
  <td>(optional) each session can contain an array of parts.
      a part is an object containing the following keys:
    <table>
    <tr>
      <th>description</th>
      <td>(required) name of the part, ex "Beschlussvorlagen zu VOB-Vergaben"</td>
    </tr>
    <tr>
      <th>template_id</th>
      <td>(optional) some parts uses templates, further information here http://ratsinfo.dresden.de/vo0042.php</td>
    </tr>
    <tr>
      <th>documents</th>
      <td>
      (optional) array of documents associated with this part
        <table>
          <tr>
            <th>file_name</th>
            <td>the file name as it is in the session directory, ex: "00003144.pdf"</td>
          </tr>
          <tr>
            <th>description</th>
            <td>name of the document, ex: "Vorlage Gremien"</td>
          </tr>
          <tr>
            <th>pdf_metadata</th>
            <td>
              <table>
                <tr>
                  <th>created_at</th>
                  <td>(required) PDF CreationDate</td>
                </tr>
                <tr>
                  <th>updated_at</th>
                  <td>(required) PDF ModDate</td>
                </tr>
                <tr>
                  <th>author</th>
                  <td>(optional) PDF Author, ex: "Sitzungsdienst 'Session'"</td>
                </tr>
                <tr>
                  <th>producer</th>
                  <td>(optional) PDF Producer, ex: "Acrobat Distiller 8.1.0 (Windows)"</td>
                </tr>
                <tr>
                  <th>creator</th>
                  <td>PDF Creator, ex: "Acrobat PDFMaker 8.1 für Word"</td>
                </tr>
                <tr>
                  <th>page_count</th>
                  <td>(required) Number of Pages</td>
                </tr>
                <tr>
                  <th>pdf_title</th>
                  <td>(optional) Either PDF Title or Subject</td>
                </tr>
                <tr>
                  <th>keywords</th>
                  <td>(optional) PDF Keywords</td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </td>
    </tr>
    <tr>
      <th>decision</th>
      <td>(optional) some sessions ended with a decision made by the comittee, ex: "Zustimmung"</td>
    </tr>
    <tr>
      <th>vote_result</th>
      <td>(optional) object
        <table>
          <tr>
            <th>pro</th>
            <td>(required) votes for the subject, ex: 1</td>
          </tr>
          <tr>
            <th>contra</th>
            <td>(required) votes against the subject, ex: 2</td>
          </tr>
          <tr>
            <th>abstention</th>
            <td>(required) neither/nor contra or pro, ex: 0</td>
         </tr>
        </table>
      </td>
    </tr>
    </table>
  </td>
  </tr>
</table>

TODO
----

- continue, where the last scan stopped
- templates for custom tasks
- clean up task
