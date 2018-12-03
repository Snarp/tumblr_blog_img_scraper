require 'tumblr_client'
load 'lib/post_analyzer.rb'
load 'lib/json_scraper.rb'
load 'lib/image_finder.rb'
load 'lib/media_scraper.rb'
load 'lib/scraper.rb'

# TIME_FORMAT = '%Y%m%d_%H%M%S'

def ts(**params)
  params
end

def scrape(blog, **params)
  @scraper.scrape_blog(blog, **params)
end

def scrape_no_imgs(blog, images: false, postprocess: false, **params)
  @scraper.scrape_blog(blog,images: images,postprocess: postprocess,**params)
end

def test_scrape(blog='demo', **params)
  @test_scraper=@scraper.clone
  @test_scraper.base_dir='scraped'
  @test_scraper.media_dir='scraped/_media'
  @test_scraper.scrape_blog(blog,**params)
end



def json_to_hash(filename='scraped/demo/json/00001.json')
  JSON::parse(File.read(filename))['response']
end

def json_to_yaml(filename='scraped/demo/json/00001.json')
  hash=JSON::parse(File.read(filename))
  File.write(filename.sub('.json','.yml'), hash.to_yaml)
end



# SETUP

def init
  load_creds
  load_settings(force: true)
  @scraper = Scraper.new(
    sleep_for:           @sleep_for, 
    base_dir:            @dir, 
    media_dir:           @media_dir, 
    postprocess:         @settings[:postprocess], 
    download_images:     @settings[:download_images], 
    filter_downloads:    @settings[:filter_downloads], 
    media_dir_structure: @settings[:media_dir_structure], 
    **@creds, **@settings[:blog_args])
end

def load_creds(filename='credentials.yml.env')
  @creds = YAML::load(File.read('credentials.yml.env'))
end

def load_settings(filename='settings.yml', force: true)
  if @settings && !force
    return nil
  elsif !File.exist?(filename)
    unless File.exist?('settings_default.yml')
      raise "#{filename} and settings_default.yml not found!"
    end
    @settings=File.read('settings_default.yml')
    File.write(filename, @settings)
    @settings=YAML::load(@settings)
  else
    @settings = YAML::load(File.read(filename))
  end

  @sleep_for = @settings[:sleep_for]
  if @settings[:base_dir]
    @dir       = @settings[:base_dir]
    @media_dir = @settings[:media_dir] || File.join(@dir, '_media')
  end
  return @settings
end

init unless @scraper

scrape(*ARGV) if ARGV && ARGV.any?