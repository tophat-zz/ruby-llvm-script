require 'rubygems'
require 'fileutils'
require 'mustache'
require 'nokogiri'
require 'open-uri'
require 'gollum'
require 'git'

WIKI_ROOT = "https://github.com/tophat/ruby-llvm-script/wiki/"
ASSET_ROOT = "http://tophat.github.com/ruby-llvm-script/"

class Page < Mustache 
  def initialize(html)
    @html = html
  end
  
  def asset_path_prefix
    ASSET_ROOT
  end
  
  def owner_name
    "tophat"
  end
  
  def owner_url
    "https://github.com/tophat"
  end
  
  def project_title
    "Ruby LLVM Script"
  end
  
  def project_tagline
    "Simple, clean interface for ruby-llvm."
  end
  
  def main_content
    @html
  end
end

class WikiPages
  def self.generate(repo, files, tempdir="src")
    pages = WikiPages.new(repo, files, tempdir)
    pages.generate
    pages.cleanup
  end
    
  def initialize(repo, files, tempdir="src")
    @tempdir = tempdir
    Git.clone(repo, @tempdir)
    @wiki = Gollum::Wiki.new(@tempdir)
    @files = files 
  end
  
  def cleanup
    FileUtils.rm_rf(@tempdir)
  end
  
  def generate
    @files.each { |page, file| map(page, file) }
  end
    
  def map(pagename, fname)
    page = @wiki.page(pagename)
    body = Nokogiri::HTML(page.formatted_data)
    body.xpath("//a").each do |link|
      href = link["href"]
      link["href"] = ASSET_ROOT + @files[File.basename(href)] if href.include?(WIKI_ROOT)
    end
    FileUtils.mkpath(File.dirname(fname))
    file = File.open(fname, "w")
    file.puts(Page.new(body.to_xml).render)
    file.close
  end
end

FILES = {
  "Installation"      => "installation.html",  
  "Hello-World"       => "breakdowns/hello-world.html",
  "Factorial"         => "breakdowns/factorial.html",
  "IO"                => "breakdowns/io.html",
  "Conditionals"      => "breakdowns/conditionals.html",
  "Function-Pointers" => "breakdowns/function-pointers.html",  
}
WikiPages.generate("https://github.com/tophat/ruby-llvm-script.wiki.git", FILES)
