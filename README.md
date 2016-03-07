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
To start scraping use on other console:

    rake

This will extract all documents to the path of the environment variable DOWNLOAD_PATH (defaults to "data") and convert it to xml files, containing metadata and full text of the pdfs

To scrape an individual session for example: [http://ratsinfo.dresden.de/to0040.php?\_\_ksinr=100](http://ratsinfo.dresden.de/to0040.php?\_\_ksinr=100)

    rake testmonth

To just download a tiny set of Data, only session data. Just for testing.

To display all tasks use:

    rake -T

The download directory will have the following scheme:

- each session have a directory, where the id is the directory name
- every document belonging to this session will be extracted to this directory

- additionally a JSON file is created, with the session id in its name. This is a machine-readable
  version of the index.htm file, which is contained in the document archives


**We do now follow the [OParl specification](https://oparl.org/spezifikation/online-ansicht/)!**

Deviations from the OParl spec:

* Numerical `id` everywhere, because we don't yet serve the data on HTTP URIs


TODO
----

- Person

- continue, where the last scan stopped
- templates for custom tasks
- clean up task
