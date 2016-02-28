require_relative 'tika_app.rb'

pdf_path = '/home/rob/Dokumente/code/stadtrat/mic-ris-scraper/data/22/00002306.pdf'

text_file_prefix = "#{File.dirname(pdf_path)}/#{File.basename(pdf_path, '.*')}"
text_file_path = "#{text_file_prefix}.xml"
tika = TikaApp.new(pdf_path)


dok = open('/home/rob/Dokumente/code/stadtrat/mic-ris-scraper/tikatest.xml',"w+")
dok.write(tika.get_xml)
