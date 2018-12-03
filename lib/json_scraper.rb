require 'net/http'
require 'uri'
require 'fileutils'
require 'json'

class JsonScraper
  attr_accessor :base_dir, :sleep_for

  def initialize(api_key:, sleep_for: 0.33)
    @api_key,@sleep_for=api_key,sleep_for
  end

  def get_blog(blog, dir:, pages: nil, limit: 20, offset: 0, 
               reblog_info: true, overwrite: false, sleep_for: @sleep_for, 
               **params)
    if params[:before]
      raise ArgumentError.new("Cannot use 'before' parameter for pagination; this function does not parse JSON.")
    end
    FileUtils::mkdir_p(dir)
    params.merge! limit: limit, offset: offset, reblog_info: reblog_info

    meta = { blog: blog, dir: dir, settings_used: params.merge({pages: pages, sleep_for: sleep_for}), init_scrape: Time.now }

    prev_page = ''
    pages     = pages.to_i
    i         = 0
    while true
      puts "Fetching from Tumblr @#{blog} at offset #{params[:offset]}..."
      page = get_page(blog, **params)

      # Identical pages means we're done
      break if (prev_page.length==page.length) && (prev_page==page)

      save_page(page, dir: dir, offset: params[:offset], limit: params[:limit], overwrite: overwrite)

      break if (i+=1)==pages
      params[:offset] += params[:limit]
      prev_page = page
      sleep(@sleep_for)
    end
    puts "\nAppear to have reached end of blog @#{blog}!"
    puts "Total pages fetched: #{i}\n"

    meta[:end_scrape] = Time.now
    meta[:pages]      = i
    return meta
  end

  def get_page(blog, api_key: @api_key, type: nil, **params)
    stem      = "https://api.tumblr.com/v2/blog/#{blog}/posts"
    stem     += "/#{type}" if !!type
    uri       = URI(stem)
    uri.query = URI.encode_www_form({ api_key: api_key }.merge(params))
    Net::HTTP.get(uri)
  end

  def save_page(page, dir:, offset:, limit: 20, figs: 5, overwrite: false)
    filename = "%.#{figs}d" % ((offset/limit)+1)  # offset 120 (p6) => 00006
    filename = File.join(dir, "#{filename}.json")
    if !overwrite && File.exist?(filename)
      raise "File already exists: #{filename}"
    end
    puts "Saving page: #{filename}"
    File.write(filename, page)
  end
end # class JsonScraper