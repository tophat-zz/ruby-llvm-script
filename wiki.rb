require 'rubygems'
require 'fileutils'
require 'nokogiri'
require 'open-uri'
require 'gollum'
require 'git'

FILEMAP = {
  "Installation"      => "installation.html",  
  "Hello-World"       => "breakdowns/hello-world.html",
  "Factorial"         => "breakdowns/factorial.html",
  "IO"                => "breakdowns/io.html",
  "Conditionals"      => "breakdowns/conditionals.html",
  "Function-Pointers" => "breakdowns/function-pointers.html",  
}
OLD_ROOT = "https://github.com/tophat/ruby-llvm-script/wiki/"
NEW_ROOT = "http://tophat.github.com/ruby-llvm-script/"

Git.clone("https://github.com/tophat/ruby-llvm-script.wiki.git", "src")

wiki = Gollum::Wiki.new("src")
wiki.pages.each do |page|
  
  fname = FILEMAP[page.filename_stripped]
  next if fname.nil?
  
  FileUtils.mkpath(File.dirname(fname))
  FileUtils.copy("template.html", fname)
   
  doc = Nokogiri::HTML(File.open(fname))
  body = doc.at_xpath("//div[@class='wrapper']/section")
  if body.nil?
    raise RuntimeError, "Wrapper section could not be found in template."
  end
  body.add_child("<h1>#{page.name}</h1>")
  body.add_child(page.formatted_data)
  body.xpath("//a").each do |link|
    href = link["href"]
    if href.include?(OLD_ROOT)
      link["href"] = NEW_ROOT + FILEMAP[File.basename(href)]
    end
  end
  
  file = File.open(fname, "w")
  file.puts(doc.to_xml)
  file.close
  
end
FileUtils.rm_rf("src")